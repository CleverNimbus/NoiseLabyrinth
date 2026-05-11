import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';
import 'package:sembast/sembast.dart';

abstract class GenerationConfigRepository {
  List<StoredGenerationConfig> getAllStored();
  List<GenerationConfig> getAllConfigs();
  List<String> getAllTags();
  List<GenerationConfig> getConfigsByTag(String tag);
  Future<int> save(GenerationConfig config);
  Future<void> saveAll(Iterable<GenerationConfig> configs);
  Future<void> seedIfEmpty(Iterable<GenerationConfig> configs);
}

class SembastGenerationConfigRepository implements GenerationConfigRepository {
  SembastGenerationConfigRepository(Database database)
    : _store = intMapStoreFactory.store('generation_configs'),
      _database = database;

  final Database _database;
  final StoreRef<int, Map<String, dynamic>> _store;

  @override
  List<StoredGenerationConfig> getAllStored() {
    final records = _store.findSync(_database);
    final items = records.map((record) {
      final data = Map<String, dynamic>.from(record.value);
      data['id'] = record.key;
      return StoredGenerationConfig.fromJson(data);
    }).toList();

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

    final sorted = tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  @override
  List<GenerationConfig> getConfigsByTag(String tag) {
    final normalizedTag = tag.trim().toLowerCase();
    return getAllStored()
        .where((item) => item.tags.any((itemTag) => itemTag.trim().toLowerCase() == normalizedTag))
        .map((item) => item.toConfig())
        .toList(growable: false);
  }

  @override
  Future<int> save(GenerationConfig config) async {
    final stored = StoredGenerationConfig.fromConfig(config);
    final json = stored.toJson();

    // If id exists, update; otherwise, add as new
    if (stored.id != null) {
      await _store.record(stored.id!).update(_database, json);
      return stored.id!;
    } else {
      final key = await _store.add(_database, json);
      return key;
    }
  }

  @override
  Future<void> saveAll(Iterable<GenerationConfig> configs) async {
    for (final config in configs) {
      await save(config);
    }
  }

  @override
  Future<void> seedIfEmpty(Iterable<GenerationConfig> configs) async {
    final isEmpty = _store.countSync(_database) == 0;
    if (isEmpty) {
      await saveAll(configs);
    }
  }
}
