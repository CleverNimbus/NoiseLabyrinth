import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';

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
    this.previewDisabledProcessorsByLayer = const {},
    this.previewDisabledModulationsByLayer = const {},
    this.previewDisabledEventsByLayer = const {},
    this.configRevision = 0,
  });

  final GenerationConfig? config;
  final int? storedConfigId;
  final EditorNode? selectedNode;
  final bool isDirty;
  final List<EditorValidationIssue> validationIssues;
  final Map<String, Set<String>> previewDisabledProcessorsByLayer;
  final Map<String, Set<String>> previewDisabledModulationsByLayer;
  final Map<String, Set<String>> previewDisabledEventsByLayer;
  final int configRevision;

  bool get isOpen => config != null;

  bool isProcessorPreviewEnabled(String layerId, String processorId) {
    return !(previewDisabledProcessorsByLayer[layerId]?.contains(processorId) ?? false);
  }

  bool isModulationPreviewEnabled(String layerId, String modulationId) {
    return !(previewDisabledModulationsByLayer[layerId]?.contains(modulationId) ?? false);
  }

  bool isEventPreviewEnabled(String layerId, String eventId) {
    return !(previewDisabledEventsByLayer[layerId]?.contains(eventId) ?? false);
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
    int? configRevision,
  }) {
    return EditorState(
      config: config ?? this.config,
      storedConfigId: clearStoredConfigId ? null : (storedConfigId ?? this.storedConfigId),
      selectedNode: clearSelection ? null : (selectedNode ?? this.selectedNode),
      isDirty: isDirty ?? this.isDirty,
      validationIssues: validationIssues ?? this.validationIssues,
      previewDisabledProcessorsByLayer: previewDisabledProcessorsByLayer ?? this.previewDisabledProcessorsByLayer,
      previewDisabledModulationsByLayer: previewDisabledModulationsByLayer ?? this.previewDisabledModulationsByLayer,
      previewDisabledEventsByLayer: previewDisabledEventsByLayer ?? this.previewDisabledEventsByLayer,
      configRevision: configRevision ?? this.configRevision,
    );
  }
}
