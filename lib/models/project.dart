class Project {
  final String project_id;
  final String name;
  final String? description;
  final String? status;
  final int? created_at;

  Project({
    required this.project_id,
    required this.name,
    this.description,
    this.status,
    this.created_at,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      project_id: json['project_id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      status: json['status'],
      created_at: json['created_at'],
    );
  }
}
