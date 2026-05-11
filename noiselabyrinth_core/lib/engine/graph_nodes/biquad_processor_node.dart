import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/engine/dsp/biquad.dart';
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
       _smoothedQ = SmoothedParameter(
         q,
         qSmoothing,
       ),
       _smoothedGainDb = SmoothedParameter(
         gainDb,
         gainDbSmoothing,
       ),
       super(
         parameters: <String, Parameter>{
           'frequency': Parameter(frequency.toDouble()),
           'q': Parameter(q),
           'gainDb': Parameter(gainDb),
         },
       );
  static const double frequencySmoothing = 0.2;
  static const double qSmoothing = 0.2;
  static const double gainDbSmoothing = 0.2;
  static final double _nonResonantMaxQ = 1.0 / math.sqrt(2.0);

  final BiquadMode mode;
  final bool resonant;
  final SmoothedParameter _smoothedFrequency;
  final SmoothedParameter _smoothedQ;
  final SmoothedParameter _smoothedGainDb;
  final BiquadSection _section = BiquadSection();

  double? _lastFrequency;
  double? _lastQ;
  double? _lastGainDb;
  int _coefficientUpdateCount = 0;

  int get coefficientUpdateCount => _coefficientUpdateCount;
  double get smoothedFrequency => _smoothedFrequency.current;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    _updateCoefficientsIfNeeded();

    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = _section.process(buffer[i]);
    }
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
    _smoothedQ.target = qParameter.finalValue;
    _smoothedQ.update();
    final rawQ = _smoothedQ.current < 1e-4 ? 1e-4 : _smoothedQ.current;
    final q = resonant ? rawQ : rawQ.clamp(1e-4, _nonResonantMaxQ);
    _smoothedGainDb.target = gainDbParameter.finalValue;
    _smoothedGainDb.update();
    final gainDb = _smoothedGainDb.current;

    final frequencyChanged = _lastFrequency == null || (_lastFrequency! - frequency).abs() > 1e-9;
    final qChanged = _lastQ == null || (_lastQ! - q).abs() > 1e-9;
    final gainChangedForPeak = mode == BiquadMode.peak && (_lastGainDb == null || (_lastGainDb! - gainDb).abs() > 1e-9);

    if (!frequencyChanged && !qChanged && !gainChangedForPeak) {
      return;
    }

    _section.coefficients = BiquadDesigner.design(
      mode: mode,
      sampleRate: sampleRate.toDouble(),
      frequency: frequency,
      q: q,
      gainDb: gainDb,
    );

    _lastFrequency = frequency;
    _lastQ = q;
    _lastGainDb = gainDb;
    _coefficientUpdateCount++;
  }
}
