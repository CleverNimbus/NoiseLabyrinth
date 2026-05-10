import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/config_editor_factory.dart';

class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorNotifierProvider);
    final selectedNode = editorState.selectedNode;
    final config = editorState.config;

    if (config == null || selectedNode == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Text(
                'Select an item from the tree',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector header
          _InspectorHeader(node: selectedNode),
          const Divider(height: 1),
          // Inspector body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConfigEditorFactory.buildInspector(context, ref, selectedNode, config),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({required this.node});
  final EditorNode node;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = _labelAndIcon(node);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  (String, IconData) _labelAndIcon(EditorNode node) {
    return switch (node) {
      MetadataNode() => ('Metadata', Icons.badge_outlined),
      RenderNode() => ('Render', Icons.graphic_eq_outlined),
      MixNode() => ('Mix', Icons.equalizer_outlined),
      LayerNode(:final layer) => ('Layer: ${layer.id}', Icons.layers_outlined),
      SourceNode(:final layer) => ('Source: ${layer.source.type.name}', Icons.waves_outlined),
      ProcessorNode(:final processor) => ('Processor: ${processor.id}', Icons.auto_fix_high_outlined),
      ModulationNode(:final modulation) => ('Modulation: ${modulation.id}', Icons.timeline_outlined),
      EventNode(:final event) => ('Event: ${event.id}', Icons.flash_on_outlined),
    };
  }
}
