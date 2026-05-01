import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

abstract class Modulator {
  void process(int blockSize, Float32List buffer);

  void trigger() {}

  void reset() {}
}

class LfoSineModulator implements Modulator {
  static const double _twoPi = 2.0 * math.pi;

  final int sampleRate;
  final double frequency;
  final double depth;
  final double _phaseStep;

  double _phase = 0.0;

  LfoSineModulator({
    required this.sampleRate,
    required this.frequency,
    required this.depth,
  }) : _phaseStep = sampleRate > 0 ? _twoPi * frequency / sampleRate : 0.0;

  @override
  void process(int blockSize, Float32List buffer) {
    var phase = _phase;

    for (var i = 0; i < blockSize; i++) {
      buffer[i] = math.sin(phase) * depth;
      phase += _phaseStep;
      if (phase >= _twoPi) {
        phase -= _twoPi;
      }
    }

    _phase = phase;
  }

  @override
  void trigger() {
    _phase = 0.0;
  }

  @override
  void reset() {
    _phase = 0.0;
  }
}

class SmoothRandomModulator implements Modulator {
  final int sampleRate;
  final double rateHz;
  final double smooth;
  final int _segmentSamples;
  final double _followFactor;

  int _rngState = 0xA3C59AC3;
  double _current = 0.0;
  double _target = 0.0;
  int _samplesUntilTarget = 0;

  SmoothRandomModulator({
    required this.sampleRate,
    required this.rateHz,
    required this.smooth,
  }) : _segmentSamples = math.max(
         1,
         (sampleRate / (rateHz <= 0.0 ? 0.01 : rateHz)).round(),
       ),
       _followFactor = (1.0 - smooth).clamp(0.001, 1.0);

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      if (_samplesUntilTarget <= 0) {
        _target = _nextRandomBiPolar();
        _samplesUntilTarget = _segmentSamples;
      }

      _current += (_target - _current) * _followFactor;
      buffer[i] = _current;
      _samplesUntilTarget--;
    }
  }

  @override
  void trigger() {
    _samplesUntilTarget = 0;
  }

  @override
  void reset() {
    _current = 0.0;
    _target = 0.0;
    _samplesUntilTarget = 0;
  }

  double _nextRandomBiPolar() {
    _rngState = _xorshift32(_rngState);
    return ((_rngState & 0x7FFFFFFF) / 1073741824.0) - 1.0;
  }

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
  }
}

class DriftModulator implements Modulator {
  final int sampleRate;
  final double speed;
  final double range;
  final double _stepPerSample;
  final double _clampedRange;

  int _rngState = 0x5F37_59DF;
  double _value = 0.0;

  DriftModulator({
    required this.sampleRate,
    required this.speed,
    required this.range,
  }) : _stepPerSample = (sampleRate > 0 ? (speed / sampleRate) : 0.0).clamp(
         0.0,
         1.0,
       ),
       _clampedRange = range.abs();

  @override
  void process(int blockSize, Float32List buffer) {
    if (_stepPerSample <= 0.0 || _clampedRange <= 0.0) {
      for (var i = 0; i < blockSize; i++) {
        buffer[i] = 0.0;
      }
      return;
    }

    var state = _rngState;
    var value = _value;
    for (var i = 0; i < blockSize; i++) {
      state = _xorshift32(state);
      final noiseStep =
          (((state & 0x7FFFFFFF) / 1073741824.0) - 1.0) * _stepPerSample;
      value = (value + noiseStep).clamp(-_clampedRange, _clampedRange);
      buffer[i] = value;
    }

    _rngState = state;
    _value = value;
  }

  @override
  void reset() {
    _value = 0.0;
  }

  @override
  void trigger() {}

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
  }
}

enum _EnvelopeStage { idle, attack, decay, sustain }

class AdsrEnvelopeModulator implements Modulator {
  final int sampleRate;
  final int attackMs;
  final int decayMs;
  final double sustain;
  final int releaseMs;
  final int _attackSamples;
  final int _decaySamples;
  final double _sustainValue;
  final double _releaseStep;

  _EnvelopeStage _stage = _EnvelopeStage.idle;
  double _value = 0.0;

  AdsrEnvelopeModulator({
    required this.sampleRate,
    required this.attackMs,
    required this.decayMs,
    required this.sustain,
    required this.releaseMs,
  }) : _attackSamples = _msToSamplesStatic(sampleRate, attackMs),
       _decaySamples = _msToSamplesStatic(sampleRate, decayMs),
       _sustainValue = sustain.clamp(0.0, 1.0).toDouble(),
       _releaseStep = 1.0 / _msToSamplesStatic(sampleRate, releaseMs);

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      switch (_stage) {
        case _EnvelopeStage.idle:
          _value = _applyRelease(_value);
          break;
        case _EnvelopeStage.attack:
          if (_attackSamples <= 1) {
            _value = 1.0;
            _stage = _EnvelopeStage.decay;
          } else {
            _value += 1.0 / _attackSamples;
            if (_value >= 1.0) {
              _value = 1.0;
              _stage = _EnvelopeStage.decay;
            }
          }
          break;
        case _EnvelopeStage.decay:
          if (_decaySamples <= 1) {
            _value = _sustainValue;
            _stage = _EnvelopeStage.sustain;
          } else {
            _value -= (1.0 - _sustainValue) / _decaySamples;
            if (_value <= _sustainValue) {
              _value = _sustainValue;
              _stage = _EnvelopeStage.sustain;
            }
          }
          break;
        case _EnvelopeStage.sustain:
          _value = _sustainValue;
          break;
      }

