using System.Diagnostics;
using System.Text;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed record BridgeStartupGuide(
    string LocalConnectUrl,
    IReadOnlyList<string> PhoneBridgeUrls,
    IReadOnlyList<string> IpadWebUrls,
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
        var ipadWebUrls = phoneBridgeUrls
            .Select(ToIpadWebUrl)
            .ToArray();

        var builder = new StringBuilder();
        builder.AppendLine("Codex Mobile Bridge ready");
        builder.AppendLine($"Windows-only QR page: {localConnectUrl}");
        builder.AppendLine("iPad/Web URLs:");
        foreach (var url in ipadWebUrls)
        {
            builder.AppendLine($"  - {url}");
        }
        builder.AppendLine("Phone bridge URLs:");
        foreach (var url in phoneBridgeUrls)
        {
            builder.AppendLine($"  - {url}");
        }
        builder.AppendLine("/connect 只能在 Windows 本机 127.0.0.1 或 localhost 打开。");
        builder.AppendLine("不要在手机填 0.0.0.0 或 127.0.0.1。");
        builder.AppendLine("手机请使用上面的局域网/VPN真实地址。");

        return new BridgeStartupGuide(
            localConnectUrl,
            phoneBridgeUrls,
            ipadWebUrls,
            builder.ToString().TrimEnd());
    }

    public static string ToIpadWebUrl(string bridgeUrl)
    {
        return $"{bridgeUrl.TrimEnd('/')}/ipad/";
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
