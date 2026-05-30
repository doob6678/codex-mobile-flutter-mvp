class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.trusted,
  });

  final String id;
  final String name;
  final String rootPath;
  final bool trusted;

  factory ProjectSummary.fromJson(Map<String, Object?> json) {
    return ProjectSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled project',
      rootPath: json['rootPath'] as String? ?? json['root'] as String? ?? '',
      trusted: json['trusted'] as bool? ?? true,
    );
  }
}
