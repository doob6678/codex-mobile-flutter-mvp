using System.Net;
using Microsoft.AspNetCore.Http;

namespace CodexMobile.Bridge.Services;

public static class BridgeAccessPolicy
{
    public static bool IsLocalOnlyEndpoint(PathString path)
    {
        return path.StartsWithSegments("/connect", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/pairing/start", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsLocalAddress(IPAddress? address)
    {
        if (address is null)
        {
            return false;
        }

        if (IPAddress.IsLoopback(address))
        {
            return true;
        }

        return false;
    }

    public static bool IsLocalHost(HostString host)
    {
        var value = host.Host.Trim();
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        value = value.Trim('[', ']');

        return string.Equals(value, "localhost", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "127.0.0.1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "::1", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsLocalOnlyRequest(HttpContext context)
    {
        return IsLocalOnlyEndpoint(context.Request.Path)
            && IsLocalAddress(context.Connection.RemoteIpAddress)
            && IsLocalHost(context.Request.Host);
    }
}
