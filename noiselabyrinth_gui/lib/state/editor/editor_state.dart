import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';

class EditorValidationIssue {
  const EditorValidationIssue({required this.message, required this.path, this.node});

  final String message;
  final String path;
  final EditorNode? node;
}

class EditorState {
  const EditorState({this.config, this.selectedNode, this.isDirty = false, this.validationIssues = const []});

  final GenerationConfig? config;
  final EditorNode? selectedNode;
  final bool isDirty;
  final List<EditorValidationIssue> validationIssues;

  bool get isOpen => config != null;

  EditorState copyWith({
    GenerationConfig? config,
    EditorNode? selectedNode,
    bool clearSelection = false,
    bool? isDirty,
    List<EditorValidationIssue>? validationIssues,
  }) {
    return EditorState(
      config: config ?? this.config,
      selectedNode: clearSelection ? null : (selectedNode ?? this.selectedNode),
      isDirty: isDirty ?? this.isDirty,
      validationIssues: validationIssues ?? this.validationIssues,
    );
  }
}
