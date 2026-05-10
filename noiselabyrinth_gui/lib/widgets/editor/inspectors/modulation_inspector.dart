import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/modulation_target_path_options.dart';

class ModulationInspector extends ConsumerWidget {
  const ModulationInspector({super.key, required this.layer, required this.modulation});

  final LayerConfig layer;
  final ModulationConfig modulation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(ModulationConfig m) => ref.read(editorNotifierProvider.notifier).updateModulation(layer.id, m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'MODULATION',
          children: [
            LabeledTextField(label: 'ID', value: modulation.id, onChanged: (v) => update(modulation..id = v)),
            LabeledDropdown<ModulationType>(
              label: 'Type',
              value: modulation.type,
              items: ModulationType.values,
              itemLabel: (t) => t.name,
              onChanged: (t) => update(_switchType(modulation, t)),
            ),
            LabeledSlider(
              label: 'Amount',
              value: modulation.amount.clamp(-1.0, 1.0),
              min: -1,
              max: 1,
              displayValue: modulation.amount.toStringAsFixed(2),
              onChanged: (v) => update(modulation..amount = v),
            ),
          ],
        ),
        if (modulation.type == ModulationType.lfo) _LfoSection(modulation, update),
        if (modulation.type == ModulationType.random) _RandomSection(modulation, update),
        if (modulation.type == ModulationType.drift) _DriftSection(modulation, update),
        if (modulation.type == ModulationType.envelope) _EnvelopeSection(modulation, update),
        if (modulation.type == ModulationType.burst) _BurstSection(modulation, update),
        _TargetsSection(modulation: modulation, onUpdate: update, layer: layer),
      ],
    );
  }

  ModulationConfig _switchType(ModulationConfig m, ModulationType t) {
    m.type = t;
    m.lfoConfig = t == ModulationType.lfo ? (m.lfoConfig ?? LfoConfig()) : null;
    m.randomConfig = t == ModulationType.random ? (m.randomConfig ?? RandomConfig()) : null;
    m.driftConfig = t == ModulationType.drift ? (m.driftConfig ?? DriftConfig()) : null;
    m.envelopeConfig = t == ModulationType.envelope ? (m.envelopeConfig ?? EnvelopeConfig()) : null;
    m.burstConfig = t == ModulationType.burst ? (m.burstConfig ?? BurstConfig()) : null;
    return m;
  }
}

// ── LFO ─────────────────────────────────

class _LfoSection extends StatelessWidget {
  const _LfoSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  LfoConfig get lfo => mod.lfoConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'LFO',
      children: [
        LabeledDropdown<LFOType>(
          label: 'Waveform',
          value: lfo.type,
          items: LFOType.values,
          itemLabel: (t) => t.name,
          onChanged: (t) {
            lfo.type = t;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Frequency (Hz)',
          value: lfo.frequency.clamp(0.001, 20.0),
          min: 0.001,
          max: 20,
          displayValue: '${lfo.frequency.toStringAsFixed(3)} Hz',
          onChanged: (v) {
            lfo.frequency = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Depth',
          value: lfo.depth.clamp(0.0, 2.0),
          min: 0,
          max: 2,
          displayValue: lfo.depth.toStringAsFixed(2),
          onChanged: (v) {
            lfo.depth = v;
            update(mod);
          },
        ),
      ],
    );
  }
}

// ── Random ───────────────────────────────

class _RandomSection extends StatelessWidget {
  const _RandomSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  RandomConfig get r => mod.randomConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'RANDOM',
      children: [
        LabeledSlider(
          label: 'Rate (Hz)',
          value: r.rateHz.clamp(0.001, 10.0),
          min: 0.001,
          max: 10,
          displayValue: '${r.rateHz.toStringAsFixed(3)} Hz',
          onChanged: (v) {
            r.rateHz = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Smooth',
          value: r.smooth,
          min: 0,
          max: 1,
          displayValue: r.smooth.toStringAsFixed(2),
          onChanged: (v) {
            r.smooth = v;
            update(mod);
          },
        ),
      ],
    );
  }
}

// ── Drift ────────────────────────────────

class _DriftSection extends StatelessWidget {
  const _DriftSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  DriftConfig get d => mod.driftConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'DRIFT',
      children: [
        LabeledSlider(
          label: 'Speed',
          value: d.speed.clamp(0.0, 1.0),
          min: 0,
          max: 1,
          displayValue: d.speed.toStringAsFixed(3),
          onChanged: (v) {
            d.speed = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Range',
          value: d.range.clamp(0.0, 2.0),
          min: 0,
          max: 2,
          displayValue: d.range.toStringAsFixed(2),
          onChanged: (v) {
            d.range = v;
            update(mod);
          },
        ),
      ],
    );
  }
}

// ── Envelope ─────────────────────────────

