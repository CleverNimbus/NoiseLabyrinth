import 'package:noiselabyrinth_core/engine/modulators/adsr_envelope_modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/burst_modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/drift_modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/smooth_random_modulator.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

class ModulationTargetBinding {
  const ModulationTargetBinding({
    required this.parameter,
    required this.amount,
    this.mode = ModulationApplyMode.additive,
    this.minValue,
    this.maxValue,
  });
  final Parameter parameter;
  final double amount;
  final ModulationApplyMode mode;
  final double? minValue;
  final double? maxValue;
}

class RuntimeModulationBinding {
  const RuntimeModulationBinding({
    required this.id,
    required this.modulator,
    required this.amount,
    required this.targets,
  });
  final String id;
  final Modulator modulator;
  final double amount;
  final List<ModulationTargetBinding> targets;
}

class ModulatorFactory {
  static Modulator create(ModulationConfig config, int sampleRate) {
    switch (config.type) {
      case ModulationType.lfo:
        final lfo = config.lfoConfig;
        if (lfo == null) {
          throw StateError('lfoConfig is required for lfo modulation.');
        }
        return LfoSineModulator(
          sampleRate: sampleRate,
          frequency: lfo.frequency,
          depth: lfo.depth,
        );
      case ModulationType.random:
        final random = config.randomConfig;
        if (random == null) {
          throw StateError('randomConfig is required for random modulation.');
        }
        return SmoothRandomModulator(
          sampleRate: sampleRate,
          rateHz: random.rateHz,
          smooth: random.smooth,
        );
      case ModulationType.drift:
        final drift = config.driftConfig;
        if (drift == null) {
          throw StateError('driftConfig is required for drift modulation.');
        }
        return DriftModulator(
          sampleRate: sampleRate,
          speed: drift.speed,
          range: drift.range,
        );
      case ModulationType.envelope:
        final envelope = config.envelopeConfig;
        if (envelope == null) {
          throw StateError(
            'envelopeConfig is required for envelope modulation.',
          );
        }
        return AdsrEnvelopeModulator(
          sampleRate: sampleRate,
          attackMs: envelope.attackMs,
          decayMs: envelope.decayMs,
          sustain: envelope.sustain,
          releaseMs: envelope.releaseMs,
        );
      case ModulationType.burst:
        final burst = config.burstConfig;
        if (burst == null) {
          throw StateError('burstConfig is required for burst modulation.');
        }
        return BurstModulator(
          sampleRate: sampleRate,
          durationMs: burst.durationMs,
          intensity: burst.intensity,
          randomness: burst.randomness,
          attackMs: burst.attackMs,
          releaseMs: burst.releaseMs,
          clusterMin: burst.clusterMin,
          clusterMax: burst.clusterMax,
          clusterSpreadMs: burst.clusterSpreadMs,
        );
    }
  }
}
