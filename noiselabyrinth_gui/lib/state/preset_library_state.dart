import 'package:flutter/material.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';

class PresetLibraryState extends ChangeNotifier {
  PresetLibraryState(this._repository);

  final GenerationConfigRepository _repository;

  List<GenerationConfig> _presets = const <GenerationConfig>[];
  List<String> _tags = const <String>[];
  String? _selectedTag;

  List<GenerationConfig> get presets => _presets;
  List<String> get tags => _tags;
  String? get selectedTag => _selectedTag;

  Future<void> seedDefaults(Iterable<GenerationConfig> defaults) async {
    await _repository.seedIfEmpty(defaults);
    await reload();
  }

  Future<void> save(GenerationConfig config) async {
    await _repository.save(config);
    await reload();
  }

  Future<void> reload() async {
    _tags = _repository.getAllTags();
    if (_selectedTag != null && !_tags.contains(_selectedTag)) {
      _selectedTag = null;
    }
    _presets = _selectedTag == null
        ? _repository.getAllConfigs()
        : _repository.getConfigsByTag(_selectedTag!);
    notifyListeners();
  }

  Future<void> selectTag(String? tag) async {
    _selectedTag = tag;
    await reload();
  }
}
