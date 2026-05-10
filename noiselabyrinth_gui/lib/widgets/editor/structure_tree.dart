import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';
import 'package:noiselabyrinth_gui/widgets/editor/structure_tree_item.dart';

class StructureTree extends ConsumerWidget {
  const StructureTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorNotifierProvider);
    final config = editorState.config;
    if (config == null) return const SizedBox.shrink();

    final selectedNode = editorState.selectedNode;
    final issues = editorState.validationIssues;

    bool hasIssue(EditorNode node) {
      return issues.any((i) => i.node.runtimeType == node.runtimeType && _sameNode(i.node, node));
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(label: 'Generation Config', icon: Icons.layers_outlined),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                // ── Metadata ──
                StructureTreeItem(
                  label: 'Metadata',
                  icon: Icons.badge_outlined,
                  depth: 0,
                  isSelected: selectedNode is MetadataNode,
                  hasError: hasIssue(const MetadataNode()),
                  onTap: () => ref.read(editorNotifierProvider.notifier).selectNode(const MetadataNode()),
                ),

                // ── Render ──
                StructureTreeItem(
                  label: 'Render',
                  icon: Icons.graphic_eq_outlined,
                  depth: 0,
                  isSelected: selectedNode is RenderNode,
                  hasError: hasIssue(const RenderNode()),
                  onTap: () => ref.read(editorNotifierProvider.notifier).selectNode(const RenderNode()),
                ),

                // ── Mix ──
                StructureTreeItem(
                  label: 'Mix',
                  icon: Icons.equalizer_outlined,
                  depth: 0,
                  isSelected: selectedNode is MixNode,
                  hasError: hasIssue(const MixNode()),
                  onTap: () => ref.read(editorNotifierProvider.notifier).selectNode(const MixNode()),
                ),

                // ── Layers ──
                _LayersSectionHeader(config: config),

                for (final layer in config.layers)
                  _LayerSubtree(layer: layer, selectedNode: selectedNode, issues: issues),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameNode(EditorNode? a, EditorNode b) {
    if (a == null) return false;
    if (a is MetadataNode && b is MetadataNode) return true;
    if (a is RenderNode && b is RenderNode) return true;
    if (a is MixNode && b is MixNode) return true;
    if (a is LayerNode && b is LayerNode) return a.layer.id == b.layer.id;
    if (a is SourceNode && b is SourceNode) return a.layer.id == b.layer.id;
    if (a is ProcessorNode && b is ProcessorNode) {
      return a.layer.id == b.layer.id && a.processor.id == b.processor.id;
    }
    if (a is ModulationNode && b is ModulationNode) {
      return a.layer.id == b.layer.id && a.modulation.id == b.modulation.id;
    }
    if (a is EventNode && b is EventNode) {
      return a.layer.id == b.layer.id && a.event.id == b.event.id;
    }
    return false;
  }
}

// ──────────────────────────────────────────
// Layers section header with Add button
// ──────────────────────────────────────────

