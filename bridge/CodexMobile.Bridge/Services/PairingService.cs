using System.Security.Cryptography;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class PairingService
{
    public const int MaxFailedAttempts = 5;
    private static readonly TimeSpan CooldownDuration = TimeSpan.FromMinutes(2);

    private readonly IClock clock;
    private readonly DeviceTokenStore tokenStore;
    private readonly object gate = new();
    private readonly Dictionary<string, PairingChallenge> challenges = new(StringComparer.OrdinalIgnoreCase);
    private int failedAttempts;
    private int successfulPairings;
    private DateTimeOffset? cooldownUntil;
    private DateTimeOffset? lastPairedAt;

    public PairingService(IClock clock, DeviceTokenStore tokenStore)
    {
        this.clock = clock;
        this.tokenStore = tokenStore;
    }

    public PairingChallenge Start(TimeSpan ttl)
    {
        lock (gate)
        {
            EnsureNotInCooldown();
        }

        var idBytes = RandomNumberGenerator.GetBytes(18);
        var id = Convert.ToBase64String(idBytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
        var code = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var challenge = new PairingChallenge(id, code, clock.Now.Add(ttl));

        lock (gate)
        {
            challenges[id] = challenge;
        }

        return challenge;
    }

    public PairingToken Complete(string code, string? challengeId = null)
    {
        if (string.IsNullOrWhiteSpace(challengeId))
        {
            RegisterFailure();
            throw new InvalidOperationException("Pairing challenge id is required.");
        }

        PairingChallenge challenge;
        lock (gate)
        {
            EnsureNotInCooldown();
            if (!challenges.TryGetValue(challengeId, out challenge!))
            {
                RegisterFailureLocked();
                throw new InvalidOperationException("Pairing challenge was not found.");
            }

            if (!string.Equals(challenge.Code, code, StringComparison.Ordinal))
            {
                RegisterFailureLocked();
                throw new InvalidOperationException("Pairing code did not match the challenge.");
            }

            challenges.Remove(challengeId);
        }

        if (challenge.ExpiresAt <= clock.Now)
        {
            RegisterFailure();
            throw new InvalidOperationException("Pairing challenge expired.");
        }

        var token = tokenStore.Issue("mobile-device", TimeSpan.FromHours(12));
        lock (gate)
        {
            failedAttempts = 0;
            cooldownUntil = null;
            successfulPairings++;
            lastPairedAt = clock.Now;
        }

        return token;
    }

    public PairingSecuritySnapshot ReadSecuritySnapshot()
    {
        lock (gate)
        {
            ClearExpiredCooldownLocked();
            return new PairingSecuritySnapshot(
                challenges.Count(challenge => challenge.Value.ExpiresAt > clock.Now),
                failedAttempts,
                MaxFailedAttempts,
                cooldownUntil,
                successfulPairings,
                lastPairedAt);
        }
    }

    private void EnsureNotInCooldown()
    {
        ClearExpiredCooldownLocked();
        if (cooldownUntil is { } until && until > clock.Now)
        {
            throw new InvalidOperationException($"Pairing is temporarily locked until {until:O}.");
        }
    }

    private void RegisterFailure()
    {
        lock (gate)
        {
            RegisterFailureLocked();
        }
    }

    private void RegisterFailureLocked()
    {
        failedAttempts++;
        if (failedAttempts >= MaxFailedAttempts)
        {
            cooldownUntil = clock.Now.Add(CooldownDuration);
            challenges.Clear();
        }
    }

    private void ClearExpiredCooldownLocked()
    {
        if (cooldownUntil is { } until && until <= clock.Now)
        {
            cooldownUntil = null;
            failedAttempts = 0;
        }
    }
}
