import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

class SineSourceNode extends SourceNode {
  SineSourceNode({
    required super.id,
    required int frequencyHz,
    required double phase,
  }) : super(
         parameters: <String, Parameter>{
           'frequencyHz': Parameter(frequencyHz.toDouble()),
           'phase': Parameter(phase),
         },
       );
  static const double _twoPi = 2.0 * math.pi;

  double _phaseAccumulator = 0;

  @override
  void prepare(int sampleRate, int blockSize) {
    super.prepare(sampleRate, blockSize);
    _phaseAccumulator = parameter('phase')!.baseValue;
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final nyquist = sampleRate > 0 ? sampleRate * 0.5 : 22050.0;
    final frequency = parameter(
      'frequencyHz',
    )!.finalValue.clamp(0.0, nyquist);
    final phaseOffset = parameter('phase')!.finalValue;
    final phaseStep = sampleRate > 0 ? _twoPi * frequency / sampleRate : 0.0;

    var phase = _phaseAccumulator;
    for (var i = 0; i < buffer.length; i++) {
      final wrappedPhase = phase + phaseOffset;
      buffer[i] = math.sin(wrappedPhase);
      phase += phaseStep;
      if (phase >= _twoPi) {
        phase -= _twoPi;
      }
    }

    _phaseAccumulator = phase;
  }
}
