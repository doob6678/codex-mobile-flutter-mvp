using System.Security.Cryptography;
using System.Text;
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

    public IReadOnlyList<PairingTokenStatus> ListActive(string? currentAccessToken)
    {
        lock (gate)
        {
            return tokens
                .Where(entry => !revoked.Contains(entry.Key) && entry.Value.ExpiresAt > clock.Now)
                .OrderByDescending(entry => entry.Value.ExpiresAt)
                .Select(entry => new PairingTokenStatus(
                    Fingerprint(entry.Key),
                    entry.Value.DeviceName,
                    entry.Value.ExpiresAt,
                    CryptographicOperations.FixedTimeEquals(
                        Encoding.UTF8.GetBytes(entry.Key),
                        Encoding.UTF8.GetBytes(currentAccessToken ?? string.Empty))))
                .ToArray();
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

    public bool RevokeByFingerprint(string fingerprint)
    {
        if (string.IsNullOrWhiteSpace(fingerprint))
        {
            return false;
        }

        lock (gate)
        {
            var match = tokens.Keys.FirstOrDefault(token =>
                string.Equals(Fingerprint(token), fingerprint.Trim(), StringComparison.OrdinalIgnoreCase));
            if (match is null)
            {
                return false;
            }

            revoked.Add(match);
            tokens.Remove(match);
            return true;
        }
    }

    private static string Fingerprint(string accessToken)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(accessToken));
        return Convert.ToHexString(hash)[..12].ToLowerInvariant();
    }
}
