import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/editor_toolbar.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_panel.dart';
import 'package:noiselabyrinth_gui/widgets/editor/structure_tree.dart';
import 'package:noiselabyrinth_gui/widgets/editor/validation_panel.dart';

final _leftPanelWidthProvider = StateProvider<double>((_) => 260);

class CreatePanel extends ConsumerWidget {
  const CreatePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(isEditorOpenProvider);
    if (!isOpen) {
      return _EditorEmptyState();
    }
    return _EditorLayout();
  }
}

// ──────────────────────────────────────────
// Empty state (no config open)
// ──────────────────────────────────────────

class _EditorEmptyState extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_outlined, size: 56, color: colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              'No preset open',
              style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new config, open one from the library, or import from JSON.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Config'),
                  onPressed: () => ref.read(editorNotifierProvider.notifier).newConfig(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Import JSON'),
                  onPressed: () => EditorToolbar.importJson(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Full editor layout
// ──────────────────────────────────────────

class _EditorLayout extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EditorLayout> createState() => _EditorLayoutState();
}

class _EditorLayoutState extends ConsumerState<_EditorLayout> {
  static const _minLeftWidth = 180.0;
  static const _maxLeftWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final leftWidth = ref.watch(_leftPanelWidthProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EditorToolbar(),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: structure tree
                SizedBox(width: leftWidth, child: const StructureTree()),
                // Draggable divider
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      final w = (leftWidth + details.delta.dx).clamp(_minLeftWidth, _maxLeftWidth);
                      ref.read(_leftPanelWidthProvider.notifier).state = w;
                    },
                    child: Container(
                      width: 5,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      child: Center(child: Container(width: 1, color: colorScheme.outlineVariant)),
                    ),
                  ),
                ),
                // Right: inspector
                const Expanded(child: InspectorPanel()),
              ],
            ),
          ),
          const Divider(height: 1),
          const ValidationPanel(),
        ],
      ),
    );
  }
}
