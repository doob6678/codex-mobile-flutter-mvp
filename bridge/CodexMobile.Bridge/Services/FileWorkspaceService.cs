using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Text;
using CodexMobile.Bridge.Models;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Presentation;
using A = DocumentFormat.OpenXml.Drawing;
using NPOI.XWPF.Extractor;
using NPOI.XWPF.UserModel;

namespace CodexMobile.Bridge.Services;

public sealed class FileWorkspaceService
{
    private static readonly IReadOnlyDictionary<string, string> ContentTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        [".md"] = "text/markdown; charset=utf-8",
        [".markdown"] = "text/markdown; charset=utf-8",
        [".doc"] = "application/msword",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        [".ppt"] = "application/vnd.ms-powerpoint",
        [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
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

        var content = ReadPreviewText(path);
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
            ".doc" or ".docx" => "document",
            ".ppt" or ".pptx" => "presentation",
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

    private static string ReadPreviewText(string path)
    {
        return Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".docx" => ExtractDocxText(path),
            ".doc" => ExtractDocText(path),
            ".pptx" => ExtractPptxText(path),
            ".ppt" => ExtractPptText(path),
            _ => File.ReadAllText(path, Encoding.UTF8),
        };
    }

    private static string ExtractDocxText(string path)
    {
        using var fs = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var document = new XWPFDocument(fs);
        try
        {
            var extractor = new XWPFWordExtractor(document);
            return extractor.Text.Trim();
        }
        finally
        {
            document.Close();
        }
    }

    private static string ExtractDocText(string path)
    {
        return ExecuteWordCom(path, document => Convert.ToString(document.Content.Text)?.Trim() ?? string.Empty);
    }

    private static string ExtractPptxText(string path)
    {
        using var fs = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var presentation = PresentationDocument.Open(fs, false);
        var builder = new StringBuilder();
        var presentationPart = presentation.PresentationPart;
        if (presentationPart?.Presentation?.SlideIdList == null)
        {
            return string.Empty;
        }

        var slideNumber = 0;
        foreach (var slideId in presentationPart.Presentation.SlideIdList.Elements<SlideId>())
        {
            if (presentationPart.GetPartById(slideId.RelationshipId!) is not SlidePart slidePart)
            {
                continue;
            }

            slideNumber++;
            AppendLine(builder, $"[Slide {slideNumber}]");
            foreach (var text in slidePart.Slide.Descendants<A.Text>())
            {
                AppendLine(builder, text.Text);
            }
        }

        return builder.ToString().Trim();
    }

    private static string ExtractPptText(string path)
    {
        return ExecutePowerPointCom(path, presentation =>
        {
            var builder = new StringBuilder();
            dynamic slides = presentation.Slides;
            for (var i = 1; i <= slides.Count; i++)
            {
                dynamic slide = slides[i];
                AppendLine(builder, $"[Slide {i}]");
                dynamic shapes = slide.Shapes;
                for (var j = 1; j <= shapes.Count; j++)
                {
                    dynamic shape = shapes[j];
                    try
                    {
                        if (Convert.ToInt32(shape.HasTextFrame) == 0)
                        {
                            continue;
                        }

                        dynamic textFrame = shape.TextFrame;
                        if (textFrame == null || Convert.ToInt32(textFrame.HasText) == 0)
                        {
                            continue;
                        }

                        AppendLine(builder, Convert.ToString(textFrame.TextRange.Text));
                    }
                    catch
                    {
                    }
                }
            }

            return builder.ToString().Trim();
        });
    }

    private static void AppendLine(StringBuilder builder, string? value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            builder.AppendLine(value.Trim());
        }
    }

    private static string ExecuteWordCom(string path, Func<dynamic, string> extract)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("DOC preview requires Windows and Microsoft Word.");
        }

        var appType = Type.GetTypeFromProgID("Word.Application")
            ?? throw new PlatformNotSupportedException("Microsoft Word is not installed for DOC preview.");

        dynamic? app = null;
        dynamic? document = null;
        dynamic? documents = null;
        try
        {
            app = Activator.CreateInstance(appType)
                ?? throw new InvalidOperationException("Failed to start Microsoft Word.");
            app.Visible = false;
            app.DisplayAlerts = 0;
            documents = app.Documents;
            document = documents.Open(path, ReadOnly: true, Visible: false, AddToRecentFiles: false);
            return extract(document);
        }
        finally
        {
            try
            {
                document?.Close(false);
            }
            catch
            {
            }

            try
            {
                app?.Quit();
            }
            catch
            {
            }

            ReleaseComObject(document);
            ReleaseComObject(documents);
            ReleaseComObject(app);
        }
    }

    private static string ExecutePowerPointCom(string path, Func<dynamic, string> extract)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("PPT preview requires Windows and Microsoft PowerPoint.");
        }

        var appType = Type.GetTypeFromProgID("PowerPoint.Application")
            ?? throw new PlatformNotSupportedException("Microsoft PowerPoint is not installed for PPT preview.");

        dynamic? app = null;
        dynamic? presentations = null;
        dynamic? presentation = null;
        try
        {
            app = Activator.CreateInstance(appType)
                ?? throw new InvalidOperationException("Failed to start Microsoft PowerPoint.");
            app.Visible = false;
            presentations = app.Presentations;
            presentation = presentations.Open(path, ReadOnly: true, Untitled: false, WithWindow: false);
            return extract(presentation);
        }
        finally
        {
            try
            {
                presentation?.Close();
            }
            catch
            {
            }

            try
            {
                app?.Quit();
            }
            catch
            {
            }

            ReleaseComObject(presentation);
            ReleaseComObject(presentations);
            ReleaseComObject(app);
        }
    }

    private static void ReleaseComObject(object? value)
    {
        if (value is null || !Marshal.IsComObject(value))
        {
            return;
        }

        try
        {
            Marshal.FinalReleaseComObject(value);
        }
        catch
        {
        }
    }
}
