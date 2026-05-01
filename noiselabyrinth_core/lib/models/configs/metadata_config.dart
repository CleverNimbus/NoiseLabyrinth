class MetadataConfig {
  final String name;
  final String description;
  final List<String> tags;
  final int version;

  const MetadataConfig({
    this.name = '',
    this.description = '',
    this.tags = const [],
    this.version = 0,
  });

  factory MetadataConfig.fromJson(Map<String, dynamic> json) {
    return MetadataConfig(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List? ?? []),
      version: json['version'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tags': tags,
      'version': version,
    };
  }
}
