import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

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
            LabeledTextField(
              label: 'ID',
              value: modulation.id,
              onChanged: (v) => update(_copy(modulation, id: v)),
            ),
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
              onChanged: (v) => update(_copy(modulation, amount: v)),
            ),
          ],
        ),
        if (modulation.type == ModulationType.lfo) _LfoSection(modulation, update),
        if (modulation.type == ModulationType.random) _RandomSection(modulation, update),
        if (modulation.type == ModulationType.drift) _DriftSection(modulation, update),
        if (modulation.type == ModulationType.envelope) _EnvelopeSection(modulation, update),
        if (modulation.type == ModulationType.burst) _BurstSection(modulation, update),
        _TargetsSection(modulation: modulation, onUpdate: update),
      ],
    );
  }

  ModulationConfig _switchType(ModulationConfig m, ModulationType t) {
    return ModulationConfig(
      id: m.id,
      type: t,
      amount: m.amount,
      lfoConfig: t == ModulationType.lfo ? (m.lfoConfig ?? LfoConfig()) : null,
      randomConfig: t == ModulationType.random ? (m.randomConfig ?? RandomConfig()) : null,
      driftConfig: t == ModulationType.drift ? (m.driftConfig ?? DriftConfig()) : null,
      envelopeConfig: t == ModulationType.envelope ? (m.envelopeConfig ?? EnvelopeConfig()) : null,
      burstConfig: t == ModulationType.burst ? (m.burstConfig ?? BurstConfig()) : null,
      targets: m.targets,
    );
  }

  ModulationConfig _copy(ModulationConfig m, {String? id, double? amount}) {
    return ModulationConfig(
      id: id ?? m.id,
      type: m.type,
      amount: amount ?? m.amount,
      lfoConfig: m.lfoConfig,
      randomConfig: m.randomConfig,
      driftConfig: m.driftConfig,
      envelopeConfig: m.envelopeConfig,
      burstConfig: m.burstConfig,
      targets: m.targets,
    );
  }
}

// ── LFO ─────────────────────────────────

class _LfoSection extends StatelessWidget {
  const _LfoSection(this.mod, this.update);
  final ModulationConfig mod;
  final ValueChanged<ModulationConfig> update;

  LfoConfig get lfo => mod.lfoConfig ?? LfoConfig();

