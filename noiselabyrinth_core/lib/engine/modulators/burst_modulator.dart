import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';

class BurstModulator implements Modulator {
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
    int seed = 0,
  }) : _attackSamples = _msToSamplesStatic(sampleRate, attackMs),
       _releaseSamples = _msToSamplesStatic(sampleRate, releaseMs),
       _clusterSpreadSamples = _msToSamplesStatic(sampleRate, clusterSpreadMs),
       _maxLifeSamples = _msToSamplesStatic(sampleRate, durationMs),
       _clampedIntensity = intensity.clamp(0.0, 1.0),
       _clampedRandomness = randomness.clamp(0.0, 1.0),
       _rngState = _nonZeroSeed(seed);
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

  int _rngState;
  final List<_ScheduledBurst> _scheduledBursts = <_ScheduledBurst>[];
  final List<_ActiveBurst> _activeBursts = <_ActiveBurst>[];

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
    final randomScalar = (1.0 - _clampedRandomness) + (_clampedRandomness * _nextUnit01());
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
    _rngState = nextXorshift32(_rngState);
    return (_rngState & 0x7FFFFFFF) / 2147483647.0;
  }

  static int _nonZeroSeed(int seed) {
    final normalized = seed & 0xFFFFFFFF;
    return normalized == 0 ? 0x7A5B3C2D : normalized;
  }
}

enum _BurstEnvelopeStage { idle, attack, release }

class _ScheduledBurst {
  _ScheduledBurst({required this.samplesUntilStart, required this.level});
  int samplesUntilStart;
  final double level;
}

class _ActiveBurst {
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
  static const double _epsilon = 1e-9;

  final double level;
  final double _attackStep;
  final double _releaseStep;
  final int _maxLifeSamples;

  _BurstEnvelopeStage _stage = _BurstEnvelopeStage.idle;
  double _envelope = 0;
  int _lifetimeSamples = 0;

  bool get finished => _stage == _BurstEnvelopeStage.idle;

  double nextSample() {
    _lifetimeSamples++;
    if (_lifetimeSamples >= _maxLifeSamples && _stage != _BurstEnvelopeStage.idle) {
      _stage = _BurstEnvelopeStage.release;
    }

    switch (_stage) {
      case _BurstEnvelopeStage.idle:
        return 0;
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
          return 0;
        }
        return _envelope * level;
    }
  }
}
