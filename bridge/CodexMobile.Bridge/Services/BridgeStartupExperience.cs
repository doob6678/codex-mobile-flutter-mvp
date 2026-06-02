using System.Diagnostics;
using System.Text;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed record BridgeStartupGuide(
    string LocalConnectUrl,
    IReadOnlyList<string> PhoneBridgeUrls,
    IReadOnlyList<string> PhoneConnectUrls,
    string ConsoleText);

public static class BridgeStartupExperience
{
    public static BridgeStartupGuide CreateGuide(
        string scheme,
        int port,
        BridgeNetworkSummary summary)
    {
        var localConnectUrl = $"{scheme}://127.0.0.1:{port}/connect";
        var phoneBridgeUrls = summary.Endpoints
            .Where(endpoint => endpoint.Scope is not "loopback")
            .Select(endpoint => endpoint.Url)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var phoneConnectUrls = phoneBridgeUrls
            .Select(url => $"{url.TrimEnd('/')}/connect")
            .ToArray();

        var builder = new StringBuilder();
        builder.AppendLine("Codex Mobile Bridge ready");
        builder.AppendLine($"Local QR page: {localConnectUrl}");
        builder.AppendLine("Phone bridge URLs:");
        foreach (var url in phoneBridgeUrls)
        {
            builder.AppendLine($"  - {url}");
        }
        builder.AppendLine("Phone QR URLs:");
        foreach (var url in phoneConnectUrls)
        {
            builder.AppendLine($"  - {url}");
        }
        builder.AppendLine("不要在手机填 0.0.0.0 或 127.0.0.1。");
        builder.AppendLine("手机请使用上面的局域网/VPN真实地址。");

        return new BridgeStartupGuide(
            localConnectUrl,
            phoneBridgeUrls,
            phoneConnectUrls,
            builder.ToString().TrimEnd());
    }

    public static void PrintAndOpen(BridgeStartupGuide guide)
    {
        Console.WriteLine(guide.ConsoleText);

        if (ShouldSkipBrowserLaunch())
        {
            return;
        }

        TryOpenBrowser(guide.LocalConnectUrl);
    }

    private static bool ShouldSkipBrowserLaunch()
    {
        var value = Environment.GetEnvironmentVariable("CODEX_MOBILE_NO_BROWSER");
        return string.Equals(value, "1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "true", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "yes", StringComparison.OrdinalIgnoreCase);
    }

    private static void TryOpenBrowser(string url)
    {
        try
        {
            var info = new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true,
            };
            Process.Start(info);
        }
        catch
        {
            // Console output remains the fallback path.
        }
    }
}