  void _updateLfo(LfoConfig l) =>
      update(ModulationConfig(id: mod.id, type: mod.type, amount: mod.amount, lfoConfig: l, targets: mod.targets));

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
          onChanged: (t) => _updateLfo(LfoConfig(type: t, frequency: lfo.frequency, depth: lfo.depth)),
        ),
        LabeledSlider(
          label: 'Frequency (Hz)',
          value: lfo.frequency.clamp(0.001, 20.0),
          min: 0.001,
          max: 20,
          displayValue: '${lfo.frequency.toStringAsFixed(3)} Hz',
          onChanged: (v) => _updateLfo(LfoConfig(type: lfo.type, frequency: v, depth: lfo.depth)),
        ),
        LabeledSlider(
          label: 'Depth',
          value: lfo.depth.clamp(0.0, 2.0),
          min: 0,
          max: 2,
          displayValue: lfo.depth.toStringAsFixed(2),
          onChanged: (v) => _updateLfo(LfoConfig(type: lfo.type, frequency: lfo.frequency, depth: v)),
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

  RandomConfig get r => mod.randomConfig ?? RandomConfig();

  void _updateRandom(RandomConfig nr) =>
      update(ModulationConfig(id: mod.id, type: mod.type, amount: mod.amount, randomConfig: nr, targets: mod.targets));

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
          onChanged: (v) => _updateRandom(RandomConfig(rateHz: v, smooth: r.smooth)),
        ),
        LabeledSlider(
          label: 'Smooth',
          value: r.smooth,
          min: 0,
          max: 1,
          displayValue: r.smooth.toStringAsFixed(2),
          onChanged: (v) => _updateRandom(RandomConfig(rateHz: r.rateHz, smooth: v)),
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

  DriftConfig get d => mod.driftConfig ?? DriftConfig();

  void _updateDrift(DriftConfig nd) =>
      update(ModulationConfig(id: mod.id, type: mod.type, amount: mod.amount, driftConfig: nd, targets: mod.targets));

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
          onChanged: (v) => _updateDrift(DriftConfig(speed: v, range: d.range)),
        ),
        LabeledSlider(
          label: 'Range',
          value: d.range.clamp(0.0, 2.0),
          min: 0,
          max: 2,
          displayValue: d.range.toStringAsFixed(2),
          onChanged: (v) => _updateDrift(DriftConfig(speed: d.speed, range: v)),
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

  EnvelopeConfig get e => mod.envelopeConfig ?? EnvelopeConfig();

  void _updateEnvelope(EnvelopeConfig ne) => update(
    ModulationConfig(id: mod.id, type: mod.type, amount: mod.amount, envelopeConfig: ne, targets: mod.targets),
  );

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'ENVELOPE',
      children: [
        LabeledIntField(
          label: 'Attack (ms)',
          value: e.attackMs,
          min: 0,
          onChanged: (v) => _updateEnvelope(
            EnvelopeConfig(attackMs: v, decayMs: e.decayMs, sustain: e.sustain, releaseMs: e.releaseMs),
          ),
        ),
        LabeledIntField(
          label: 'Decay (ms)',
          value: e.decayMs,
          min: 0,
          onChanged: (v) => _updateEnvelope(
            EnvelopeConfig(attackMs: e.attackMs, decayMs: v, sustain: e.sustain, releaseMs: e.releaseMs),
          ),
        ),
        LabeledSlider(
          label: 'Sustain',
          value: e.sustain,
          min: 0,
          max: 1,
          displayValue: e.sustain.toStringAsFixed(2),
          onChanged: (v) => _updateEnvelope(
            EnvelopeConfig(attackMs: e.attackMs, decayMs: e.decayMs, sustain: v, releaseMs: e.releaseMs),
          ),
        ),
        LabeledIntField(
          label: 'Release (ms)',
          value: e.releaseMs,
          min: 0,
          onChanged: (v) => _updateEnvelope(
            EnvelopeConfig(attackMs: e.attackMs, decayMs: e.decayMs, sustain: e.sustain, releaseMs: v),
          ),
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

  BurstConfig get b => mod.burstConfig ?? BurstConfig();

  void _updateBurst(BurstConfig nb) =>
      update(ModulationConfig(id: mod.id, type: mod.type, amount: mod.amount, burstConfig: nb, targets: mod.targets));

  BurstConfig _copy({
    int? durationMs,
    double? intensity,
    double? randomness,
    int? attackMs,
    int? releaseMs,
    int? clusterMin,
    int? clusterMax,
    int? clusterSpreadMs,
  }) {
    return BurstConfig(
      durationMs: durationMs ?? b.durationMs,
      intensity: intensity ?? b.intensity,
      randomness: randomness ?? b.randomness,
      attackMs: attackMs ?? b.attackMs,
      releaseMs: releaseMs ?? b.releaseMs,
      clusterMin: clusterMin ?? b.clusterMin,
      clusterMax: clusterMax ?? b.clusterMax,
      clusterSpreadMs: clusterSpreadMs ?? b.clusterSpreadMs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'BURST',
      children: [
        LabeledIntField(
          label: 'Duration (ms)',
          value: b.durationMs,
          min: 1,
          onChanged: (v) => _updateBurst(_copy(durationMs: v)),
        ),
        LabeledSlider(
          label: 'Intensity',
          value: b.intensity,
          min: 0,
          max: 1,
          displayValue: b.intensity.toStringAsFixed(2),
          onChanged: (v) => _updateBurst(_copy(intensity: v)),
        ),
        LabeledSlider(
          label: 'Randomness',
          value: b.randomness,
          min: 0,
          max: 1,
          displayValue: b.randomness.toStringAsFixed(2),
          onChanged: (v) => _updateBurst(_copy(randomness: v)),
        ),
        LabeledIntField(
          label: 'Attack (ms)',
          value: b.attackMs,
          min: 0,
          onChanged: (v) => _updateBurst(_copy(attackMs: v)),
        ),
        LabeledIntField(
          label: 'Release (ms)',
          value: b.releaseMs,
          min: 1,
          onChanged: (v) => _updateBurst(_copy(releaseMs: v)),
        ),
        LabeledIntField(
          label: 'Cluster Min',
          value: b.clusterMin,
          min: 1,
          onChanged: (v) => _updateBurst(_copy(clusterMin: v)),
        ),
        LabeledIntField(
          label: 'Cluster Max',
          value: b.clusterMax,
          min: 1,
          onChanged: (v) => _updateBurst(_copy(clusterMax: v)),
        ),
        LabeledIntField(
          label: 'Spread (ms)',
          value: b.clusterSpreadMs,
          min: 0,
          onChanged: (v) => _updateBurst(_copy(clusterSpreadMs: v)),
        ),
      ],
    );
  }
}

// ── Targets ──────────────────────────────

class _TargetsSection extends StatelessWidget {
  const _TargetsSection({required this.modulation, required this.onUpdate});
  final ModulationConfig modulation;
  final ValueChanged<ModulationConfig> onUpdate;

  void _updateTargets(List<ModulationTargetConfig> targets) {
    onUpdate(
      ModulationConfig(
        id: modulation.id,
        type: modulation.type,
        amount: modulation.amount,
        lfoConfig: modulation.lfoConfig,
        randomConfig: modulation.randomConfig,
        driftConfig: modulation.driftConfig,
        envelopeConfig: modulation.envelopeConfig,
        burstConfig: modulation.burstConfig,
        targets: targets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            final newTarget = ModulationTargetConfig(path: '');
            _updateTargets([...modulation.targets, newTarget]);
          },
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, required this.index, required this.onChanged, required this.onRemove});

  final ModulationTargetConfig target;
  final int index;
  final ValueChanged<ModulationTargetConfig> onChanged;
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
          LabeledTextField(
            label: 'Path',
            value: target.path,
            hint: 'e.g. layers[0].processors[0].biquad.frequency',
            onChanged: (v) => onChanged(
              ModulationTargetConfig(
                path: v,
                amount: target.amount,
                mode: target.mode,
                minValue: target.minValue,
                maxValue: target.maxValue,
              ),
            ),
          ),
          LabeledSlider(
            label: 'Amount',
            value: target.amount.clamp(-2.0, 2.0),
            min: -2,
            max: 2,
            displayValue: target.amount.toStringAsFixed(2),
            onChanged: (v) => onChanged(
              ModulationTargetConfig(
                path: target.path,
                amount: v,
                mode: target.mode,
                minValue: target.minValue,
                maxValue: target.maxValue,
              ),
            ),
          ),
          LabeledDropdown<ModulationApplyMode>(
            label: 'Mode',
            value: target.mode,
            items: ModulationApplyMode.values,
            itemLabel: (m) => m.name,
            onChanged: (m) => onChanged(
              ModulationTargetConfig(
                path: target.path,
                amount: target.amount,
                mode: m,
                minValue: target.minValue,
                maxValue: target.maxValue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
