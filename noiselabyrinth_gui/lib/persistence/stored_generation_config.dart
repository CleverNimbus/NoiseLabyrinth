import 'dart:convert';

import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class StoredGenerationConfig {
  StoredGenerationConfig({
    this.id = 0,
    required this.name,
    required this.description,
    required this.version,
    required this.tagsJson,
    required this.configJson,
    int? updatedAtEpochMs,
  }) : updatedAtEpochMs =
           updatedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch;

  factory StoredGenerationConfig.fromConfig(
    GenerationConfig config, {
    int id = 0,
  }) {
    return StoredGenerationConfig(
      id: id,
      name: config.metadata.name,
      description: config.metadata.description,
      version: config.metadata.version,
      tagsJson: jsonEncode(config.metadata.tags),
      configJson: jsonEncode(config.toJson()),
    );
  }

  @Id()
  int id;

  @Index()
  String name;

  String description;
  int version;
  String tagsJson;
  String configJson;
  int updatedAtEpochMs;

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

  void updateFromConfig(GenerationConfig config) {
    name = config.metadata.name;
    description = config.metadata.description;
    version = config.metadata.version;
    tagsJson = jsonEncode(config.metadata.tags);
    configJson = jsonEncode(config.toJson());
    updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
  }
}
