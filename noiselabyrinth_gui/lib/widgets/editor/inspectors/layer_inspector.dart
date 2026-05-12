import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class LayerInspector extends ConsumerWidget {
  const LayerInspector({super.key, required this.layer});
  final LayerConfig layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorNotifierProvider);
    final notifier = ref.read(editorNotifierProvider.notifier);

    void commit(LayerConfig updated) => notifier.updateLayer(updated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'LAYER',
          children: [
            LabeledTextField(
              label: 'ID',
              value: layer.id,
              hint: 'Unique layer identifier',
              onChanged: (v) => commit(layer..id = v),
            ),
            LabeledSlider(
              label: 'Gain',
              value: layer.gain.clamp(0.0, 4.0),
              min: 0,
              max: 4,
              displayValue: layer.gain.toStringAsFixed(2),
              onChanged: (v) => commit(layer..gain = v),
            ),
            LabeledSlider(
              label: 'Pan',
              value: layer.pan,
              min: -1,
              max: 1,
              displayValue: layer.pan.toStringAsFixed(2),
              onChanged: (v) => commit(layer..pan = v),
            ),
          ],
        ),
        InspectorSection(
          title: 'PROCESSORS (${layer.processors.length})',
          children: [
            if (layer.processors.isEmpty)
              _EmptyHint('No processors. Add one from the tree.')
            else
              for (final proc in layer.processors)
                _NavCard(
                  label: proc.id,
                  subtitle: proc.type.name,
                  icon: Icons.auto_fix_high_outlined,
                  onTap: () => notifier.selectNode(ProcessorNode(layer, proc)),
                  isPreviewEnabled: editorState.isProcessorPreviewEnabled(layer.id, proc.id),
                  onTogglePreview: () => notifier.toggleProcessorPreviewEnabled(layer.id, proc.id),
                ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Processor'),
              onPressed: () => notifier.addProcessor(layer.id),
            ),
          ],
        ),
        InspectorSection(
          title: 'MODULATIONS (${layer.modulations.length})',
          children: [
            if (layer.modulations.isEmpty)
              _EmptyHint('No modulations. Add one from the tree.')
            else
              for (final mod in layer.modulations)
                _NavCard(
                  label: mod.id,
                  subtitle: mod.type.name,
                  icon: Icons.timeline_outlined,
                  onTap: () => notifier.selectNode(ModulationNode(layer, mod)),
                  isPreviewEnabled: editorState.isModulationPreviewEnabled(layer.id, mod.id),
                  onTogglePreview: () => notifier.toggleModulationPreviewEnabled(layer.id, mod.id),
                ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Modulation'),
              onPressed: () => notifier.addModulation(layer.id),
            ),
          ],
        ),
        InspectorSection(
          title: 'EVENTS (${layer.events.length})',
          children: [
            if (layer.events.isEmpty)
              _EmptyHint('No events. Add one from the tree.')
            else
              for (final event in layer.events)
                _NavCard(
                  label: event.id,
                  subtitle: event.trigger.type.name,
                  icon: Icons.flash_on_outlined,
                  onTap: () => notifier.selectNode(EventNode(layer, event)),
                  isPreviewEnabled: editorState.isEventPreviewEnabled(layer.id, event.id),
                  onTogglePreview: () => notifier.toggleEventPreviewEnabled(layer.id, event.id),
                ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Event'),
              onPressed: () => notifier.addEvent(layer.id),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isPreviewEnabled,
    required this.onTogglePreview,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPreviewEnabled;
  final VoidCallback onTogglePreview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: isPreviewEnabled ? 1.0 : 0.45,
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Spacer(),
              Tooltip(
                message: isPreviewEnabled ? 'Disable in Preview' : 'Enable in Preview',
                child: IconButton(
                  icon: Icon(isPreviewEnabled ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 14),
                  onPressed: onTogglePreview,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
