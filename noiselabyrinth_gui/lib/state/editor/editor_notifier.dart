import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart'
    hide SourceNode, ProcessorNode; // Hide to avoid conflicts with our editor nodes
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier() : super(const EditorState());

  // ---------- open / new ----------

  void newConfig() {
    final config = GenerationConfig(
      metadata: MetadataConfig(name: 'Untitled'),
      render: RenderConfig(),
      mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig()),
      layers: [
        LayerConfig(
          id: 'layer_1',
          source: SourceConfig(
            type: SourceType.noise,
            noiseConfig: NoiseConfig(color: NoiseColor.white, band: BandConfig()),
          ),
        ),
      ],
    );
    final issues = _buildValidationIssues(config);
    state = EditorState(config: config, isDirty: true, validationIssues: issues);
  }

  void openConfig(GenerationConfig config) {
    final issues = _buildValidationIssues(config);
    state = EditorState(config: config, isDirty: false, validationIssues: issues);
  }

  // ---------- selection ----------

  void selectNode(EditorNode? node) {
    state = state.copyWith(selectedNode: node, clearSelection: node == null);
  }

  // ---------- metadata ----------

  void updateMetadata(MetadataConfig metadata) {
    if (state.config == null) return;
    final config = state.config!;
    config.metadata.name = metadata.name;
    config.metadata.description = metadata.description;
    config.metadata.tags = metadata.tags;
    config.metadata.version = metadata.version;
    _commit(config);
  }

  // ---------- render ----------

  void updateRender(RenderConfig render) {
    if (state.config == null) return;
    final config = state.config!;
    config.render = render;
    _commit(config);
  }

  // ---------- mix ----------

  void updateMix(MixConfig mix) {
    if (state.config == null) return;
    final config = state.config!;
    config.mix.mix = mix.mix;
    config.mix.dither.enabled = mix.dither.enabled;
    config.mix.dither.type = mix.dither.type;
    config.mix.dither.bitDepth = mix.dither.bitDepth;
    config.mix.dither.amount = mix.dither.amount;
    config.mix.normalization.enabled = mix.normalization.enabled;
    config.mix.normalization.targetDb = mix.normalization.targetDb;
    _commit(config);
  }

  // ---------- layers ----------

  void addLayer() {
    if (state.config == null) return;
    final config = state.config!;
    final id = _uniqueId('layer', config.layers.map((l) => l.id).toSet());
    final newLayer = LayerConfig(
      id: id,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(color: NoiseColor.white, band: BandConfig()),
      ),
    );
    config.layers = [...config.layers, newLayer];
    _commit(config);
  }

  void updateLayer(LayerConfig updated) {
    if (state.config == null) return;
    final config = state.config!;
    config.layers = [for (final l in config.layers) l.id == updated.id ? updated : l];
    // Update selection if the selected node references this layer by id.
    final sel = state.selectedNode;
    EditorNode? newSel;
    if (sel is LayerNode && sel.layer.id == updated.id) {
      newSel = LayerNode(updated);
    } else if (sel is SourceNode && sel.layer.id == updated.id) {
      newSel = SourceNode(updated);
    } else if (sel is ProcessorNode && sel.layer.id == updated.id) {
      final proc = updated.processors.firstWhere((p) => p.id == sel.processor.id, orElse: () => sel.processor);
      newSel = ProcessorNode(updated, proc);
    } else if (sel is ModulationNode && sel.layer.id == updated.id) {
      final mod = updated.modulations.firstWhere((m) => m.id == sel.modulation.id, orElse: () => sel.modulation);
      newSel = ModulationNode(updated, mod);
    } else if (sel is EventNode && sel.layer.id == updated.id) {
      final ev = updated.events.firstWhere((e) => e.id == sel.event.id, orElse: () => sel.event);
      newSel = EventNode(updated, ev);
    }
    _commit(config, selectedNode: newSel ?? sel);
  }

  void removeLayer(String layerId) {
    if (state.config == null) return;
    final config = state.config!;
    config.layers = config.layers.where((l) => l.id != layerId).toList();
    final sel = state.selectedNode;
    final clearSel = _selectionBelongsToLayer(sel, layerId);
    _commit(config, selectedNode: clearSel ? null : sel, clearSel: clearSel);
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (state.config == null) return;
    final config = state.config!;
    final layers = [...config.layers];
    final item = layers.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    layers.insert(insertAt, item);
    config.layers = layers;
    _commit(config);
  }

  // ---------- processors ----------

  void addProcessor(String layerId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final id = _uniqueId('processor', layer.processors.map((p) => p.id).toSet());
    final proc = ProcessorConfig(id: id, type: ProcessorType.biquad, biquad: BiquadConfig());
    final updated = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: [...layer.processors, proc],
      modulations: layer.modulations,
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updated : l];
    _commit(config, selectedNode: ProcessorNode(updated, proc));
  }

  void updateProcessor(String layerId, ProcessorConfig updated) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: [for (final p in layer.processors) p.id == updated.id ? updated : p],
      modulations: layer.modulations,
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    EditorNode? newSel;
    if (sel is ProcessorNode && sel.layer.id == layerId && sel.processor.id == updated.id) {
      newSel = ProcessorNode(updatedLayer, updated);
    }
    _commit(config, selectedNode: newSel ?? sel);
  }

  void removeProcessor(String layerId, String processorId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors.where((p) => p.id != processorId).toList(),
      modulations: layer.modulations,
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    final clearSel = sel is ProcessorNode && sel.layer.id == layerId && sel.processor.id == processorId;
    _commit(config, selectedNode: clearSel ? null : sel, clearSel: clearSel);
  }

  void reorderProcessor(String layerId, int oldIndex, int newIndex) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final procs = [...layer.processors];
    final item = procs.removeAt(oldIndex);
    procs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: procs,
      modulations: layer.modulations,
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    _commit(config);
  }

  // ---------- modulations ----------

  void addModulation(String layerId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final id = _uniqueId('mod', layer.modulations.map((m) => m.id).toSet());
    final mod = ModulationConfig(id: id, type: ModulationType.lfo, lfoConfig: LfoConfig(), targets: const []);
    final updated = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: [...layer.modulations, mod],
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updated : l];
    _commit(config, selectedNode: ModulationNode(updated, mod));
  }

  void updateModulation(String layerId, ModulationConfig updated) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: [for (final m in layer.modulations) m.id == updated.id ? updated : m],
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    EditorNode? newSel;
    if (sel is ModulationNode && sel.layer.id == layerId && sel.modulation.id == updated.id) {
      newSel = ModulationNode(updatedLayer, updated);
    }
    _commit(config, selectedNode: newSel ?? sel);
  }

  void removeModulation(String layerId, String modulationId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: layer.modulations.where((m) => m.id != modulationId).toList(),
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    final clearSel = sel is ModulationNode && sel.layer.id == layerId && sel.modulation.id == modulationId;
    _commit(config, selectedNode: clearSel ? null : sel, clearSel: clearSel);
  }

  // ---------- events ----------

  void addEvent(String layerId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final id = _uniqueId('event', layer.events.map((e) => e.id).toSet());
    final event = EventConfig(id: id, trigger: TriggerConfig(), actions: const []);
    final updated = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: layer.modulations,
      events: [...layer.events, event],
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updated : l];
    _commit(config, selectedNode: EventNode(updated, event));
  }

  void updateEvent(String layerId, EventConfig updated) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: layer.modulations,
      events: [for (final e in layer.events) e.id == updated.id ? updated : e],
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    EditorNode? newSel;
    if (sel is EventNode && sel.layer.id == layerId && sel.event.id == updated.id) {
      newSel = EventNode(updatedLayer, updated);
    }
    _commit(config, selectedNode: newSel ?? sel);
  }

  void removeEvent(String layerId, String eventId) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: layer.source,
      processors: layer.processors,
      modulations: layer.modulations,
      events: layer.events.where((e) => e.id != eventId).toList(),
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    final clearSel = sel is EventNode && sel.layer.id == layerId && sel.event.id == eventId;
    _commit(config, selectedNode: clearSel ? null : sel, clearSel: clearSel);
  }

  // ---------- update source ----------

  void updateSource(String layerId, SourceConfig updated) {
    if (state.config == null) return;
    final config = state.config!;
    final layerIdx = config.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final layer = config.layers[layerIdx];
    final updatedLayer = LayerConfig(
      id: layer.id,
      gain: layer.gain,
      pan: layer.pan,
      source: updated,
      processors: layer.processors,
      modulations: layer.modulations,
      events: layer.events,
    );
    config.layers = [for (final l in config.layers) l.id == layerId ? updatedLayer : l];
    final sel = state.selectedNode;
    EditorNode? newSel;
    if (sel is SourceNode && sel.layer.id == layerId) {
      newSel = SourceNode(updatedLayer);
    }
    _commit(config, selectedNode: newSel ?? sel);
  }

  // ---------- save ----------

  Future<void> saveToRepository(GenerationConfigRepository repo) async {
    if (state.config == null) return;
    await repo.save(state.config!);
    state = state.copyWith(isDirty: false);
  }

  // ---------- helpers ----------

  void _commit(GenerationConfig config, {EditorNode? selectedNode, bool clearSel = false}) {
    final issues = _buildValidationIssues(config);
    state = EditorState(
      config: config,
      selectedNode: clearSel ? null : (selectedNode ?? state.selectedNode),
      isDirty: true,
      validationIssues: issues,
    );
  }

  List<EditorValidationIssue> _buildValidationIssues(GenerationConfig config) {
    final validator = GenerationConfigParser();
    final coreIssues = validator.validate(config);
    return coreIssues.map((issue) {
      return EditorValidationIssue(path: issue.path, message: issue.message, node: _nodeForPath(issue.path, config));
    }).toList();
  }

  EditorNode? _nodeForPath(String path, GenerationConfig config) {
    if (path.startsWith('metadata')) return const MetadataNode();
    if (path.startsWith('render')) return const RenderNode();
    if (path.startsWith('mix')) return const MixNode();

    // layers[N]...
    final layerMatch = RegExp(r'^layers\[(\d+)\]').firstMatch(path);
    if (layerMatch == null) return null;
    final layerIdx = int.tryParse(layerMatch.group(1) ?? '') ?? -1;
    if (layerIdx < 0 || layerIdx >= config.layers.length) return null;
    final layer = config.layers[layerIdx];
    final rest = path.substring(layerMatch.end);

    if (rest.startsWith('.source')) return SourceNode(layer);
    final procMatch = RegExp(r'^\.processors\[(\d+)\]').firstMatch(rest);
    if (procMatch != null) {
      final procIdx = int.tryParse(procMatch.group(1) ?? '') ?? -1;
      if (procIdx >= 0 && procIdx < layer.processors.length) {
        return ProcessorNode(layer, layer.processors[procIdx]);
      }
    }
    final modMatch = RegExp(r'^\.modulations\[(\d+)\]').firstMatch(rest);
    if (modMatch != null) {
      final modIdx = int.tryParse(modMatch.group(1) ?? '') ?? -1;
      if (modIdx >= 0 && modIdx < layer.modulations.length) {
        return ModulationNode(layer, layer.modulations[modIdx]);
      }
    }
    final evMatch = RegExp(r'^\.events\[(\d+)\]').firstMatch(rest);
    if (evMatch != null) {
      final evIdx = int.tryParse(evMatch.group(1) ?? '') ?? -1;
      if (evIdx >= 0 && evIdx < layer.events.length) {
        return EventNode(layer, layer.events[evIdx]);
      }
    }
    return LayerNode(layer);
  }

  String _uniqueId(String prefix, Set<String> existing) {
    var i = 1;
    while (existing.contains('${prefix}_$i')) {
      i++;
    }
    return '${prefix}_$i';
  }

  bool _selectionBelongsToLayer(EditorNode? sel, String layerId) {
    if (sel == null) return false;
    if (sel is LayerNode) return sel.layer.id == layerId;
    if (sel is SourceNode) return sel.layer.id == layerId;
    if (sel is ProcessorNode) return sel.layer.id == layerId;
    if (sel is ModulationNode) return sel.layer.id == layerId;
    if (sel is EventNode) return sel.layer.id == layerId;
    return false;
  }
}
