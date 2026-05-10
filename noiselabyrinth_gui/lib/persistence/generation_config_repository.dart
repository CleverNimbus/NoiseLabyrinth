import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_gui/objectbox.g.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';

abstract class GenerationConfigRepository {
  List<StoredGenerationConfig> getAllStored();
  List<GenerationConfig> getAllConfigs();
  List<String> getAllTags();
  List<GenerationConfig> getConfigsByTag(String tag);
  Future<int> save(GenerationConfig config);
  Future<void> saveAll(Iterable<GenerationConfig> configs);
  Future<void> seedIfEmpty(Iterable<GenerationConfig> configs);
}

class ObjectBoxGenerationConfigRepository
    implements GenerationConfigRepository {
  ObjectBoxGenerationConfigRepository(Store store)
    : _box = store.box<StoredGenerationConfig>();

  final Box<StoredGenerationConfig> _box;

  @override
  List<StoredGenerationConfig> getAllStored() {
    final items = _box.getAll();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  @override
  List<GenerationConfig> getAllConfigs() {
    return getAllStored().map((item) => item.toConfig()).toList(growable: false);
  }

  @override
  List<String> getAllTags() {
    final tags = <String>{};
    for (final item in getAllStored()) {
      tags.addAll(item.tags);
    }

    final sorted = tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  @override
  List<GenerationConfig> getConfigsByTag(String tag) {
    final normalizedTag = tag.trim().toLowerCase();
    return getAllStored()
        .where(
          (item) => item.tags.any(
            (itemTag) => itemTag.trim().toLowerCase() == normalizedTag,
          ),
        )
        .map((item) => item.toConfig())
        .toList(growable: false);
  }

  @override
  Future<int> save(GenerationConfig config) async {
    final existing = _findByName(config.metadata.name);
    final stored = existing ?? StoredGenerationConfig.fromConfig(config);
    stored.updateFromConfig(config);
    return _box.put(stored);
  }

  @override
  Future<void> saveAll(Iterable<GenerationConfig> configs) async {
    final storedItems = <StoredGenerationConfig>[];
    for (final config in configs) {
      final existing = _findByName(config.metadata.name);
      final stored = existing ?? StoredGenerationConfig.fromConfig(config);
      stored.updateFromConfig(config);
      storedItems.add(stored);
    }

    _box.putMany(storedItems);
  }

  @override
  Future<void> seedIfEmpty(Iterable<GenerationConfig> configs) async {
    if (_box.isEmpty()) {
      await saveAll(configs);
    }
  }

  StoredGenerationConfig? _findByName(String name) {
    final query = _box.query(StoredGenerationConfig_.name.equals(name)).build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }
}
