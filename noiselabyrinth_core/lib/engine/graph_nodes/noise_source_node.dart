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
  static const double _gaussianScale = 0.5773502691896258;
  static final double _butterworthQ = 1.0 / math.sqrt(2.0);

  final NoiseColor color;
  int _rngState;
  bool _hasGaussianSpare = false;
  double _gaussianSpare = 0;

  // State for brown and pink noise shaping.
  double _brownState = 0;
  double _pink0 = 0;
  double _pink1 = 0;
  double _pink2 = 0;
  double _pink3 = 0;
  double _pink4 = 0;
  double _pink5 = 0;
  double _pink6 = 0;

  // State for band-limiting via cascaded biquad sections.
  double _bandLowHz = 0;
  double _bandHighHz = 0;
  final List<_BiquadSection> _bandHighpassStages = List<_BiquadSection>.generate(
    2,
    (_) => _BiquadSection(),
  );
  final List<_BiquadSection> _bandLowpassStages = List<_BiquadSection>.generate(
    2,
    (_) => _BiquadSection(),
  );

  @override
  void prepare(int sampleRate, int blockSize) {
    super.prepare(sampleRate, blockSize);
    _hasGaussianSpare = false;
    _gaussianSpare = 0.0;
    _lastGaussianState = _rngState;
    _brownState = 0.0;
    _pink0 = 0.0;
    _pink1 = 0.0;
    _pink2 = 0.0;
    _pink3 = 0.0;
    _pink4 = 0.0;
    _pink5 = 0.0;
    _pink6 = 0.0;
    _bandLowHz = double.nan;
    _bandHighHz = double.nan;
    for (final stage in _bandHighpassStages) {
      stage.reset();
    }
    for (final stage in _bandLowpassStages) {
      stage.reset();
    }
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    if (color == NoiseColor.bandlimited) {
      _updateBandlimitCoefficientsIfNeeded();
    }

    var state = _rngState;
    for (var i = 0; i < buffer.length; i++) {
      final white = _nextGaussianSample(state);
      state = _lastGaussianState;

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

    final effectiveSampleRate = sampleRate > 0 ? sampleRate.toDouble() : 44100.0;

    if (low <= 0.0) {
      for (final stage in _bandHighpassStages) {
        stage.bypass();
      }
    } else {
      for (final stage in _bandHighpassStages) {
        stage.configureHighpass(
          sampleRate: effectiveSampleRate,
          frequency: low,
          q: _butterworthQ,
        );
      }
    }

    for (final stage in _bandLowpassStages) {
      stage.configureLowpass(
        sampleRate: effectiveSampleRate,
        frequency: high,
        q: _butterworthQ,
      );
    }

    _bandLowHz = low;
    _bandHighHz = high;
  }

  double _nextBandlimitedSample(double white) {
    var sample = white;
    for (final stage in _bandHighpassStages) {
      sample = stage.process(sample);
    }
    for (final stage in _bandLowpassStages) {
      sample = stage.process(sample);
    }
    return sample.clamp(-1.0, 1.0);
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

  int _lastGaussianState = 0;

  double _nextGaussianSample(int seedState) {
    if (_hasGaussianSpare) {
      _hasGaussianSpare = false;
      _lastGaussianState = seedState;
      return (_gaussianSpare * _gaussianScale).clamp(-1.0, 1.0);
    }

    var state = seedState;
    while (true) {
      state = nextXorshift32(state);
      final u = _stateToCenteredUnitFloat(state);
      state = nextXorshift32(state);
      final v = _stateToCenteredUnitFloat(state);
      final s = (u * u) + (v * v);
      if (s <= 0.0 || s >= 1.0) {
        continue;
      }

      final scale = math.sqrt((-2.0 * math.log(s)) / s);
      _gaussianSpare = v * scale;
      _hasGaussianSpare = true;
      _lastGaussianState = state;
      return ((u * scale) * _gaussianScale).clamp(-1.0, 1.0);
    }
  }

  static double _stateToCenteredUnitFloat(int state) {
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

class _BiquadSection {
  static const double _twoPi = 2.0 * math.pi;

  double _b0 = 1;
  double _b1 = 0;
  double _b2 = 0;
  double _a1 = 0;
  double _a2 = 0;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  void reset() {
    _x1 = 0.0;
    _x2 = 0.0;
    _y1 = 0.0;
    _y2 = 0.0;
  }

  void bypass() {
    _b0 = 1.0;
    _b1 = 0.0;
    _b2 = 0.0;
    _a1 = 0.0;
    _a2 = 0.0;
  }

  void configureLowpass({
    required double sampleRate,
    required double frequency,
    required double q,
  }) {
    final omega = _twoPi * frequency / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2.0 * q);

    final b0 = (1.0 - cosOmega) * 0.5;
    final b1 = 1.0 - cosOmega;
    final b2 = (1.0 - cosOmega) * 0.5;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  void configureHighpass({
    required double sampleRate,
    required double frequency,
    required double q,
  }) {
    final omega = _twoPi * frequency / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2.0 * q);

    final b0 = (1.0 + cosOmega) * 0.5;
    final b1 = -(1.0 + cosOmega);
    final b2 = (1.0 + cosOmega) * 0.5;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  double process(double input) {
    final output = (_b0 * input) + (_b1 * _x1) + (_b2 * _x2) - (_a1 * _y1) - (_a2 * _y2);
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    return output;
  }
}
