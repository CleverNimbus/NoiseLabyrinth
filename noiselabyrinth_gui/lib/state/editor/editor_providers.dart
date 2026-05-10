import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_notifier.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';

/// Injected from main.dart via ProviderScope overrides.
final repositoryProvider = Provider<GenerationConfigRepository>(
  (_) => throw UnimplementedError('repositoryProvider must be overridden'),
);

/// Main editor state provider.
final editorNotifierProvider = StateNotifierProvider<EditorNotifier, EditorState>((_) => EditorNotifier());

/// Derived: currently selected node.
final selectedNodeProvider = Provider<EditorNode?>((ref) => ref.watch(editorNotifierProvider).selectedNode);

/// Derived: whether the editor has a config open.
final isEditorOpenProvider = Provider<bool>((ref) => ref.watch(editorNotifierProvider).isOpen);

/// Derived: current validation issues.
final validationIssuesProvider = Provider<List<EditorValidationIssue>>(
  (ref) => ref.watch(editorNotifierProvider).validationIssues,
);

/// Derived: whether the working copy is dirty.
final isDirtyProvider = Provider<bool>((ref) => ref.watch(editorNotifierProvider).isDirty);
