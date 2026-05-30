using System.Diagnostics;
using System.Text;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class CommandService
{
    private static readonly (string Prefix, RiskLevel Risk)[] Allowlist =
    [
        ("git status", RiskLevel.ReadOnly),
        ("dotnet test", RiskLevel.Test),
        ("flutter test", RiskLevel.Test),
        ("flutter analyze", RiskLevel.Verification),
        ("powershell -ExecutionPolicy Bypass -File scripts\\verify.ps1", RiskLevel.Verification),
        ("powershell -ExecutionPolicy Bypass -File scripts/verify.ps1", RiskLevel.Verification),
    ];

    private readonly AuditLog audit;

    public CommandService(AuditLog audit)
    {
        this.audit = audit;
    }

    public CommandPreview Preview(CommandRequest request)
    {
        var command = Normalize(request.Command);
        var match = Allowlist.FirstOrDefault(item => command.StartsWith(item.Prefix, StringComparison.OrdinalIgnoreCase));
        if (match.Prefix is null)
        {
            throw new InvalidOperationException("Command is not in the mobile bridge allowlist.");
        }

        var cwd = Path.GetFullPath(request.WorkingDirectory);
        if (!Directory.Exists(cwd))
        {
            throw new DirectoryNotFoundException(cwd);
        }

        return new CommandPreview(command, cwd, match.Risk, RequiresApproval: match.Risk != RiskLevel.ReadOnly);
    }

    public async Task<CommandRunResult> RunAsync(CommandRequest request, CancellationToken cancellationToken)
    {
        var preview = Preview(request);
        audit.Record("command.preview", $"{preview.Command} cwd={preview.WorkingDirectory}");

        var startInfo = new ProcessStartInfo("cmd.exe", $"/d /s /c \"{preview.Command}\"")
        {
            WorkingDirectory = preview.WorkingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start command.");
        using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(5));
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeout.Token);

        var stdoutTask = process.StandardOutput.ReadToEndAsync(linked.Token);
        var stderrTask = process.StandardError.ReadToEndAsync(linked.Token);
        await process.WaitForExitAsync(linked.Token);

        var result = new CommandRunResult(
            preview.Command,
            process.ExitCode,
            TrimOutput(await stdoutTask),
            TrimOutput(await stderrTask),
            DateTimeOffset.UtcNow);

        audit.Record("command.finished", $"{result.Command} exit={result.ExitCode}");
        return result;
    }

    private static string Normalize(string command)
    {
        return string.Join(' ', command.Split([' ', '\t', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries));
    }

    private static string TrimOutput(string output)
    {
        const int maxLength = 32_000;
        return output.Length <= maxLength ? output : output[..maxLength];
    }
}
