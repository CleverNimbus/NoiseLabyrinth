import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';

class LayerPreviewConfigurationDialog extends ConsumerWidget {
  const LayerPreviewConfigurationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorNotifierProvider);
    final config = editorState.config;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 720,
        height: 760,
        child: config == null
            ? const Center(child: Text('Open a config to configure layer preview.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Layer preview configuration',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Selected branches are included in preview playback.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      children: [
                        _LayerPreviewSectionHeader(layerCount: config.layers.length),
                        for (final layer in config.layers) _LayerPreviewSubtree(layer: layer, editorState: editorState),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LayerPreviewSectionHeader extends StatelessWidget {
  const _LayerPreviewSectionHeader({required this.layerCount});

  final int layerCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Layers ($layerCount)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LayerPreviewSubtree extends ConsumerStatefulWidget {
  const _LayerPreviewSubtree({required this.layer, required this.editorState});

  final LayerConfig layer;
  final EditorState editorState;

  @override
  ConsumerState<_LayerPreviewSubtree> createState() => _LayerPreviewSubtreeState();
}

class _LayerPreviewSubtreeState extends ConsumerState<_LayerPreviewSubtree> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final selection = widget.editorState.selectionForLayer(layer.id);
    final notifier = ref.read(editorNotifierProvider.notifier);
    final layerEnabled = selection.layerEnabled;
    final sourceEnabled = selection.sourceEnabled;
    final branchEnabled = layerEnabled && sourceEnabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewTreeRow(
              label: layer.id,
              icon: Icons.layers_outlined,
              depth: 0,
              checkboxValue: layerEnabled,
              onCheckboxChanged: (_) => notifier.toggleLayerPreviewEnabled(layer.id),
              isExpandable: true,
              isExpanded: _expanded,
              onToggleExpand: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) ...[
              _PreviewTreeRow(
                label: 'Source (${layer.source.type.name})',
                icon: Icons.waves_outlined,
                depth: 1,
                checkboxValue: sourceEnabled,
                onCheckboxChanged: layerEnabled ? (_) => notifier.toggleSourcePreviewEnabled(layer.id) : null,
                enabled: layerEnabled,
              ),
              _PreviewCollectionHeader(label: 'Processors', count: layer.processors.length, depth: 1),
              for (final processor in layer.processors)
                _PreviewTreeRow(
                  label: '${processor.id} (${processor.type.name})',
                  icon: _processorIcon(processor.type),
                  depth: 2,
                  checkboxValue: selection.isProcessorEnabled(processor.id),
                  onCheckboxChanged: branchEnabled
                      ? (_) => notifier.toggleProcessorPreviewEnabled(layer.id, processor.id)
                      : null,
                  enabled: branchEnabled,
                ),
              _PreviewCollectionHeader(label: 'Modulations', count: layer.modulations.length, depth: 1),
              for (final modulation in layer.modulations)
                _PreviewTreeRow(
                  label: '${modulation.id} (${modulation.type.name})',
                  icon: _modulationIcon(modulation.type),
                  depth: 2,
                  checkboxValue: selection.isModulationEnabled(modulation.id),
                  onCheckboxChanged: branchEnabled
                      ? (_) => notifier.toggleModulationPreviewEnabled(layer.id, modulation.id)
                      : null,
                  enabled: branchEnabled,
                ),
              _PreviewCollectionHeader(label: 'Events', count: layer.events.length, depth: 1),
              for (final event in layer.events)
                _PreviewTreeRow(
                  label: '${event.id} (${event.trigger.type.name})',
                  icon: Icons.flash_on_outlined,
                  depth: 2,
                  checkboxValue: selection.isEventEnabled(event.id),
                  onCheckboxChanged: branchEnabled
                      ? (_) => notifier.toggleEventPreviewEnabled(layer.id, event.id)
                      : null,
                  enabled: branchEnabled,
                ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _processorIcon(ProcessorType type) {
    switch (type) {
      case ProcessorType.biquad:
        return Icons.filter_alt_outlined;
      case ProcessorType.gain:
        return Icons.volume_up_outlined;
      case ProcessorType.saturator:
        return Icons.whatshot_outlined;
      case ProcessorType.delay:
        return Icons.history_outlined;
    }
  }

  IconData _modulationIcon(ModulationType type) {
    switch (type) {
      case ModulationType.lfo:
        return Icons.sync_alt_outlined;
      case ModulationType.random:
        return Icons.shuffle_outlined;
      case ModulationType.drift:
        return Icons.trending_up_outlined;
      case ModulationType.envelope:
        return Icons.show_chart_outlined;
      case ModulationType.burst:
        return Icons.bolt_outlined;
    }
  }
}

class _PreviewCollectionHeader extends StatelessWidget {
  const _PreviewCollectionHeader({required this.label, required this.count, required this.depth});

  final String label;
  final int count;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final indent = 14.0 + (depth * 18.0);
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8, right: 10, bottom: 4),
      child: Text(
        '$label ($count)',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PreviewTreeRow extends StatelessWidget {
  const _PreviewTreeRow({
    required this.label,
    required this.icon,
    required this.depth,
    required this.checkboxValue,
    required this.onCheckboxChanged,
    this.enabled = true,
    this.isExpandable = false,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  final String label;
  final IconData icon;
  final int depth;
  final bool checkboxValue;
  final ValueChanged<bool?>? onCheckboxChanged;
  final bool enabled;
  final bool isExpandable;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final indent = 8.0 + (depth * 18.0);
    final contentColor = enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Row(
          children: [
            SizedBox(width: indent),
            if (isExpandable)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onToggleExpand,
                icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 18),
              )
            else
              const SizedBox(width: 24),
            Checkbox(
              value: checkboxValue,
              onChanged: onCheckboxChanged,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Icon(icon, size: 15, color: contentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: contentColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
