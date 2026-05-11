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
    this.configRevision = 0,
  });

  final GenerationConfig? config;
  final int? storedConfigId;
  final EditorNode? selectedNode;
  final bool isDirty;
  final List<EditorValidationIssue> validationIssues;
  final int configRevision;

  bool get isOpen => config != null;

  EditorState copyWith({
    GenerationConfig? config,
    int? storedConfigId,
    bool clearStoredConfigId = false,
    EditorNode? selectedNode,
    bool clearSelection = false,
    bool? isDirty,
    List<EditorValidationIssue>? validationIssues,
    int? configRevision,
  }) {
    return EditorState(
      config: config ?? this.config,
      storedConfigId: clearStoredConfigId ? null : (storedConfigId ?? this.storedConfigId),
      selectedNode: clearSelection ? null : (selectedNode ?? this.selectedNode),
      isDirty: isDirty ?? this.isDirty,
      validationIssues: validationIssues ?? this.validationIssues,
      configRevision: configRevision ?? this.configRevision,
    );
  }
}
