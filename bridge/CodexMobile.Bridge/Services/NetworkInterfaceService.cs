using CodexMobile.Bridge.Models;
using System.Net;
using System.Net.Sockets;
using System.Net.NetworkInformation;

namespace CodexMobile.Bridge.Services;

public sealed class NetworkInterfaceService
{
    private readonly Func<IReadOnlyList<IPAddress>> addressProvider;
    private readonly Func<ExternalBridgeUrlsResult> externalBridgeUrlsProvider;
    private readonly bool allowPublicBridgeHosts;

    public NetworkInterfaceService()
        : this(GetLocalIPv4Addresses, GetAllowPublicBridgeHosts(), ReadConfiguredExternalBridgeUrls)
    {
    }

    public NetworkInterfaceService(
        Func<IReadOnlyList<IPAddress>> addressProvider,
        bool allowPublicBridgeHosts)
        : this(addressProvider, allowPublicBridgeHosts, ReadConfiguredExternalBridgeUrls)
    {
    }

    public NetworkInterfaceService(
        Func<IReadOnlyList<IPAddress>> addressProvider,
        bool allowPublicBridgeHosts,
        Func<ExternalBridgeUrlsResult> externalBridgeUrlsProvider)
    {
        this.addressProvider = addressProvider ?? throw new ArgumentNullException(nameof(addressProvider));
        this.allowPublicBridgeHosts = allowPublicBridgeHosts;
        this.externalBridgeUrlsProvider = externalBridgeUrlsProvider ?? throw new ArgumentNullException(nameof(externalBridgeUrlsProvider));
    }

    public BridgeNetworkSummary ReadSummary(string scheme, int port)
    {
        var endpoints = new List<BridgeNetworkEndpoint>();
        var warnings = new List<string>();
        var distinctHosts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var distinctUrls = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var externalUrls = externalBridgeUrlsProvider();
        warnings.AddRange(externalUrls.Warnings);
        foreach (var url in externalUrls.Urls)
        {
            if (!distinctUrls.Add(url))
            {
                continue;
            }

            var uri = new Uri(url, UriKind.Absolute);
            distinctHosts.Add(uri.Host);
            endpoints.Add(new BridgeNetworkEndpoint(
                uri.Host,
                url,
                "external",
                true,
                true));
        }

        foreach (var address in addressProvider().Where(address => address.AddressFamily == AddressFamily.InterNetwork))
        {
            var host = address.ToString();
            if (!distinctHosts.Add(host))
            {
                continue;
            }

            var scope = Classify(address);
            if (scope == "public" && !allowPublicBridgeHosts)
            {
                warnings.Add($"Skipped public host {host} because CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE is not enabled.");
                continue;
            }

            var url = BuildUrl(scheme, host, port);
            if (!distinctUrls.Add(url))
            {
                continue;
            }

            endpoints.Add(new BridgeNetworkEndpoint(
                host,
                url,
                scope,
                true,
                scope != "public"));
        }

        if (!endpoints.Any(endpoint => endpoint.Scope == "loopback"))
        {
            var loopbackUrl = BuildUrl(scheme, "127.0.0.1", port);
            if (distinctUrls.Add(loopbackUrl))
            {
                endpoints.Insert(0, new BridgeNetworkEndpoint(
                "127.0.0.1",
                loopbackUrl,
                "loopback",
                true,
                false));
            }
        }

        return new BridgeNetworkSummary(
            scheme,
            port,
            allowPublicBridgeHosts,
            endpoints,
            warnings);
    }

    public static ExternalBridgeUrlsResult ReadConfiguredExternalBridgeUrls()
    {
        var rawValues = new List<string>();
        var warnings = new List<string>();

        AddDelimitedEnvironment(rawValues, "CODEX_MOBILE_EXTERNAL_BRIDGE_URLS");
        AddDelimitedEnvironment(rawValues, "CODEX_MOBILE_PUBLIC_BRIDGE_URLS");

        var configuredFile = Environment.GetEnvironmentVariable("CODEX_MOBILE_EXTERNAL_BRIDGE_URLS_FILE");
        var candidateFiles = new List<string>();
        if (!string.IsNullOrWhiteSpace(configuredFile))
        {
            candidateFiles.Add(configuredFile);
        }

        candidateFiles.Add(Path.Combine(AppContext.BaseDirectory, "bridge-external-urls.txt"));

        foreach (var file in candidateFiles.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                if (!File.Exists(file))
                {
                    continue;
                }

                foreach (var line in File.ReadAllLines(file))
                {
                    var trimmed = line.Trim();
                    if (trimmed.Length == 0 || trimmed.StartsWith("#", StringComparison.Ordinal))
                    {
                        continue;
                    }

                    rawValues.Add(trimmed);
                }
            }
            catch (Exception ex)
            {
                warnings.Add($"Could not read external bridge URL file {file}: {ex.Message}");
            }
        }

