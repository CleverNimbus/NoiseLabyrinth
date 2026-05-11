import 'dart:convert';

import 'package:noiselabyrinth_core/models/configs/generation_config.dart';

/// Model for storing GenerationConfig in Sembast database.
/// No ObjectBox decorators needed - Sembast uses serialization instead.
class StoredGenerationConfig {
  StoredGenerationConfig({
    this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.tagsJson,
    required this.configJson,
    int? updatedAtEpochMs,
  }) : updatedAtEpochMs = updatedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;

  factory StoredGenerationConfig.fromConfig(GenerationConfig config, {int? id}) {
    return StoredGenerationConfig(
      id: id,
      name: config.metadata.name,
      description: config.metadata.description,
      version: config.metadata.version,
      tagsJson: jsonEncode(config.metadata.tags),
      configJson: jsonEncode(config.toJson()),
    );
  }

  factory StoredGenerationConfig.fromJson(Map<String, dynamic> json) {
    return StoredGenerationConfig(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as int,
      tagsJson: json['tagsJson'] as String,
      configJson: json['configJson'] as String,
      updatedAtEpochMs: json['updatedAtEpochMs'] as int?,
    );
  }

  int? id;
  final String name;
  final String description;
  final int version;
  final String tagsJson;
  final String configJson;
  final int updatedAtEpochMs;

  List<String> get tags {
    final decoded = jsonDecode(tagsJson);
    if (decoded is! List) {
      return const <String>[];
    }

    return decoded.whereType<String>().toList(growable: false);
  }

  GenerationConfig toConfig() {
    final decoded = jsonDecode(configJson);
    return GenerationConfig.fromJson(decoded as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'version': version,
      'tagsJson': tagsJson,
      'configJson': configJson,
      'updatedAtEpochMs': updatedAtEpochMs,
    };
  }

  void updateFromConfig(GenerationConfig config) {
    // Create a new instance since fields are final
    // This method should be replaced in the repository layer
    throw UnsupportedError('Use repository.save() instead of updating instance directly');
  }
}
