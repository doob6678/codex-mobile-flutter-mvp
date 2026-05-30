using System.Security.Cryptography;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class DeviceTokenStore
{
    private readonly IClock clock;
    private readonly object gate = new();
    private readonly Dictionary<string, PairingToken> tokens = new(StringComparer.Ordinal);
    private readonly HashSet<string> revoked = new(StringComparer.Ordinal);

    public DeviceTokenStore(IClock clock)
    {
        this.clock = clock;
    }

    public PairingToken Issue(string deviceName, TimeSpan ttl)
    {
        var token = new PairingToken(
            Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant(),
            clock.Now.Add(ttl),
            string.IsNullOrWhiteSpace(deviceName) ? "mobile-device" : deviceName.Trim());

        lock (gate)
        {
            tokens[token.AccessToken] = token;
        }

        return token;
    }

    public bool Validate(string? accessToken)
    {
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return false;
        }

        lock (gate)
        {
            if (revoked.Contains(accessToken))
            {
                return false;
            }

            return tokens.TryGetValue(accessToken, out var token) && token.ExpiresAt > clock.Now;
        }
    }

    public void Revoke(string accessToken)
    {
        lock (gate)
        {
            revoked.Add(accessToken);
            tokens.Remove(accessToken);
        }
    }
}