class _EnvelopeSection extends StatelessWidget {
  const _EnvelopeSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  EnvelopeConfig get e => mod.envelopeConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'ENVELOPE',
      children: [
        LabeledSlider(
          label: 'Attack (ms)',
          value: e.attackMs.toDouble().clamp(0.0, 2000.0),
          min: 0,
          max: 2000,
          displayValue: '${e.attackMs.round()} ms',
          onChanged: (v) {
            e.attackMs = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Decay (ms)',
          value: e.decayMs.toDouble().clamp(0.0, 2000.0),
          min: 0,
          max: 2000,
          displayValue: '${e.decayMs.round()} ms',
          onChanged: (v) {
            e.decayMs = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Sustain',
          value: e.sustain,
          min: 0,
          max: 1,
          displayValue: e.sustain.toStringAsFixed(2),
          onChanged: (v) {
            e.sustain = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Release (ms)',
          value: e.releaseMs.toDouble().clamp(0.0, 2000.0),
          min: 0,
          max: 2000,
          displayValue: '${e.releaseMs.round()} ms',
          onChanged: (v) {
            e.releaseMs = v.round();
            update(mod);
          },
        ),
      ],
    );
  }
}

// ── Burst ────────────────────────────────

class _BurstSection extends StatelessWidget {
  const _BurstSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  BurstConfig get b => mod.burstConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'BURST',
      children: [
        LabeledSlider(
          label: 'Duration (ms)',
          value: b.durationMs.toDouble().clamp(1.0, 2000.0),
          min: 1,
          max: 2000,
          displayValue: '${b.durationMs.round()} ms',
          onChanged: (v) {
            b.durationMs = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Intensity',
          value: b.intensity,
          min: 0,
          max: 1,
          displayValue: b.intensity.toStringAsFixed(2),
          onChanged: (v) {
            b.intensity = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Randomness',
          value: b.randomness,
          min: 0,
          max: 1,
          displayValue: b.randomness.toStringAsFixed(2),
          onChanged: (v) {
            b.randomness = v;
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Attack (ms)',
          value: b.attackMs.toDouble().clamp(0.0, 500.0),
          min: 0,
          max: 500,
          displayValue: '${b.attackMs.round()} ms',
          onChanged: (v) {
            b.attackMs = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Release (ms)',
          value: b.releaseMs.toDouble().clamp(1.0, 500.0),
          min: 1,
          max: 500,
          displayValue: '${b.releaseMs.round()} ms',
          onChanged: (v) {
            b.releaseMs = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Cluster Min',
          value: b.clusterMin.toDouble().clamp(1.0, 50.0),
          min: 1,
          max: 50,
          displayValue: '${b.clusterMin.round()}',
          onChanged: (v) {
            b.clusterMin = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Cluster Max',
          value: b.clusterMax.toDouble().clamp(1.0, 50.0),
          min: 1,
          max: 50,
          displayValue: '${b.clusterMax.round()}',
          onChanged: (v) {
            b.clusterMax = v.round();
            update(mod);
          },
        ),
        LabeledSlider(
          label: 'Spread (ms)',
          value: b.clusterSpreadMs.toDouble().clamp(0.0, 1000.0),
          min: 0,
          max: 1000,
          displayValue: '${b.clusterSpreadMs.round()} ms',
          onChanged: (v) {
            b.clusterSpreadMs = v.round();
            update(mod);
          },
        ),
      ],
    );
  }
}

// ── Targets ──────────────────────────────

class _TargetsSection extends StatelessWidget {
  const _TargetsSection({
    required this.modulation,
    required this.onUpdate,
    required this.layer,
  });
  final ModulationConfig modulation;
  final ValueChanged<ModulationConfig> onUpdate;
  final LayerConfig layer;

  void _updateTargets(List<ModulationTargetConfig> targets) {
    modulation.targets = targets;
    onUpdate(modulation);
  }

  @override
  Widget build(BuildContext context) {
    final targetOptions = buildModulationTargetPathOptions(layer);

    return InspectorSection(
      title: 'TARGETS (${modulation.targets.length})',
      children: [
        if (modulation.targets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No targets. Add one below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (var i = 0; i < modulation.targets.length; i++)
          _TargetCard(
            target: modulation.targets[i],
            index: i,
            targetOptions: targetOptions,
            onChanged: (t) {
              final list = [...modulation.targets];
              list[i] = t;
              _updateTargets(list);
            },
            onRemove: () {
              final list = [...modulation.targets]..removeAt(i);
              _updateTargets(list);
            },
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Target'),
          onPressed: () {
            final newTarget = ModulationTargetConfig(path: targetOptions.isNotEmpty ? targetOptions.first.path : '');
            _updateTargets([...modulation.targets, newTarget]);
          },
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    required this.index,
    required this.targetOptions,
    required this.onChanged,
    required this.onRemove,
  });

  final ModulationTargetConfig target;
  final int index;
  final List<ModulationTargetPathOption> targetOptions;
  final ValueChanged<ModulationTargetConfig> onChanged;
  final VoidCallback onRemove;

  ModulationTargetPathOption _resolveSelectedOption() {
    for (final option in targetOptions) {
      if (option.path == target.path) {
        return option;
      }
    }

    return ModulationTargetPathOption(
      path: target.path,
      label: target.path.isEmpty ? 'Select target' : 'Custom: ${target.path}',
    );
  }

  List<ModulationTargetPathOption> _buildDropdownOptions(ModulationTargetPathOption selected) {
    final options = [...targetOptions];
    final hasSelected = options.any((option) => option.path == selected.path);
    if (!hasSelected) {
      return [selected, ...options];
    }
    if (selected.path.isEmpty) {
      return [selected, ...options];
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = _resolveSelectedOption();
    final dropdownOptions = _buildDropdownOptions(selectedOption);

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
                'Target ${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 14),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: 'Remove target',
              ),
            ],
          ),
          LabeledDropdown<ModulationTargetPathOption>(
            label: 'Path',
            value: selectedOption,
            items: dropdownOptions,
            itemLabel: (option) => option.label,
            onChanged: (option) {
              target.path = option.path;
              onChanged(target);
            },
          ),
          LabeledSlider(
            label: 'Amount',
            value: target.amount.clamp(-2.0, 2.0),
            min: -2,
            max: 2,
            displayValue: target.amount.toStringAsFixed(2),
            onChanged: (v) {
              target.amount = v;
              onChanged(target);
            },
          ),
          LabeledDropdown<ModulationApplyMode>(
            label: 'Mode',
            value: target.mode,
            items: ModulationApplyMode.values,
            itemLabel: (m) => m.name,
            onChanged: (m) {
              target.mode = m;
              onChanged(target);
            },
          ),
        ],
      ),
    );
  }
}
