import 'dart:math' as math;

import 'package:noiselabyrinth_core/models/enums.dart';

class BiquadCoefficients {
  const BiquadCoefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  const BiquadCoefficients.identity() : b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0;

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;
}

class BiquadDesigner {
  static BiquadCoefficients design({
    required BiquadMode mode,
    required double sampleRate,
    required double frequency,
    required double q,
    double gainDb = 0.0,
  }) {
    final omega = 2.0 * math.pi * frequency / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2.0 * q);

    switch (mode) {
      case BiquadMode.lowpass:
        final b0 = (1.0 - cosOmega) * 0.5;
        final b1 = 1.0 - cosOmega;
        final b2 = (1.0 - cosOmega) * 0.5;
        final a0 = 1.0 + alpha;
        final a1 = -2.0 * cosOmega;
        final a2 = 1.0 - alpha;
        return BiquadCoefficients(
          b0: b0 / a0,
          b1: b1 / a0,
          b2: b2 / a0,
          a1: a1 / a0,
          a2: a2 / a0,
        );
      case BiquadMode.highpass:
        final b0 = (1.0 + cosOmega) * 0.5;
        final b1 = -(1.0 + cosOmega);
        final b2 = (1.0 + cosOmega) * 0.5;
        final a0 = 1.0 + alpha;
        final a1 = -2.0 * cosOmega;
        final a2 = 1.0 - alpha;
        return BiquadCoefficients(
          b0: b0 / a0,
          b1: b1 / a0,
          b2: b2 / a0,
          a1: a1 / a0,
          a2: a2 / a0,
        );
      case BiquadMode.bandpass:
        final b0 = alpha;
        const b1 = 0;
        final b2 = -alpha;
        final a0 = 1.0 + alpha;
        final a1 = -2.0 * cosOmega;
        final a2 = 1.0 - alpha;
        return BiquadCoefficients(
          b0: b0 / a0,
          b1: b1 / a0,
          b2: b2 / a0,
          a1: a1 / a0,
          a2: a2 / a0,
        );
      case BiquadMode.peak:
        final gainLinear = math.pow(10.0, gainDb / 40.0).toDouble();
        final b0 = 1.0 + alpha * gainLinear;
        final b1 = -2.0 * cosOmega;
        final b2 = 1.0 - alpha * gainLinear;
        final a0 = 1.0 + alpha / gainLinear;
        final a1 = -2.0 * cosOmega;
        final a2 = 1.0 - alpha / gainLinear;
        return BiquadCoefficients(
          b0: b0 / a0,
          b1: b1 / a0,
          b2: b2 / a0,
          a1: a1 / a0,
          a2: a2 / a0,
        );
    }
  }
}

class BiquadSection {
  BiquadCoefficients coefficients = const BiquadCoefficients.identity();

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  void bypass() {
    coefficients = const BiquadCoefficients.identity();
  }

  void reset() {
    _x1 = 0.0;
    _x2 = 0.0;
    _y1 = 0.0;
    _y2 = 0.0;
  }

  double process(double input) {
    final output =
        (coefficients.b0 * input) +
        (coefficients.b1 * _x1) +
        (coefficients.b2 * _x2) -
        (coefficients.a1 * _y1) -
        (coefficients.a2 * _y2);
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = output;
    return output;
  }
}
