using Microsoft.Extensions.Configuration;
using System.Net;
using System.Net.Sockets;

namespace CodexMobile.Bridge.Services;

public static class BridgeHosting
{
    private const int DefaultPort = 5010;

    public static string[] ResolveUrls(IConfiguration configuration)
    {
        return ResolveUrls(configuration, IsPortAvailable, FindAvailablePort);
    }

    public static string[] ResolveUrls(
        IConfiguration configuration,
        Func<int, bool> isPortAvailable,
        Func<int> findAvailablePort)
    {
        var configured =
            Environment.GetEnvironmentVariable("ASPNETCORE_URLS")
            ?? Environment.GetEnvironmentVariable("CODEX_MOBILE_BRIDGE_URLS")
            ?? configuration["BridgeUrls"]
            ?? Environment.GetEnvironmentVariable("CODEX_MOBILE_BIND_URLS");

        if (!string.IsNullOrWhiteSpace(configured))
        {
            return configured.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        }

        return [$"http://0.0.0.0:{DefaultPort}"];
    }

    public static int ResolvePort(IEnumerable<string> urls)
    {
        foreach (var rawUrl in urls)
        {
            if (Uri.TryCreate(rawUrl, UriKind.Absolute, out var uri) && uri.Port > 0)
            {
                return uri.Port;
            }
        }

        return DefaultPort;
    }

    private static bool IsPortAvailable(int port)
    {
        TcpListener? listener = null;
        try
        {
            listener = new TcpListener(IPAddress.Any, port);
            listener.Start();
            return true;
        }
        catch (SocketException)
        {
            return false;
        }
        finally
        {
            listener?.Stop();
        }
    }

    private static int FindAvailablePort()
    {
        var listener = new TcpListener(IPAddress.Any, 0);
        try
        {
            listener.Start();
            return ((IPEndPoint)listener.LocalEndpoint).Port;
        }
        finally
        {
            listener.Stop();
        }
    }

}
