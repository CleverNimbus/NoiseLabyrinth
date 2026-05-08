/// Metadata for a generation preset.
class MetadataConfig {
  MetadataConfig({
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

  /// Human-readable name of the generation preset.
  String name;

  /// Optional free-text description of the preset intent or content.
  String description;

  /// Optional classification tags for search and organization.
  List<String> tags;

  /// Preset version number for configuration evolution.
  int version;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tags': tags,
      'version': version,
    };
  }
}
