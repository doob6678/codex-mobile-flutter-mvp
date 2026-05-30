using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class ProjectStore
{
    private readonly object gate = new();
    private readonly Dictionary<string, ProjectRecord> projects = new(StringComparer.OrdinalIgnoreCase);

    public ProjectRecord AddProject(string name, string rootPath)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Project name is required.", nameof(name));
        }

        var canonicalRoot = CanonicalizeRoot(rootPath);
        var project = new ProjectRecord(NewId("project"), name.Trim(), canonicalRoot, DateTimeOffset.UtcNow);

        lock (gate)
        {
            projects[project.Id] = project;
        }

        return project;
    }

    public int AddConfiguredProjects(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return 0;
        }

        var added = 0;
        foreach (var entry in value.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var separator = entry.IndexOf('=', StringComparison.Ordinal);
            var name = separator > 0 ? entry[..separator].Trim() : Path.GetFileName(entry.Trim());
            var rootPath = separator > 0 ? entry[(separator + 1)..].Trim() : entry.Trim();

            if (TryAddConfiguredProject(name, rootPath))
            {
                added++;
            }
        }

        return added;
    }

    public bool TryAddConfiguredProject(string name, string rootPath)
    {
        if (string.IsNullOrWhiteSpace(rootPath) || !Directory.Exists(rootPath))
        {
            return false;
        }

        var canonicalRoot = CanonicalizeRoot(rootPath);
        lock (gate)
        {
            if (projects.Values.Any(project => IsSamePath(project.RootPath, canonicalRoot)))
            {
                return false;
            }
        }

        AddProject(string.IsNullOrWhiteSpace(name) ? Path.GetFileName(canonicalRoot) : name, canonicalRoot);
        return true;
    }

    public IReadOnlyList<ProjectRecord> ListProjects()
    {
        lock (gate)
        {
            return projects.Values.OrderBy(project => project.Name, StringComparer.OrdinalIgnoreCase).ToArray();
        }
    }

    public ProjectRecord GetProject(string projectId)
    {
        lock (gate)
        {
            if (projects.TryGetValue(projectId, out var project))
            {
                return project;
            }
        }

        throw new KeyNotFoundException($"Project '{projectId}' is not authorized.");
    }

    public string ResolveProjectPath(string projectId, string relativePath)
    {
        var project = GetProject(projectId);
        var candidate = Path.GetFullPath(Path.Combine(project.RootPath, relativePath ?? "."));
        var root = project.RootPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

        if (IsSamePath(candidate, root))
        {
            return root;
        }

        var rootWithSeparator = root + Path.DirectorySeparatorChar;
        if (!candidate.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Path escapes the authorized project root.");
        }

        return candidate;
    }

    private static string CanonicalizeRoot(string rootPath)
    {
        if (string.IsNullOrWhiteSpace(rootPath))
        {
            throw new ArgumentException("Root path is required.", nameof(rootPath));
        }

        var fullPath = Path.GetFullPath(rootPath);
        if (!Directory.Exists(fullPath))
        {
            throw new DirectoryNotFoundException($"Project root does not exist: {fullPath}");
        }

        return fullPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    private static bool IsSamePath(string left, string right)
    {
        return string.Equals(
            left.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            right.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            StringComparison.OrdinalIgnoreCase);
    }

    private static string NewId(string prefix) => $"{prefix}_{Guid.NewGuid():N}";
}
