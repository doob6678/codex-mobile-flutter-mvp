using Microsoft.Extensions.Configuration;

namespace CodexMobile.Bridge.Services;

public static class BridgeHosting
{
    public static string[] ResolveUrls(IConfiguration configuration)
    {
        var configured =
            Environment.GetEnvironmentVariable("ASPNETCORE_URLS")
            ?? configuration["BridgeUrls"]
            ?? Environment.GetEnvironmentVariable("CODEX_MOBILE_BIND_URLS");

        if (!string.IsNullOrWhiteSpace(configured))
        {
            return configured.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        }

        return ["http://0.0.0.0:5010"];
    }
}
