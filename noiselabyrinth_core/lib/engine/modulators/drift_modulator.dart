import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';

class DriftModulator implements Modulator {
  DriftModulator({
    required this.sampleRate,
    required this.speed,
    required this.range,
  }) : _stepPerSample = (sampleRate > 0 ? (speed / sampleRate) : 0.0).clamp(
         0.0,
         1.0,
       ),
       _clampedRange = range.abs();
  final int sampleRate;
  final double speed;
  final double range;
  final double _stepPerSample;
  final double _clampedRange;

  int _rngState = 0x5F37_59DF;
  double _value = 0;

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
      state = nextXorshift32(state);
      final noiseStep = (((state & 0x7FFFFFFF) / 1073741824.0) - 1.0) * _stepPerSample;
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
}
