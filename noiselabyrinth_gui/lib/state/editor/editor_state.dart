import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';

class LayerPreviewSelection {
  const LayerPreviewSelection({
    this.layerEnabled = true,
    this.sourceEnabled = true,
    this.disabledProcessorIds = const <String>{},
    this.disabledModulationIds = const <String>{},
    this.disabledEventIds = const <String>{},
  });

  final bool layerEnabled;
  final bool sourceEnabled;
  final Set<String> disabledProcessorIds;
  final Set<String> disabledModulationIds;
  final Set<String> disabledEventIds;

  bool isProcessorEnabled(String processorId) => !disabledProcessorIds.contains(processorId);
  bool isModulationEnabled(String modulationId) => !disabledModulationIds.contains(modulationId);
  bool isEventEnabled(String eventId) => !disabledEventIds.contains(eventId);

  LayerPreviewSelection copyWith({
    bool? layerEnabled,
    bool? sourceEnabled,
    Set<String>? disabledProcessorIds,
    Set<String>? disabledModulationIds,
    Set<String>? disabledEventIds,
  }) {
    return LayerPreviewSelection(
      layerEnabled: layerEnabled ?? this.layerEnabled,
      sourceEnabled: sourceEnabled ?? this.sourceEnabled,
      disabledProcessorIds: disabledProcessorIds ?? this.disabledProcessorIds,
      disabledModulationIds: disabledModulationIds ?? this.disabledModulationIds,
      disabledEventIds: disabledEventIds ?? this.disabledEventIds,
    );
  }
}

class EditorValidationIssue {
  const EditorValidationIssue({required this.message, required this.path, this.node});

  final String message;
  final String path;
  final EditorNode? node;
}

class EditorState {
  const EditorState({
    this.config,
    this.storedConfigId,
    this.selectedNode,
    this.isDirty = false,
    this.validationIssues = const [],
    this.previewLayerSelections = const {},
    this.configRevision = 0,
  });

  final GenerationConfig? config;
  final int? storedConfigId;
  final EditorNode? selectedNode;
  final bool isDirty;
  final List<EditorValidationIssue> validationIssues;
  final Map<String, LayerPreviewSelection> previewLayerSelections;
  final int configRevision;

  bool get isOpen => config != null;

  LayerPreviewSelection selectionForLayer(String layerId) {
    return previewLayerSelections[layerId] ?? const LayerPreviewSelection();
  }

  bool isLayerPreviewEnabled(String layerId) {
    return selectionForLayer(layerId).layerEnabled;
  }

  bool isSourcePreviewEnabled(String layerId) {
    return selectionForLayer(layerId).sourceEnabled;
  }

  bool isProcessorPreviewEnabled(String layerId, String processorId) {
    return selectionForLayer(layerId).isProcessorEnabled(processorId);
  }

  bool isModulationPreviewEnabled(String layerId, String modulationId) {
    return selectionForLayer(layerId).isModulationEnabled(modulationId);
  }

  bool isEventPreviewEnabled(String layerId, String eventId) {
    return selectionForLayer(layerId).isEventEnabled(eventId);
  }

  EditorState copyWith({
    GenerationConfig? config,
    int? storedConfigId,
    bool clearStoredConfigId = false,
    EditorNode? selectedNode,
    bool clearSelection = false,
    bool? isDirty,
    List<EditorValidationIssue>? validationIssues,
    Map<String, Set<String>>? previewDisabledProcessorsByLayer,
    Map<String, Set<String>>? previewDisabledModulationsByLayer,
    Map<String, Set<String>>? previewDisabledEventsByLayer,
    Map<String, LayerPreviewSelection>? previewLayerSelections,
    int? configRevision,
  }) {
    return EditorState(
      config: config ?? this.config,
      storedConfigId: clearStoredConfigId ? null : (storedConfigId ?? this.storedConfigId),
      selectedNode: clearSelection ? null : (selectedNode ?? this.selectedNode),
      isDirty: isDirty ?? this.isDirty,
      validationIssues: validationIssues ?? this.validationIssues,
      previewLayerSelections: previewLayerSelections ?? this.previewLayerSelections,
      configRevision: configRevision ?? this.configRevision,
    );
  }
}
