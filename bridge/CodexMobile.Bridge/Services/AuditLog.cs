using System.Text.RegularExpressions;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class AuditLog
{
    private static readonly Regex ApiKeyAssignment = new(@"OPENAI_API_KEY\s*=\s*\S+", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex SecretToken = new(@"sk-[A-Za-z0-9_\-]+", RegexOptions.Compiled);

    private readonly IClock clock;
    private readonly object gate = new();
    private readonly List<AuditEntry> entries = new();

    public AuditLog(IClock clock)
    {
        this.clock = clock;
    }

    public AuditEntry Record(string type, string message)
    {
        var entry = new AuditEntry($"audit_{Guid.NewGuid():N}", type, Redact(message), clock.Now);
        lock (gate)
        {
            entries.Add(entry);
        }

        return entry;
    }

    public IReadOnlyList<AuditEntry> List()
    {
        lock (gate)
        {
            return entries.ToArray();
        }
    }

    private static string Redact(string message)
    {
        var redacted = ApiKeyAssignment.Replace(message, "OPENAI_API_KEY=[REDACTED]");
        return SecretToken.Replace(redacted, "[REDACTED]");
    }
}