        var urls = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var rawValue in rawValues)
        {
            if (!TryNormalizeExternalUrl(rawValue, out var normalized))
            {
                warnings.Add($"Ignored invalid external bridge URL: {rawValue}");
                continue;
            }

            if (seen.Add(normalized))
            {
                urls.Add(normalized);
            }
        }

        return new ExternalBridgeUrlsResult(urls, warnings);
    }

    private static void AddDelimitedEnvironment(List<string> values, string name)
    {
        var raw = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(raw))
        {
            return;
        }

        values.AddRange(raw.Split(
            [',', ';', '\r', '\n'],
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static bool TryNormalizeExternalUrl(string rawUrl, out string normalized)
    {
        normalized = string.Empty;
        if (!Uri.TryCreate(rawUrl.Trim(), UriKind.Absolute, out var uri))
        {
            return false;
        }

        if (uri.Scheme is not ("http" or "https") || string.IsNullOrWhiteSpace(uri.Host))
        {
            return false;
        }

        normalized = uri.GetLeftPart(UriPartial.Authority).TrimEnd('/');
        return true;
    }

    public static IReadOnlyList<IPAddress> GetLocalIPv4Addresses()
    {
        var overrideHosts = Environment.GetEnvironmentVariable("CODEX_MOBILE_BRIDGE_HOSTS");
        if (!string.IsNullOrWhiteSpace(overrideHosts))
        {
            var parsed = overrideHosts
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(host => IPAddress.TryParse(host, out var address) ? address : null)
                .OfType<IPAddress>()
                .ToArray();

            if (parsed.Length > 0)
            {
                return parsed;
            }
        }

        var addresses = new List<IPAddress>();

        try
        {
            foreach (var networkInterface in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (networkInterface.OperationalStatus != OperationalStatus.Up)
                {
                    continue;
                }

                foreach (var ipProperties in networkInterface.GetIPProperties().UnicastAddresses)
                {
                    if (ipProperties.Address.AddressFamily == AddressFamily.InterNetwork)
                    {
                        addresses.Add(ipProperties.Address);
                    }
                }
            }
        }
        catch
        {
            // Fallback below.
        }

        if (addresses.Count == 0)
        {
            addresses.Add(IPAddress.Loopback);
        }

        return addresses;
    }

    private static string BuildUrl(string scheme, string host, int port)
    {
        var formattedHost = host.Contains(":", StringComparison.Ordinal) && !host.StartsWith("[", StringComparison.Ordinal)
            ? $"[{host}]"
            : host;
        return $"{scheme}://{formattedHost}:{port}";
    }

    private static string Classify(IPAddress address)
    {
        var bytes = address.GetAddressBytes();
        if (IPAddress.IsLoopback(address))
        {
            return "loopback";
        }

        if (bytes[0] == 10)
        {
            return "private-lan";
        }

        if (bytes[0] == 192 && bytes[1] == 168)
        {
            return "private-lan";
        }

        if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31)
        {
            return "private-lan";
        }

        if (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127)
        {
            return "mesh-vpn";
        }

        if (bytes[0] == 169 && bytes[1] == 254)
        {
            return "link-local";
        }

        return "public";
    }

    private static bool GetAllowPublicBridgeHosts()
    {
        var value = Environment.GetEnvironmentVariable("CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE");
        return string.Equals(value, "true", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yes", StringComparison.OrdinalIgnoreCase);
    }
}

public sealed record ExternalBridgeUrlsResult(
    IReadOnlyList<string> Urls,
    IReadOnlyList<string> Warnings);
