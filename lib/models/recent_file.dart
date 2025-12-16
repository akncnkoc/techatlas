class RecentFile {
  final String path;
  final String name;
  final DateTime addedAt;

  RecentFile({
    required this.path,
    required this.name,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      path: json['path'],
      name: json['name'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }
}
