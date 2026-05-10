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
            LabeledTextField(label: 'ID', value: processor.id, onChanged: (v) => update(processor..id = v)),
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
    p.type = t;
    p.biquad = t == ProcessorType.biquad ? (p.biquad ?? BiquadConfig()) : null;
    p.gain = t == ProcessorType.gain ? (p.gain ?? GainConfig()) : null;
    p.saturator = t == ProcessorType.saturator ? (p.saturator ?? SaturatorConfig()) : null;
    p.delay = t == ProcessorType.delay ? (p.delay ?? DelayConfig()) : null;
    return p;
  }
}

// ── Biquad ───────────────────────────────

class _BiquadSection extends StatelessWidget {
  const _BiquadSection(this.processor, this.update);
  final ProcessorConfig processor;
  final ValueChanged<ProcessorConfig> update;

  BiquadConfig get b => processor.biquad!;

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
          onChanged: (m) {
            b.biquadMode = m;
            update(processor);
          },
        ),
        LabeledSlider(
          label: 'Frequency (Hz)',
          value: b.frequency.toDouble().clamp(20.0, 20000.0),
          min: 20,
          max: 20000,
          displayValue: '${b.frequency.round()} Hz',
          onChanged: (v) {
            b.frequency = v.round();
            update(processor);
          },
        ),
        LabeledSlider(
          label: 'Q',
          value: b.q.clamp(0.1, 10.0),
          min: 0.1,
          max: 10,
          displayValue: b.q.toStringAsFixed(2),
          onChanged: (v) {
            b.q = v;
            update(processor);
          },
        ),
        LabeledSlider(
          label: 'Gain (dB)',
          value: b.gainDb.clamp(-12.0, 12.0),
          min: -12,
          max: 12,
          displayValue: b.gainDb.toStringAsFixed(1),
          onChanged: (v) {
            b.gainDb = v;
            update(processor);
          },
        ),
        LabeledSwitch(
          label: 'Resonant',
          value: b.resonant,
          onChanged: (v) {
            b.resonant = v;
            update(processor);
          },
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

  GainConfig get g => processor.gain!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'GAIN',
      children: [
        LabeledSlider(
          label: 'Gain',
          value: g.gain.clamp(-60.0, 60.0),
          min: -60,
          max: 60,
          displayValue: g.gain.toStringAsFixed(1),
          onChanged: (v) {
            g.gain = v;
            update(processor);
          },
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

  SaturatorConfig get s => processor.saturator!;

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
          onChanged: (v) {
            s.drive = v;
            update(processor);
          },
        ),
        LabeledDropdown<SaturatorCurve>(
          label: 'Curve',
          value: s.curve,
          items: SaturatorCurve.values,
          itemLabel: (c) => c.name,
          onChanged: (c) {
            s.curve = c;
            update(processor);
          },
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

  DelayConfig get d => processor.delay!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'DELAY',
      children: [
        LabeledSlider(
          label: 'Time (ms)',
          value: d.delayTimeMs.toDouble().clamp(0.0, 500.0),
          min: 0,
          max: 500,
          displayValue: '${d.delayTimeMs.round()} ms',
          onChanged: (v) {
            d.delayTimeMs = v.round();
            update(processor);
          },
        ),
        LabeledSlider(
          label: 'Feedback',
          value: d.feedback,
          min: 0,
          max: 1,
          displayValue: d.feedback.toStringAsFixed(2),
          onChanged: (v) {
            d.feedback = v;
            update(processor);
          },
        ),
        LabeledSlider(
          label: 'Mix',
          value: d.mix,
          min: 0,
          max: 1,
          displayValue: d.mix.toStringAsFixed(2),
          onChanged: (v) {
            d.mix = v;
            update(processor);
          },
        ),
      ],
    );
  }
}