      buffer[i] = _value;
    }
  }

  @override
  void trigger() {
    _stage = _EnvelopeStage.attack;
    if (_value < 0.0 || !_value.isFinite) {
      _value = 0.0;
    }
  }

  @override
  void reset() {
    _stage = _EnvelopeStage.idle;
  }

  static int _msToSamplesStatic(int sampleRate, int ms) {
    if (ms <= 0 || sampleRate <= 0) {
      return 1;
    }
    return math.max(1, (sampleRate * ms / 1000.0).round());
  }

  double _applyRelease(double current) {
    if (_releaseStep >= 1.0) {
      return 0.0;
    }

    final next = current - _releaseStep;
    if (next <= 0.0) {
      return 0.0;
    }
    return next;
  }
}

class BurstModulator implements Modulator {
  final int sampleRate;
  final int durationMs;
  final double intensity;
  final double randomness;
  final int attackMs;
  final int releaseMs;
  final int clusterMin;
  final int clusterMax;
  final int clusterSpreadMs;

  final int _attackSamples;
  final int _releaseSamples;
  final int _clusterSpreadSamples;
  final int _maxLifeSamples;
  final double _clampedIntensity;
  final double _clampedRandomness;

  int _rngState = 0x7A5B_3C2D;
  final List<_ScheduledBurst> _scheduledBursts = <_ScheduledBurst>[];
  final List<_ActiveBurst> _activeBursts = <_ActiveBurst>[];

  BurstModulator({
    required this.sampleRate,
    required this.durationMs,
    required this.intensity,
    required this.randomness,
    required this.attackMs,
    required this.releaseMs,
    required this.clusterMin,
    required this.clusterMax,
    required this.clusterSpreadMs,
  }) : _attackSamples = _msToSamplesStatic(sampleRate, attackMs),
       _releaseSamples = _msToSamplesStatic(sampleRate, releaseMs),
       _clusterSpreadSamples = _msToSamplesStatic(sampleRate, clusterSpreadMs),
       _maxLifeSamples = _msToSamplesStatic(sampleRate, durationMs),
       _clampedIntensity = intensity.clamp(0.0, 1.0).toDouble(),
       _clampedRandomness = randomness.clamp(0.0, 1.0).toDouble();

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      _activateReadyBursts();

      var sample = 0.0;
      var activeIndex = 0;
      while (activeIndex < _activeBursts.length) {
        final burst = _activeBursts[activeIndex];
        sample += burst.nextSample();
        if (burst.finished) {
          _activeBursts.removeAt(activeIndex);
          continue;
        }
        activeIndex++;
      }

      buffer[i] = sample;
      _advanceScheduledBursts();
    }
  }

  void _activateReadyBursts() {
    var index = 0;
    while (index < _scheduledBursts.length) {
      final scheduled = _scheduledBursts[index];
      if (scheduled.samplesUntilStart > 0) {
        index++;
        continue;
      }

      _activeBursts.add(
        _ActiveBurst(
          level: scheduled.level,
          attackSamples: _attackSamples,
          releaseSamples: _releaseSamples,
          maxLifeSamples: _maxLifeSamples,
        ),
      );
      _scheduledBursts.removeAt(index);
    }
  }

  void _advanceScheduledBursts() {
    for (var i = 0; i < _scheduledBursts.length; i++) {
      _scheduledBursts[i].samplesUntilStart--;
    }
  }

  int _nextBurstClusterCount() {
    if (clusterMax <= clusterMin) {
      return clusterMin;
    }
    final span = clusterMax - clusterMin + 1;
    return clusterMin + (_nextUnit01() * span).floor().clamp(0, span - 1);
  }

  int _nextClusterDelaySamples() {
    if (_clusterSpreadSamples <= 1) {
      return 0;
    }
    return (_nextUnit01() * _clusterSpreadSamples).floor().clamp(
      0,
      _clusterSpreadSamples - 1,
    );
  }

  double _nextBurstLevel() {
    final randomScalar =
        (1.0 - _clampedRandomness) + (_clampedRandomness * _nextUnit01());
    return _clampedIntensity * randomScalar;
  }

  @override
  void trigger() {
    final burstCount = _nextBurstClusterCount();
    for (var i = 0; i < burstCount; i++) {
      _scheduledBursts.add(
        _ScheduledBurst(
          samplesUntilStart: _nextClusterDelaySamples(),
          level: _nextBurstLevel(),
        ),
      );
    }
  }

  @override
  void reset() {
    _scheduledBursts.clear();
    _activeBursts.clear();
  }

  static int _msToSamplesStatic(int sampleRate, int ms) {
    if (ms <= 0 || sampleRate <= 0) {
      return 1;
    }
    return math.max(1, (sampleRate * ms / 1000.0).round());
  }

  double _nextUnit01() {
    _rngState = _xorshift32(_rngState);
    return (_rngState & 0x7FFFFFFF) / 2147483647.0;
  }

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
  }
}

