import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';

final presetLibraryProvider = StateNotifierProvider<PresetLibraryNotifier, PresetLibraryState>((ref) {
  final repo = ref.watch(repositoryProvider);
  return PresetLibraryNotifier(repo);
});

class PresetLibraryState {
  const PresetLibraryState({
    this.presets = const <StoredGenerationConfig>[],
    this.tags = const <String>[],
    this.selectedTag,
  });

  final List<StoredGenerationConfig> presets;
  final List<String> tags;
  final String? selectedTag;

  PresetLibraryState copyWith({
    List<StoredGenerationConfig>? presets,
    List<String>? tags,
    String? selectedTag,
    bool clearSelectedTag = false,
  }) {
    return PresetLibraryState(
      presets: presets ?? this.presets,
      tags: tags ?? this.tags,
      selectedTag: clearSelectedTag ? null : (selectedTag ?? this.selectedTag),
    );
  }
}

class PresetLibraryNotifier extends StateNotifier<PresetLibraryState> {
  PresetLibraryNotifier(this._repository) : super(const PresetLibraryState()) {
    unawaited(reload());
  }

  final GenerationConfigRepository _repository;

  Future<void> seedDefaults(Iterable<GenerationConfig> defaults) async {
    await _repository.seedIfEmpty(defaults);
    await reload();
  }

  Future<void> save(GenerationConfig config) async {
    await _repository.save(config);
    await reload();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await reload();
  }

  Future<void> reload() async {
    final tags = _repository.getAllTags();
    var selectedTag = state.selectedTag;
    if (selectedTag != null && !tags.contains(selectedTag)) {
      selectedTag = null;
    }
    final normalizedTag = selectedTag?.trim().toLowerCase();
    final allStored = _repository.getAllStored();
    final presets = normalizedTag == null
        ? allStored
        : allStored
              .where((item) => item.tags.any((tag) => tag.trim().toLowerCase() == normalizedTag))
              .toList(growable: false);
    state = PresetLibraryState(presets: presets, tags: tags, selectedTag: selectedTag);
  }

  Future<void> selectTag(String? tag) async {
    state = state.copyWith(selectedTag: tag, clearSelectedTag: tag == null);
    await reload();
  }
}
