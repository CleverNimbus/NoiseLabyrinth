import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class BiquadProcessorNode extends ProcessorNode {
  BiquadProcessorNode({
    required super.id,
    required this.mode,
    required int frequency,
    required double q,
    required double gainDb,
    this.resonant = false,
  }) : _smoothedFrequency = SmoothedParameter(
         frequency.toDouble(),
         frequencySmoothing,
       ),
       super(
         parameters: <String, Parameter>{
           'frequency': Parameter(frequency.toDouble()),
           'q': Parameter(q),
           'gainDb': Parameter(gainDb),
         },
       );
  static const double frequencySmoothing = 0.2;
  static final double _nonResonantMaxQ = 1.0 / math.sqrt(2.0);

  final BiquadMode mode;
  final bool resonant;
  final SmoothedParameter _smoothedFrequency;

  double _b0 = 1;
  double _b1 = 0;
  double _b2 = 0;
  double _a1 = 0;
  double _a2 = 0;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  double? _lastFrequency;
  double? _lastQ;
  double? _lastGainDb;
  int _coefficientUpdateCount = 0;

  int get coefficientUpdateCount => _coefficientUpdateCount;
  double get smoothedFrequency => _smoothedFrequency.current;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    _updateCoefficientsIfNeeded();

    var x1 = _x1;
    var x2 = _x2;
    var y1 = _y1;
    var y2 = _y2;

    for (var i = 0; i < buffer.length; i++) {
      final x0 = buffer[i];
      final y0 = (_b0 * x0) + (_b1 * x1) + (_b2 * x2) - (_a1 * y1) - (_a2 * y2);

      buffer[i] = y0;

      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }

    _x1 = x1;
    _x2 = x2;
    _y1 = y1;
    _y2 = y2;
  }

  void _updateCoefficientsIfNeeded() {
    final frequencyParameter = parameter('frequency')!;
    final qParameter = parameter('q')!;
    final gainDbParameter = parameter('gainDb')!;

    final rawFrequency = frequencyParameter.finalValue;
    _smoothedFrequency.target = rawFrequency;
    _smoothedFrequency.update();
    final nyquist = sampleRate > 0 ? sampleRate * 0.5 : 22050.0;
    final frequency = _smoothedFrequency.current.clamp(1.0, nyquist - 1.0);
    final rawQ = qParameter.finalValue < 1e-4 ? 1e-4 : qParameter.finalValue;
    final q = resonant ? rawQ : rawQ.clamp(1e-4, _nonResonantMaxQ);
    final gainDb = gainDbParameter.finalValue;

    final frequencyChanged = _lastFrequency == null || (_lastFrequency! - frequency).abs() > 1e-9;
    final qChanged = _lastQ == null || (_lastQ! - q).abs() > 1e-9;
    final gainChangedForPeak = mode == BiquadMode.peak && (_lastGainDb == null || (_lastGainDb! - gainDb).abs() > 1e-9);

    if (!frequencyChanged && !qChanged && !gainChangedForPeak) {
      return;
    }

    final omega = 2.0 * math.pi * frequency / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2.0 * q);

    final double b0;
    final double b1;
    final double b2;
    switch (mode) {
      case BiquadMode.lowpass:
        b0 = (1.0 - cosOmega) * 0.5;
        b1 = 1.0 - cosOmega;
        b2 = (1.0 - cosOmega) * 0.5;
      case BiquadMode.highpass:
        b0 = (1.0 + cosOmega) * 0.5;
        b1 = -(1.0 + cosOmega);
        b2 = (1.0 + cosOmega) * 0.5;
      case BiquadMode.bandpass:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
      case BiquadMode.peak:
        final gainLinear = math.pow(10.0, gainDb / 40.0).toDouble();
        b0 = 1.0 + alpha * gainLinear;
        b1 = -2.0 * cosOmega;
        b2 = 1.0 - alpha * gainLinear;
        final a0Peak = 1.0 + alpha / gainLinear;
        final a1Peak = -2.0 * cosOmega;
        final a2Peak = 1.0 - alpha / gainLinear;

        _b0 = b0 / a0Peak;
        _b1 = b1 / a0Peak;
        _b2 = b2 / a0Peak;
        _a1 = a1Peak / a0Peak;
        _a2 = a2Peak / a0Peak;

        _lastFrequency = frequency;
        _lastQ = q;
        _lastGainDb = gainDb;
        _coefficientUpdateCount++;
        return;
    }
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;

    _lastFrequency = frequency;
    _lastQ = q;
    _lastGainDb = gainDb;
    _coefficientUpdateCount++;
  }
}
