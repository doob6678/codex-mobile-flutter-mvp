using CodexMobile.Bridge.Models;
using System.Net;
using System.Net.Sockets;
using System.Net.NetworkInformation;

namespace CodexMobile.Bridge.Services;

public sealed class NetworkInterfaceService
{
    private readonly Func<IReadOnlyList<IPAddress>> addressProvider;
    private readonly bool allowPublicBridgeHosts;

    public NetworkInterfaceService()
        : this(GetLocalIPv4Addresses, GetAllowPublicBridgeHosts())
    {
    }

    public NetworkInterfaceService(
        Func<IReadOnlyList<IPAddress>> addressProvider,
        bool allowPublicBridgeHosts)
    {
        this.addressProvider = addressProvider ?? throw new ArgumentNullException(nameof(addressProvider));
        this.allowPublicBridgeHosts = allowPublicBridgeHosts;
    }

    public BridgeNetworkSummary ReadSummary(string scheme, int port)
    {
        var endpoints = new List<BridgeNetworkEndpoint>();
        var warnings = new List<string>();
        var distinctHosts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

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

            endpoints.Add(new BridgeNetworkEndpoint(
                host,
                BuildUrl(scheme, host, port),
                scope,
                true,
                scope != "public"));
        }

        if (!endpoints.Any(endpoint => endpoint.Scope == "loopback"))
        {
            endpoints.Insert(0, new BridgeNetworkEndpoint(
                "127.0.0.1",
                BuildUrl(scheme, "127.0.0.1", port),
                "loopback",
                true,
                false));
        }

        return new BridgeNetworkSummary(
            scheme,
            port,
            allowPublicBridgeHosts,
            endpoints,
            warnings);
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