class _LayersSectionHeader extends ConsumerWidget {
  const _LayersSectionHeader({required this.config});
  final GenerationConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 2),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Icon(Icons.stacked_bar_chart_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Layers (${config.layers.length})',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add Layer',
            icon: const Icon(Icons.add, size: 16),
            onPressed: () => ref.read(editorNotifierProvider.notifier).addLayer(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Per-layer expandable subtree
// ──────────────────────────────────────────

class _LayerSubtree extends ConsumerStatefulWidget {
  const _LayerSubtree({required this.layer, required this.selectedNode, required this.issues});

  final LayerConfig layer;
  final EditorNode? selectedNode;
  final List<EditorValidationIssue> issues;

  @override
  ConsumerState<_LayerSubtree> createState() => _LayerSubtreeState();
}

class _LayerSubtreeState extends ConsumerState<_LayerSubtree> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    final sel = widget.selectedNode;
    final notifier = ref.read(editorNotifierProvider.notifier);

    bool layerHasIssue() => widget.issues.any((i) {
      final n = i.node;
      return (n is LayerNode && n.layer.id == layer.id) ||
          (n is SourceNode && n.layer.id == layer.id) ||
          (n is ProcessorNode && n.layer.id == layer.id) ||
          (n is ModulationNode && n.layer.id == layer.id) ||
          (n is EventNode && n.layer.id == layer.id);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Layer row
        StructureTreeItem(
          label: layer.id,
          icon: Icons.layers_outlined,
          depth: 1,
          isSelected: sel is LayerNode && sel.layer.id == layer.id,
          isExpandable: true,
          isExpanded: _expanded,
          hasError: layerHasIssue(),
          onTap: () => notifier.selectNode(LayerNode(layer)),
          onToggleExpand: () => setState(() => _expanded = !_expanded),
          trailingActions: [
            TreeItemAction(
              icon: Icons.delete_outline,
              tooltip: 'Remove Layer',
              onPressed: () => notifier.removeLayer(layer.id),
            ),
          ],
        ),

        if (_expanded) ...[
          // Source
          StructureTreeItem(
            label: 'Source (${layer.source.type.name})',
            icon: Icons.waves_outlined,
            depth: 2,
            isSelected: sel is SourceNode && sel.layer.id == layer.id,
            hasError: widget.issues.any((i) => i.node is SourceNode && (i.node as SourceNode).layer.id == layer.id),
            onTap: () => notifier.selectNode(SourceNode(layer)),
          ),

          // Processors
          _CollectionSection(
            label: 'Processors',
            count: layer.processors.length,
            icon: Icons.auto_fix_high_outlined,
            depth: 2,
            onAdd: () => notifier.addProcessor(layer.id),
            children: [
              for (final proc in layer.processors)
                StructureTreeItem(
                  label: '${proc.id} (${proc.type.name})',
                  icon: _processorIcon(proc.type),
                  depth: 3,
                  isSelected: sel is ProcessorNode && sel.layer.id == layer.id && sel.processor.id == proc.id,
                  hasError: widget.issues.any(
                    (i) =>
                        i.node is ProcessorNode &&
                        (i.node as ProcessorNode).layer.id == layer.id &&
                        (i.node as ProcessorNode).processor.id == proc.id,
                  ),
                  onTap: () => notifier.selectNode(ProcessorNode(layer, proc)),
                  trailingActions: [
                    TreeItemAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove Processor',
                      onPressed: () => notifier.removeProcessor(layer.id, proc.id),
                    ),
                  ],
                ),
            ],
          ),

          // Modulations
          _CollectionSection(
            label: 'Modulations',
            count: layer.modulations.length,
            icon: Icons.timeline_outlined,
            depth: 2,
            onAdd: () => notifier.addModulation(layer.id),
            children: [
              for (final mod in layer.modulations)
                StructureTreeItem(
                  label: '${mod.id} (${mod.type.name})',
                  icon: _modulationIcon(mod.type),
                  depth: 3,
                  isSelected: sel is ModulationNode && sel.layer.id == layer.id && sel.modulation.id == mod.id,
                  hasError: widget.issues.any(
                    (i) =>
                        i.node is ModulationNode &&
                        (i.node as ModulationNode).layer.id == layer.id &&
                        (i.node as ModulationNode).modulation.id == mod.id,
                  ),
                  onTap: () => notifier.selectNode(ModulationNode(layer, mod)),
                  trailingActions: [
                    TreeItemAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove Modulation',
                      onPressed: () => notifier.removeModulation(layer.id, mod.id),
                    ),
                  ],
                ),
            ],
          ),

          // Events
          _CollectionSection(
            label: 'Events',
            count: layer.events.length,
            icon: Icons.flash_on_outlined,
            depth: 2,
            onAdd: () => notifier.addEvent(layer.id),
            children: [
              for (final event in layer.events)
                StructureTreeItem(
                  label: '${event.id} (${event.trigger.type.name})',
                  icon: Icons.flash_on_outlined,
                  depth: 3,
                  isSelected: sel is EventNode && sel.layer.id == layer.id && sel.event.id == event.id,
                  hasError: widget.issues.any(
                    (i) =>
                        i.node is EventNode &&
                        (i.node as EventNode).layer.id == layer.id &&
                        (i.node as EventNode).event.id == event.id,
                  ),
                  onTap: () => notifier.selectNode(EventNode(layer, event)),
                  trailingActions: [
                    TreeItemAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove Event',
                      onPressed: () => notifier.removeEvent(layer.id, event.id),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
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

// ──────────────────────────────────────────
// Collapsible collection sub-section
// ──────────────────────────────────────────

class _CollectionSection extends StatefulWidget {
  const _CollectionSection({
    required this.label,
    required this.count,
    required this.icon,
    required this.depth,
    required this.onAdd,
    required this.children,
  });

  final String label;
  final int count;
  final IconData icon;
  final int depth;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  State<_CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends State<_CollectionSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StructureTreeItem(
          label: '${widget.label} (${widget.count})',
          icon: widget.icon,
          depth: widget.depth,
          isExpandable: true,
          isExpanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
          onToggleExpand: () => setState(() => _expanded = !_expanded),
          trailingActions: [
            TreeItemAction(
              icon: Icons.add,
              tooltip: 'Add ${widget.label.replaceAll('s', '')}',
              onPressed: widget.onAdd,
            ),
          ],
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

// ──────────────────────────────────────────
// Section header (non-interactive)
// ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
