using System.Diagnostics;
using System.Text;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class CommandService
{
    private sealed record CommandTemplate(
        string Executable,
        string[] Arguments,
        RiskLevel Risk);

    private static readonly CommandTemplate[] Allowlist =
    [
        new("git", ["status"], RiskLevel.ReadOnly),
        new("dotnet", ["test"], RiskLevel.Test),
        new("flutter", ["test"], RiskLevel.Test),
        new("flutter", ["analyze"], RiskLevel.Verification),
        new("powershell", ["-ExecutionPolicy", "Bypass", "-File", "scripts\\verify.ps1"], RiskLevel.Verification),
        new("powershell", ["-ExecutionPolicy", "Bypass", "-File", "scripts/verify.ps1"], RiskLevel.Verification),
    ];

    private readonly AuditLog audit;
    private readonly ProjectStore projects;

    public CommandService(AuditLog audit, ProjectStore? projects = null)
    {
        this.audit = audit;
        this.projects = projects ?? new ProjectStore();
    }

    public CommandPreview Preview(CommandRequest request)
    {
        var parts = SplitCommand(request.Command);
        var match = Allowlist.FirstOrDefault(item => CommandEquals(item, parts));
        if (match is null)
        {
            throw new InvalidOperationException("Command is not in the mobile bridge allowlist.");
        }

        var cwd = Path.GetFullPath(request.WorkingDirectory);
        if (!Directory.Exists(cwd))
        {
            throw new DirectoryNotFoundException(cwd);
        }

        EnsureAuthorizedWorkingDirectory(cwd);

        var command = FormatCommand(match);
        return new CommandPreview(command, cwd, match.Risk, RequiresApproval: match.Risk != RiskLevel.ReadOnly);
    }

    public async Task<CommandRunResult> RunAsync(CommandRequest request, CancellationToken cancellationToken)
    {
        var preview = Preview(request);
        if (preview.RequiresApproval)
        {
            throw new UnauthorizedAccessException("Command requires an approved Bridge approval before execution.");
        }

        audit.Record("command.preview", $"{preview.Command} cwd={preview.WorkingDirectory}");

        var template = Allowlist.Single(item => string.Equals(FormatCommand(item), preview.Command, StringComparison.OrdinalIgnoreCase));
        var startInfo = new ProcessStartInfo(template.Executable)
        {
            WorkingDirectory = preview.WorkingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        foreach (var argument in template.Arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

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

    private void EnsureAuthorizedWorkingDirectory(string cwd)
    {
        if (projects.ListProjects().Any(project => IsSameOrChildPath(cwd, project.RootPath)))
        {
            return;
        }

        throw new UnauthorizedAccessException("Command working directory is not inside an authorized project root.");
    }

    private static bool CommandEquals(CommandTemplate template, IReadOnlyList<string> parts)
    {
        if (parts.Count != template.Arguments.Length + 1)
        {
            return false;
        }

        return string.Equals(parts[0], template.Executable, StringComparison.OrdinalIgnoreCase)
            && template.Arguments.SequenceEqual(parts.Skip(1), StringComparer.OrdinalIgnoreCase);
    }

    private static string FormatCommand(CommandTemplate template)
    {
        return string.Join(' ', new[] { template.Executable }.Concat(template.Arguments));
    }

    private static string[] SplitCommand(string command)
    {
        return (command ?? "")
            .Split([' ', '\t', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    private static bool IsSameOrChildPath(string candidate, string rootPath)
    {
        var root = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var fullCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (string.Equals(fullCandidate, root, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return fullCandidate.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    }

    private static string TrimOutput(string output)
    {
        const int maxLength = 32_000;
        return output.Length <= maxLength ? output : output[..maxLength];
    }
}
