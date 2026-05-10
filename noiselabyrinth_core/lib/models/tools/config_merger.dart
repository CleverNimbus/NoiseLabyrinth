import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';

/// Merges two or more [GenerationConfig] objects into the first one.
///
/// - Layers whose [id] does not exist in [base] are appended.
/// - For layers that already exist in [base] (matched by id), processors,
///   modulations, and events whose [id] is not already present are appended.
///   Existing items are left untouched.
class ConfigMerger {
  /// Merges [others] into [base] and returns [base].
  static GenerationConfig merge(
    GenerationConfig base,
    List<GenerationConfig> others,
  ) {
    for (final source in others) {
      _mergeInto(base, source);
    }
    return base;
  }

  static void _mergeInto(GenerationConfig base, GenerationConfig source) {
    for (final sourceLayer in source.layers) {
      final existingIndex = base.layers.indexWhere((l) => l.id == sourceLayer.id);
      if (existingIndex == -1) {
        base.layers = List<LayerConfig>.of(base.layers)..add(sourceLayer);
      } else {
        _mergeLayer(base.layers[existingIndex], sourceLayer);
      }
    }
  }

  static void _mergeLayer(LayerConfig base, LayerConfig source) {
    final existingProcessorIds = base.processors.map((p) => p.id).toSet();
    final newProcessors = source.processors.where((p) => !existingProcessorIds.contains(p.id));
    if (newProcessors.isNotEmpty) {
      base.processors = List.of(base.processors)..addAll(newProcessors);
    }

    final existingModulationIds = base.modulations.map((m) => m.id).toSet();
    final newModulations = source.modulations.where((m) => !existingModulationIds.contains(m.id));
    if (newModulations.isNotEmpty) {
      base.modulations = List.of(base.modulations)..addAll(newModulations);
    }

    final existingEventIds = base.events.map((e) => e.id).toSet();
    final newEvents = source.events.where((e) => !existingEventIds.contains(e.id));
    if (newEvents.isNotEmpty) {
      base.events = List.of(base.events)..addAll(newEvents);
    }
  }
}
