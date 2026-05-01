import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

class NoiseSourceNode extends SourceNode {
  NoiseSourceNode({
    required super.id,
    required this.color,
    required int low,
    required int high,
    int seed = 0,
  }) : _rngState = 1,
       super(
         parameters: <String, Parameter>{
           'bandLow': Parameter(low.toDouble()),
           'bandHigh': Parameter(high.toDouble()),
         },
       ) {
    _rngState = _nonZeroSeed(seed, id);
  }
  static const double _twoPi = 2.0 * math.pi;

  final NoiseColor color;
  int _rngState;

  // State for brown and pink noise shaping.
  double _brownState = 0;
  double _pink0 = 0;
  double _pink1 = 0;
  double _pink2 = 0;
  double _pink3 = 0;
  double _pink4 = 0;
  double _pink5 = 0;
  double _pink6 = 0;

  // State for simple band-limiting (high-pass then low-pass).
  double _bandLowAlpha = 0;
  double _bandHighAlpha = 0;
  double _bandLowHz = 0;
  double _bandHighHz = 0;
  double _bandPrevInput = 0;
  double _bandHighState = 0;
  double _bandLowState = 0;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    if (color == NoiseColor.bandlimited) {
      _updateBandlimitCoefficientsIfNeeded();
    }

    var state = _rngState;
    for (var i = 0; i < buffer.length; i++) {
      state = nextXorshift32(state);
      final white = _stateToUnitFloat(state);

      switch (color) {
        case NoiseColor.white:
          buffer[i] = white;
        case NoiseColor.bandlimited:
          buffer[i] = _nextBandlimitedSample(white);
        case NoiseColor.brown:
          buffer[i] = _nextBrownSample(white);
        case NoiseColor.pink:
          buffer[i] = _nextPinkSample(white);
      }
    }
    _rngState = state;
  }

  void _updateBandlimitCoefficientsIfNeeded() {
    final nyquist = sampleRate > 0 ? (sampleRate * 0.5) : 22050.0;
    final requestedLow = parameter('bandLow')!.finalValue;
    final requestedHigh = parameter('bandHigh')!.finalValue;

    var low = requestedLow.clamp(0.0, nyquist - 2.0);
    var high = requestedHigh.clamp(1.0, nyquist - 1.0);
    if (high <= low + 1.0) {
      high = (low + 1.0).clamp(1.0, nyquist - 1.0);
      low = (high - 1.0).clamp(0.0, nyquist - 2.0);
    }

    if ((_bandLowHz - low).abs() < 1e-9 && (_bandHighHz - high).abs() < 1e-9) {
      return;
    }

    final dt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 44100.0;

    if (low <= 0.0) {
      _bandLowAlpha = 0.0;
    } else {
      final rcLow = 1.0 / (_twoPi * low);
      _bandLowAlpha = rcLow / (rcLow + dt);
    }

    final rcHigh = 1.0 / (_twoPi * high);
    _bandHighAlpha = dt / (rcHigh + dt);

    _bandLowHz = low;
    _bandHighHz = high;
  }

  double _nextBandlimitedSample(double white) {
    final highPassed = _bandLowAlpha <= 0.0 ? white : _bandLowAlpha * (_bandHighState + white - _bandPrevInput);
    _bandPrevInput = white;
    _bandHighState = highPassed;

    _bandLowState += _bandHighAlpha * (highPassed - _bandLowState);
    return _bandLowState.clamp(-1.0, 1.0);
  }

  double _nextBrownSample(double white) {
    // Integrated white with gentle leakage to avoid DC drift.
    _brownState = (_brownState + (white * 0.02)) * 0.995;
    _brownState = _brownState.clamp(-1.0, 1.0);
    return _brownState;
  }

  double _nextPinkSample(double white) {
    // Paul Kellet-style pinking filter.
    _pink0 = (0.99886 * _pink0) + (white * 0.0555179);
    _pink1 = (0.99332 * _pink1) + (white * 0.0750759);
    _pink2 = (0.96900 * _pink2) + (white * 0.1538520);
    _pink3 = (0.86650 * _pink3) + (white * 0.3104856);
    _pink4 = (0.55000 * _pink4) + (white * 0.5329522);
    _pink5 = (-0.7616 * _pink5) - (white * 0.0168980);

    final pink = _pink0 + _pink1 + _pink2 + _pink3 + _pink4 + _pink5 + _pink6 + (white * 0.5362);
    _pink6 = white * 0.115926;

    return (pink * 0.11).clamp(-1.0, 1.0);
  }

  static double _stateToUnitFloat(int state) {
    return ((state & 0x7FFFFFFF) / 1073741824.0) - 1.0;
  }

  static int _nonZeroSeed(int seed, String id) {
    if (seed != 0) {
      return seed & 0xFFFFFFFF;
    }

    var hash = 2166136261;
    for (final codeUnit in id.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }

    return hash == 0 ? 0x6D2B79F5 : hash;
  }
}