enum _BurstEnvelopeStage { idle, attack, release }

class _ScheduledBurst {
  int samplesUntilStart;
  final double level;

  _ScheduledBurst({required this.samplesUntilStart, required this.level});
}

class _ActiveBurst {
  static const double _epsilon = 1e-9;

  final double level;
  final double _attackStep;
  final double _releaseStep;
  final int _maxLifeSamples;

  _BurstEnvelopeStage _stage = _BurstEnvelopeStage.idle;
  double _envelope = 0.0;
  int _lifetimeSamples = 0;

  _ActiveBurst({
    required this.level,
    required int attackSamples,
    required int releaseSamples,
    required int maxLifeSamples,
  }) : _attackStep = 1.0 / (attackSamples <= 0 ? 1 : attackSamples),
       _releaseStep = 1.0 / (releaseSamples <= 0 ? 1 : releaseSamples),
       _maxLifeSamples = maxLifeSamples <= 0 ? 1 : maxLifeSamples {
    _stage = _BurstEnvelopeStage.attack;
  }

  bool get finished => _stage == _BurstEnvelopeStage.idle;

  double nextSample() {
    _lifetimeSamples++;
    if (_lifetimeSamples >= _maxLifeSamples &&
        _stage != _BurstEnvelopeStage.idle) {
      _stage = _BurstEnvelopeStage.release;
    }

    switch (_stage) {
      case _BurstEnvelopeStage.idle:
        return 0.0;
      case _BurstEnvelopeStage.attack:
        _envelope += _attackStep;
        if (_envelope >= 1.0) {
          _envelope = 1.0;
          _stage = _BurstEnvelopeStage.release;
        }
        return _envelope * level;
      case _BurstEnvelopeStage.release:
        _envelope -= _releaseStep;
        if (_envelope <= _epsilon) {
          _envelope = 0.0;
          _stage = _BurstEnvelopeStage.idle;
          return 0.0;
        }
        return _envelope * level;
    }
  }
}

class ModulationTargetBinding {
  final Parameter parameter;
  final double amount;
  final ModulationApplyMode mode;
  final double? minValue;
  final double? maxValue;

  const ModulationTargetBinding({
    required this.parameter,
    required this.amount,
    this.mode = ModulationApplyMode.additive,
    this.minValue,
    this.maxValue,
  });
}

class RuntimeModulationBinding {
  final String id;
  final Modulator modulator;
  final double amount;
  final List<ModulationTargetBinding> targets;

  const RuntimeModulationBinding({
    required this.id,
    required this.modulator,
    required this.amount,
    required this.targets,
  });
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

class ModulationEngine {
  final List<RuntimeModulationBinding> bindings;
  Float32List _scratch = Float32List(0);

  ModulationEngine({required this.bindings});

  void processBlock(int blockSize) {
    if (bindings.isEmpty || blockSize <= 0) {
      return;
    }

    if (_scratch.length != blockSize) {
      _scratch = Float32List(blockSize);
    }

    for (final binding in bindings) {
      binding.modulator.process(blockSize, _scratch);

      var sum = 0.0;
      for (var i = 0; i < blockSize; i++) {
        sum += _scratch[i];
      }
      final blockValue = sum / blockSize;

      final modulationValue = blockValue * binding.amount;
      for (final target in binding.targets) {
        _applyToTarget(target, modulationValue);
      }
    }
  }

  void _applyToTarget(ModulationTargetBinding target, double modulationValue) {
    final parameter = target.parameter;
    final scaled = modulationValue * target.amount;

    final delta = switch (target.mode) {
      ModulationApplyMode.additive => scaled,
      ModulationApplyMode.multiplicative => parameter.baseValue * scaled,
    };

    final currentFinal = parameter.baseValue + parameter.modulationValue;
    var nextFinal = currentFinal + delta;

    final minValue = target.minValue;
    final maxValue = target.maxValue;
    if (minValue != null || maxValue != null) {
      final clampMin = minValue ?? double.negativeInfinity;
      final clampMax = maxValue ?? double.infinity;
      nextFinal = nextFinal.clamp(clampMin, clampMax).toDouble();
    }

    parameter.modulationValue = nextFinal - parameter.baseValue;
  }
}
