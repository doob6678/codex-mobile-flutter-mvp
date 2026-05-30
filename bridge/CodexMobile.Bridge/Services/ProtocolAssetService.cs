using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class ProtocolAssetService
{
    private static readonly string[] SupportedMethods =
    [
        "initialize",
        "config/read",
        "account/read",
        "thread/list",
        "thread/read",
        "thread/start",
        "thread/resume",
        "turn/start",
        "turn/steer",
        "fs/readDirectory",
        "fs/readFile",
        "item/commandExecution/requestApproval",
        "item/fileChange/requestApproval",
        "command/exec",
    ];

    private readonly string repositoryRoot;

    public ProtocolAssetService(string repositoryRoot)
    {
        this.repositoryRoot = Path.GetFullPath(repositoryRoot);
    }

    public ProtocolSummary ReadSummary()
    {
        var generatedRoot = Path.Combine(repositoryRoot, "generated");
        var tsRoot = Path.Combine(generatedRoot, "codex-app-server-ts");
        var schemaRoot = Path.Combine(generatedRoot, "codex-app-server-schema");

        return new ProtocolSummary(
            "codex app-server generate-ts/generate-json-schema --experimental",
            ListRelativeFiles(tsRoot),
            ListRelativeFiles(schemaRoot),
            SupportedMethods);
    }

    private IReadOnlyList<string> ListRelativeFiles(string root)
    {
        if (!Directory.Exists(root))
        {
            return [];
        }

        return Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories)
            .Select(path => Path.GetRelativePath(repositoryRoot, path).Replace('\\', '/'))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }
}
