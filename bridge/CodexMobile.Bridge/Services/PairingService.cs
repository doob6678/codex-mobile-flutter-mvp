using System.Security.Cryptography;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class PairingService
{
    private readonly IClock clock;
    private readonly object gate = new();
    private readonly Dictionary<string, PairingChallenge> challenges = new(StringComparer.OrdinalIgnoreCase);

    public PairingService(IClock clock)
    {
        this.clock = clock;
    }

    public PairingChallenge Start(TimeSpan ttl)
    {
        var code = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var challenge = new PairingChallenge(code, clock.Now.Add(ttl));

        lock (gate)
        {
            challenges[code] = challenge;
        }

        return challenge;
    }

    public PairingToken Complete(string code)
    {
        PairingChallenge challenge;
        lock (gate)
        {
            if (!challenges.TryGetValue(code, out challenge!))
            {
                throw new InvalidOperationException("Pairing challenge was not found.");
            }

            challenges.Remove(code);
        }

        if (challenge.ExpiresAt <= clock.Now)
        {
            throw new InvalidOperationException("Pairing challenge expired.");
        }

        return new PairingToken(Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant(), clock.Now.AddHours(12));
    }
}
