import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class GainProcessorNode extends ProcessorNode {
  GainProcessorNode({required super.id, required double gain})
    : _smoothedGain = SmoothedParameter(gain, gainSmoothing),
      super(parameters: <String, Parameter>{'gain': Parameter(gain)});
  static const double gainSmoothing = 0.2;

  final SmoothedParameter _smoothedGain;

  double get smoothedGain => _smoothedGain.current;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawGain = parameter('gain')!.finalValue;
    _smoothedGain.target = rawGain.isFinite ? rawGain : 0.0;
    _smoothedGain.update();
    final gainValue = _smoothedGain.current.isFinite ? _smoothedGain.current : 0.0;
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] *= gainValue;
    }
  }
}
