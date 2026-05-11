import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class SourceInspector extends ConsumerWidget {
  const SourceInspector({super.key, required this.layer});
  final LayerConfig layer;

  SourceConfig get source => layer.source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(SourceConfig s) => ref.read(editorNotifierProvider.notifier).updateSource(layer.id, s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'SOURCE TYPE',
          children: [
            LabeledDropdown<SourceType>(
              label: 'Type',
              value: source.type,
              items: SourceType.values,
              itemLabel: (t) => t.name,
              onChanged: (t) => update(_switchType(t)),
            ),
          ],
        ),
        if (source.type == SourceType.noise) _NoiseSection(source, update),
        if (source.type == SourceType.impulse) _ImpulseSection(source, update),
        if (source.type == SourceType.sine) _SineSection(source, update),
      ],
    );
  }

  SourceConfig _switchType(SourceType t) {
    source.type = t;
    switch (t) {
      case SourceType.noise:
        source.noiseConfig ??= NoiseConfig(color: NoiseColor.white, band: BandConfig());
      case SourceType.impulse:
        source.impulseConfig ??= ImpulseConfig();
      case SourceType.sine:
        source.sineConfig ??= SineConfig();
    }
    return source;
  }
}

// ── Noise ────────────────────────────────

class _NoiseSection extends StatelessWidget {
  const _NoiseSection(this.source, this.update);
  final SourceConfig source;
  final ValueChanged<SourceConfig> update;

  NoiseConfig get noise => source.noiseConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'NOISE',
      children: [
        LabeledDropdown<NoiseColor>(
          label: 'Color',
          value: noise.color,
          items: NoiseColor.values,
          itemLabel: (c) => c.name,
          onChanged: (c) {
            noise.color = c;
            update(source);
          },
        ),
        if (noise.color == NoiseColor.bandlimited)
          InspectorSection(
            title: 'BAND',
            children: [
              LabeledSlider(
                label: 'Low (Hz)',
                value: noise.band.low.toDouble().clamp(0.0, 20000.0),
                min: 0,
                max: 20000,
                displayValue: '${noise.band.low.round()} Hz',
                onChanged: (v) {
                  noise.band.low = v.round();
                  update(source);
                },
              ),
              LabeledSlider(
                label: 'High (Hz)',
                value: noise.band.high.toDouble().clamp(0.0, 20000.0),
                min: 0,
                max: 20000,
                displayValue: '${noise.band.high.round()} Hz',
                onChanged: (v) {
                  noise.band.high = v.round();
                  update(source);
                },
              ),
            ],
          ),
      ],
    );
  }
}

// ── Impulse ──────────────────────────────

class _ImpulseSection extends StatelessWidget {
  const _ImpulseSection(this.source, this.update);
  final SourceConfig source;
  final ValueChanged<SourceConfig> update;

  ImpulseConfig get cfg => source.impulseConfig!;

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'IMPULSE',
      children: [
        LabeledSlider(
          label: 'Density',
          value: cfg.density,
          min: 0,
          max: 1,
          displayValue: cfg.density.toStringAsFixed(2),
          onChanged: (v) {
            cfg.density = v;
            update(source);
          },
        ),
        LabeledSlider(
          label: 'Randomness',
          value: cfg.randomness,
          min: 0,
          max: 1,
          displayValue: cfg.randomness.toStringAsFixed(2),
          onChanged: (v) {
            cfg.randomness = v;
            update(source);
          },
        ),
      ],
    );
  }
}

// ── Sine ─────────────────────────────────

class _SineSection extends StatelessWidget {
  const _SineSection(this.source, this.update);
  final SourceConfig source;
  final ValueChanged<SourceConfig> update;

  SineConfig get cfg => source.sineConfig!;
  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'SINE',
      children: [
        LabeledSlider(
          label: 'Frequency (Hz)',
          value: cfg.frequencyHz.toDouble().clamp(20.0, 20000.0),
          min: 20,
          max: 20000,
          displayValue: '${cfg.frequencyHz.round()} Hz',
          onChanged: (v) {
            cfg.frequencyHz = v.round();
            update(source);
          },
        ),
        LabeledSlider(
          label: 'Phase',
          value: cfg.phase.clamp(0.0, 1.0),
          min: 0,
          max: 1,
          displayValue: (cfg.phase * 360).toStringAsFixed(1),
          onChanged: (v) {
            cfg.phase = v;
            update(source);
          },
        ),
      ],
    );
  }
}
