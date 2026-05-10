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
    switch (t) {
      case SourceType.noise:
        return SourceConfig(
          type: t,
          noiseConfig: source.noiseConfig ?? NoiseConfig(color: NoiseColor.white, band: BandConfig()),
        );
      case SourceType.impulse:
        return SourceConfig(type: t, impulseConfig: source.impulseConfig ?? const ImpulseConfig());
      case SourceType.sine:
        return SourceConfig(type: t, sineConfig: source.sineConfig ?? const SineConfig());
    }
  }
}

// ── Noise ────────────────────────────────

class _NoiseSection extends StatelessWidget {
  const _NoiseSection(this.source, this.update);
  final SourceConfig source;
  final ValueChanged<SourceConfig> update;

  NoiseConfig get noise => source.noiseConfig ?? NoiseConfig(color: NoiseColor.white, band: BandConfig());

  void _updateNoise(NoiseConfig n) => update(SourceConfig(type: source.type, noiseConfig: n));

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
          onChanged: (c) => _updateNoise(NoiseConfig(color: c, band: noise.band)),
        ),
        InspectorSection(
          title: 'BAND',
          children: [
            LabeledIntField(
              label: 'Low (Hz)',
              value: noise.band.low,
              min: 0,
              onChanged: (v) => _updateNoise(
                NoiseConfig(
                  color: noise.color,
                  band: BandConfig(low: v, high: noise.band.high),
                ),
              ),
            ),
            LabeledIntField(
              label: 'High (Hz)',
              value: noise.band.high,
              min: 1,
              onChanged: (v) => _updateNoise(
                NoiseConfig(
                  color: noise.color,
                  band: BandConfig(low: noise.band.low, high: v),
                ),
              ),
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

  ImpulseConfig get cfg => source.impulseConfig ?? ImpulseConfig();

  void _updateImpulse(ImpulseConfig c) => update(SourceConfig(type: source.type, impulseConfig: c));

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
          onChanged: (v) => _updateImpulse(ImpulseConfig(density: v, randomness: cfg.randomness)),
        ),
        LabeledSlider(
          label: 'Randomness',
          value: cfg.randomness,
          min: 0,
          max: 1,
          displayValue: cfg.randomness.toStringAsFixed(2),
          onChanged: (v) => _updateImpulse(ImpulseConfig(density: cfg.density, randomness: v)),
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

  SineConfig get cfg => source.sineConfig ?? const SineConfig();

  void _updateSine(SineConfig c) => update(SourceConfig(type: source.type, sineConfig: c));

  @override
  Widget build(BuildContext context) {
    return InspectorSection(
      title: 'SINE',
      children: [
        LabeledIntField(
          label: 'Frequency (Hz)',
          value: cfg.frequencyHz,
          min: 1,
          onChanged: (v) => _updateSine(SineConfig(frequencyHz: v, phase: cfg.phase)),
        ),
        LabeledDoubleField(
          label: 'Phase',
          value: cfg.phase,
          hint: '0.0',
          onChanged: (v) => _updateSine(SineConfig(frequencyHz: cfg.frequencyHz, phase: v)),
        ),
      ],
    );
  }
}
