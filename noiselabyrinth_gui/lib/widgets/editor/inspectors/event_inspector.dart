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
          children: [
            LabeledTextField(
              label: 'ID',
              value: event.id,
              onChanged: (v) => update(EventConfig(id: v, trigger: event.trigger, actions: event.actions)),
            ),
          ],
        ),
        InspectorSection(
          title: 'TRIGGER',
          children: [
            LabeledDropdown<TriggerType>(
              label: 'Type',
              value: event.trigger.type,
              items: TriggerType.values,
              itemLabel: (t) => t.name,
              onChanged: (t) => update(
                EventConfig(
                  id: event.id,
                  trigger: TriggerConfig(type: t, rate: event.trigger.rate),
                  actions: event.actions,
                ),
              ),
            ),
            LabeledSlider(
              label: 'Rate (Hz)',
              value: event.trigger.rate.clamp(0.001, 10.0),
              min: 0.001,
              max: 10,
              displayValue: '${event.trigger.rate.toStringAsFixed(3)} Hz',
              onChanged: (v) => update(
                EventConfig(
                  id: event.id,
                  trigger: TriggerConfig(type: event.trigger.type, rate: v),
                  actions: event.actions,
                ),
              ),
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
    onUpdate(EventConfig(id: event.id, trigger: event.trigger, actions: actions));
  }

  @override
  Widget build(BuildContext context) {
    final availableModIds = layer.modulations.map((m) => m.id).toList();

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
          onPressed: () {
            final defaultId = availableModIds.isNotEmpty ? availableModIds.first : '';
            _updateActions([...event.actions, ActionConfig(modulatorId: defaultId)]);
          },
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
              onChanged: (v) => onChanged(ActionConfig(modulatorId: v, mode: action.mode)),
            )
          else
            LabeledTextField(
              label: 'Modulator ID',
              value: action.modulatorId,
              hint: 'Modulation ID in this layer',
              onChanged: (v) => onChanged(ActionConfig(modulatorId: v, mode: action.mode)),
            ),
          LabeledDropdown<ActionMode>(
            label: 'Mode',
            value: action.mode,
            items: ActionMode.values,
            itemLabel: (m) => m.name,
            onChanged: (m) => onChanged(ActionConfig(modulatorId: action.modulatorId, mode: m)),
          ),
        ],
      ),
    );
  }
}
