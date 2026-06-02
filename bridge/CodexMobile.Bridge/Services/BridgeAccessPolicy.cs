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
}
