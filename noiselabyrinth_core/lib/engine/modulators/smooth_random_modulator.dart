import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';

class SmoothRandomModulator implements Modulator {
  SmoothRandomModulator({
    required this.sampleRate,
    required this.rateHz,
    required this.smooth,
  }) : _segmentSamples = math.max(
         1,
         (sampleRate / (rateHz <= 0.0 ? 0.01 : rateHz)).round(),
       ),
       _followFactor = (1.0 - smooth).clamp(0.001, 1.0);
  final int sampleRate;
  final double rateHz;
  final double smooth;
  final int _segmentSamples;
  final double _followFactor;

  int _rngState = 0xA3C59AC3;
  double _current = 0;
  double _target = 0;
  int _samplesUntilTarget = 0;

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
    _rngState = nextXorshift32(_rngState);
    return ((_rngState & 0x7FFFFFFF) / 1073741824.0) - 1.0;
  }
}
