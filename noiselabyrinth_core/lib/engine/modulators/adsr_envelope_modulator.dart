import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';

enum _EnvelopeStage { idle, attack, decay, sustain }

class AdsrEnvelopeModulator implements Modulator {
  AdsrEnvelopeModulator({
    required this.sampleRate,
    required this.attackMs,
    required this.decayMs,
    required this.sustain,
    required this.releaseMs,
  }) : _attackSamples = _msToSamplesStatic(sampleRate, attackMs),
       _decaySamples = _msToSamplesStatic(sampleRate, decayMs),
       _sustainValue = sustain.clamp(0.0, 1.0),
       _releaseStep = 1.0 / _msToSamplesStatic(sampleRate, releaseMs);
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
  double _value = 0;

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      switch (_stage) {
        case _EnvelopeStage.idle:
          _value = _applyRelease(_value);
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
        case _EnvelopeStage.sustain:
          _value = _sustainValue;
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
      return 0;
    }

    final next = current - _releaseStep;
    if (next <= 0.0) {
      return 0;
    }
    return next;
  }
}
