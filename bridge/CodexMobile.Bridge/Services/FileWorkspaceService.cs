using System.Security.Cryptography;
using System.Text;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class FileWorkspaceService
{
    private static readonly IReadOnlyDictionary<string, string> ContentTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        [".md"] = "text/markdown; charset=utf-8",
        [".markdown"] = "text/markdown; charset=utf-8",
        [".html"] = "text/html; charset=utf-8",
        [".htm"] = "text/html; charset=utf-8",
        [".txt"] = "text/plain; charset=utf-8",
        [".json"] = "application/json; charset=utf-8",
        [".dart"] = "text/plain; charset=utf-8",
        [".cs"] = "text/plain; charset=utf-8",
        [".png"] = "image/png",
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".gif"] = "image/gif",
        [".webp"] = "image/webp",
        [".bmp"] = "image/bmp",
        [".svg"] = "image/svg+xml",
        [".pdf"] = "application/pdf",
    };

    private readonly ProjectStore projects;

    public FileWorkspaceService(ProjectStore projects)
    {
        this.projects = projects;
    }

    public IReadOnlyList<CodexFileEntry> List(string projectId, string relativePath)
    {
        var directoryPath = projects.ResolveProjectPath(projectId, relativePath);
        if (!Directory.Exists(directoryPath))
        {
            return Array.Empty<CodexFileEntry>();
        }

        var project = projects.GetProject(projectId);
        return Directory.EnumerateFileSystemEntries(directoryPath)
            .Select(path => ToEntry(project.RootPath, path))
            .OrderByDescending(entry => entry.IsDirectory)
            .ThenBy(entry => entry.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public FileReadResponse ReadText(string projectId, string relativePath)
    {
        var path = projects.ResolveProjectPath(projectId, relativePath);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("File not found.", path);
        }

        var content = File.ReadAllText(path, Encoding.UTF8);
        var info = new FileInfo(path);
        return new FileReadResponse(
            projectId,
            relativePath,
            content,
            ComputeHash(path),
            info.Length,
            DetectLanguage(path),
            GetContentType(path));
    }

    public FileDownloadResponse Download(string projectId, string relativePath)
    {
        var path = projects.ResolveProjectPath(projectId, relativePath);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("File not found.", path);
        }

        var bytes = File.ReadAllBytes(path);
        var info = new FileInfo(path);
        return new FileDownloadResponse(
            projectId,
            relativePath,
            Path.GetFileName(path),
            GetContentType(path),
            info.Length,
            bytes,
            DetectLanguage(path));
    }

    public FileHashResponse Hash(string projectId, string relativePath)
    {
        var path = projects.ResolveProjectPath(projectId, relativePath);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("File not found.", path);
        }

        return new FileHashResponse(projectId, relativePath, ComputeHash(path));
    }

    public FilePatchResponse ApplyPatch(FilePatchRequest request)
    {
        var path = projects.ResolveProjectPath(request.ProjectId, request.Path);
        if (!File.Exists(path))
        {
            throw new FileNotFoundException("File not found.", path);
        }

        var previousHash = ComputeHash(path);
        if (!string.Equals(previousHash, request.ExpectedHash, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("File changed since the patch was proposed.");
        }

        File.WriteAllText(path, request.ReplacementText, Encoding.UTF8);
        var newHash = ComputeHash(path);
        return new FilePatchResponse(request.ProjectId, request.Path, previousHash, newHash, Applied: true);
    }

    private static CodexFileEntry ToEntry(string projectRoot, string path)
    {
        var attributes = File.GetAttributes(path);
        var isDirectory = attributes.HasFlag(FileAttributes.Directory);
        var name = Path.GetFileName(path);
        var relative = Path.GetRelativePath(projectRoot, path);
        var modifiedAt = isDirectory ? Directory.GetLastWriteTimeUtc(path) : File.GetLastWriteTimeUtc(path);
        var size = isDirectory ? 0 : new FileInfo(path).Length;
        return new CodexFileEntry(name, relative, isDirectory, size, new DateTimeOffset(modifiedAt, TimeSpan.Zero));
    }

    private static string ComputeHash(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
    }

    private static string DetectLanguage(string path)
    {
        return Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".md" or ".markdown" => "markdown",
            ".dart" => "dart",
            ".cs" => "csharp",
            ".java" => "java",
            ".js" => "javascript",
            ".ts" => "typescript",
            ".json" => "json",
            ".ps1" => "powershell",
            _ => "text",
        };
    }

    private static string GetContentType(string path)
    {
        var extension = Path.GetExtension(path);
        return ContentTypes.TryGetValue(extension, out var contentType)
            ? contentType
            : "application/octet-stream";
    }
}
