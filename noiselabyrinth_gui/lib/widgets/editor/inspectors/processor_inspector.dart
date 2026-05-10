import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class ProcessorInspector extends ConsumerWidget {
  const ProcessorInspector({super.key, required this.layer, required this.processor});

  final LayerConfig layer;
  final ProcessorConfig processor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(ProcessorConfig p) => ref.read(editorNotifierProvider.notifier).updateProcessor(layer.id, p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'PROCESSOR',
          children: [
            LabeledTextField(
              label: 'ID',
              value: processor.id,
              onChanged: (v) => update(_copy(processor, id: v)),
            ),
            LabeledDropdown<ProcessorType>(
              label: 'Type',
              value: processor.type,
              items: ProcessorType.values,
              itemLabel: (t) => t.name,
              onChanged: (t) => update(_switchType(processor, t)),
            ),
          ],
        ),
        if (processor.type == ProcessorType.biquad) _BiquadSection(processor, update),
        if (processor.type == ProcessorType.gain) _GainSection(processor, update),
        if (processor.type == ProcessorType.saturator) _SaturatorSection(processor, update),
        if (processor.type == ProcessorType.delay) _DelaySection(processor, update),
      ],
    );
  }

  ProcessorConfig _switchType(ProcessorConfig p, ProcessorType t) {
    return ProcessorConfig(
      id: p.id,
      type: t,
      biquad: t == ProcessorType.biquad ? (p.biquad ?? BiquadConfig()) : null,
      gain: t == ProcessorType.gain ? (p.gain ?? GainConfig()) : null,
      saturator: t == ProcessorType.saturator ? (p.saturator ?? SaturatorConfig()) : null,
      delay: t == ProcessorType.delay ? (p.delay ?? DelayConfig()) : null,
    );
  }

  ProcessorConfig _copy(ProcessorConfig p, {String? id}) {
    return ProcessorConfig(
      id: id ?? p.id,
      type: p.type,
      biquad: p.biquad,
      gain: p.gain,
      saturator: p.saturator,
      delay: p.delay,
    );
  }
}

// ── Biquad ───────────────────────────────

class _BiquadSection extends StatelessWidget {
  const _BiquadSection(this.processor, this.update);
  final ProcessorConfig processor;
  final ValueChanged<ProcessorConfig> update;

  BiquadConfig get b => processor.biquad ?? BiquadConfig();

  void _updateBiquad(BiquadConfig nb) => update(ProcessorConfig(id: processor.id, type: processor.type, biquad: nb));

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'BIQUAD FILTER',
      children: [
        LabeledDropdown<BiquadMode>(
          label: 'Mode',
          value: b.biquadMode,
          items: BiquadMode.values,
          itemLabel: (m) => m.name,
          onChanged: (m) => _updateBiquad(
            BiquadConfig(biquadMode: m, frequency: b.frequency, q: b.q, gainDb: b.gainDb, resonant: b.resonant),
          ),
        ),
        LabeledIntField(
          label: 'Frequency (Hz)',
          value: b.frequency,
          min: 1,
          onChanged: (v) => _updateBiquad(
            BiquadConfig(biquadMode: b.biquadMode, frequency: v, q: b.q, gainDb: b.gainDb, resonant: b.resonant),
          ),
        ),
        LabeledDoubleField(
          label: 'Q',
          value: b.q,
          hint: '> 0',
          onChanged: (v) => _updateBiquad(
            BiquadConfig(
              biquadMode: b.biquadMode,
              frequency: b.frequency,
              q: v,
              gainDb: b.gainDb,
              resonant: b.resonant,
            ),
          ),
        ),
        LabeledDoubleField(
          label: 'Gain (dB)',
          value: b.gainDb,
          onChanged: (v) => _updateBiquad(
            BiquadConfig(biquadMode: b.biquadMode, frequency: b.frequency, q: b.q, gainDb: v, resonant: b.resonant),
          ),
        ),
        LabeledSwitch(
          label: 'Resonant',
          value: b.resonant,
          onChanged: (v) => _updateBiquad(
            BiquadConfig(biquadMode: b.biquadMode, frequency: b.frequency, q: b.q, gainDb: b.gainDb, resonant: v),
          ),
        ),
      ],
    );
  }
}

// ── Gain ─────────────────────────────────

class _GainSection extends StatelessWidget {
  const _GainSection(this.processor, this.update);
  final ProcessorConfig processor;
  final ValueChanged<ProcessorConfig> update;

  GainConfig get g => processor.gain ?? GainConfig();

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'GAIN',
      children: [
        LabeledDoubleField(
          label: 'Gain',
          value: g.gain,
          onChanged: (v) => update(
            ProcessorConfig(
              id: processor.id,
              type: processor.type,
              gain: GainConfig(gain: v),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Saturator ────────────────────────────

class _SaturatorSection extends StatelessWidget {
  const _SaturatorSection(this.processor, this.update);
  final ProcessorConfig processor;
  final ValueChanged<ProcessorConfig> update;

  SaturatorConfig get s => processor.saturator ?? SaturatorConfig();

  void _updateSat(SaturatorConfig ns) => update(ProcessorConfig(id: processor.id, type: processor.type, saturator: ns));

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'SATURATOR',
      children: [
        LabeledSlider(
          label: 'Drive',
          value: s.drive.clamp(0.0, 10.0),
          min: 0,
          max: 10,
          displayValue: s.drive.toStringAsFixed(2),
          onChanged: (v) => _updateSat(SaturatorConfig(drive: v, curve: s.curve)),
        ),
        LabeledDropdown<SaturatorCurve>(
          label: 'Curve',
          value: s.curve,
          items: SaturatorCurve.values,
          itemLabel: (c) => c.name,
          onChanged: (c) => _updateSat(SaturatorConfig(drive: s.drive, curve: c)),
        ),
      ],
    );
  }
}

// ── Delay ────────────────────────────────

class _DelaySection extends StatelessWidget {
  const _DelaySection(this.processor, this.update);
  final ProcessorConfig processor;
  final ValueChanged<ProcessorConfig> update;

  DelayConfig get d => processor.delay ?? DelayConfig();

  void _updateDelay(DelayConfig nd) => update(ProcessorConfig(id: processor.id, type: processor.type, delay: nd));

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'DELAY',
      children: [
        LabeledIntField(
          label: 'Time (ms)',
          value: d.delayTimeMs,
          min: 0,
          onChanged: (v) => _updateDelay(DelayConfig(delayTimeMs: v, feedback: d.feedback, mix: d.mix)),
        ),
        LabeledSlider(
          label: 'Feedback',
          value: d.feedback,
          min: 0,
          max: 1,
          displayValue: d.feedback.toStringAsFixed(2),
          onChanged: (v) => _updateDelay(DelayConfig(delayTimeMs: d.delayTimeMs, feedback: v, mix: d.mix)),
        ),
        LabeledSlider(
          label: 'Mix',
          value: d.mix,
          min: 0,
          max: 1,
          displayValue: d.mix.toStringAsFixed(2),
          onChanged: (v) => _updateDelay(DelayConfig(delayTimeMs: d.delayTimeMs, feedback: d.feedback, mix: v)),
        ),
      ],
    );
  }
}
