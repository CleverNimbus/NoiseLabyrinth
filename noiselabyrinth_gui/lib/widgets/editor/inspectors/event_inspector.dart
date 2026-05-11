import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class EventInspector extends ConsumerWidget {
  const EventInspector({super.key, required this.layer, required this.event});

  final LayerConfig layer;
  final EventConfig event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(EventConfig e) => ref.read(editorNotifierProvider.notifier).updateEvent(layer.id, e);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'EVENT',
          children: [LabeledTextField(label: 'ID', value: event.id, onChanged: (v) => update(event..id = v))],
        ),
        InspectorSection(
          title: 'TRIGGER',
          children: [
            LabeledDropdown<TriggerType>(
              label: 'Type',
              value: event.trigger.type,
              items: TriggerType.values,
              itemLabel: (t) => t.name,
              onChanged: (t) {
                event.trigger.type = t;
                update(event);
              },
            ),
            LabeledSlider(
              label: 'Rate (Hz)',
              value: event.trigger.rate.clamp(0.001, 10.0),
              min: 0.001,
              max: 10,
              displayValue: '${event.trigger.rate.toStringAsFixed(3)} Hz',
              onChanged: (v) {
                event.trigger.rate = v;
                update(event);
              },
            ),
          ],
        ),
        _ActionsSection(event: event, layer: layer, onUpdate: update),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.event, required this.layer, required this.onUpdate});

  final EventConfig event;
  final LayerConfig layer;
  final ValueChanged<EventConfig> onUpdate;

  void _updateActions(List<ActionConfig> actions) {
    event.actions = actions;
    onUpdate(event);
  }

  @override
  Widget build(BuildContext context) {
    final availableModIds = layer.modulations.map((m) => m.id).toList();
    final hasAvailableModulators = availableModIds.isNotEmpty;

    return InspectorSection(
      title: 'ACTIONS (${event.actions.length})',
      children: [
        if (event.actions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No actions. Add one below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (!hasAvailableModulators)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Add a modulation to this layer before creating event actions.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (var i = 0; i < event.actions.length; i++)
          _ActionCard(
            action: event.actions[i],
            index: i,
            availableModIds: availableModIds,
            onChanged: (a) {
              final list = [...event.actions];
              list[i] = a;
              _updateActions(list);
            },
            onRemove: () {
              final list = [...event.actions]..removeAt(i);
              _updateActions(list);
            },
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Action'),
          onPressed: hasAvailableModulators
              ? () {
                  _updateActions([...event.actions, ActionConfig(modulatorId: availableModIds.first)]);
                }
              : null,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.index,
    required this.availableModIds,
    required this.onChanged,
    required this.onRemove,
  });

  final ActionConfig action;
  final int index;
  final List<String> availableModIds;
  final ValueChanged<ActionConfig> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Action ${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 14),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: 'Remove action',
              ),
            ],
          ),
          if (availableModIds.isNotEmpty)
            LabeledDropdown<String>(
              label: 'Modulator',
              value: availableModIds.contains(action.modulatorId) ? action.modulatorId : availableModIds.first,
              items: availableModIds,
              onChanged: (v) {
                action.modulatorId = v;
                onChanged(action);
              },
            )
          else
            LabeledTextField(
              label: 'Modulator ID',
              value: action.modulatorId,
              hint: 'Modulation ID in this layer',
              onChanged: (v) {
                action.modulatorId = v;
                onChanged(action);
              },
            ),
          LabeledDropdown<ActionMode>(
            label: 'Mode',
            value: action.mode,
            items: ActionMode.values,
            itemLabel: (m) => m.name,
            onChanged: (m) {
              action.mode = m;
              onChanged(action);
            },
          ),
        ],
      ),
    );
  }
}
