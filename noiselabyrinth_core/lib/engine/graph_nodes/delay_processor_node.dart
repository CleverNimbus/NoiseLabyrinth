import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class DelayProcessorNode extends ProcessorNode {
  DelayProcessorNode({
    required super.id,
    required int delayTimeMs,
    required double feedback,
    required double mix,
  }) : _smoothedFeedback = SmoothedParameter(feedback, _feedbackSmoothing),
       _smoothedMix = SmoothedParameter(mix, _mixSmoothing),
       super(
         parameters: <String, Parameter>{
           'delayTimeMs': Parameter(delayTimeMs.toDouble()),
           'feedback': Parameter(feedback),
           'mix': Parameter(mix),
         },
       );
  static const double _feedbackSmoothing = 0.1;
  static const double _mixSmoothing = 0.1;

  Float32List _delayLine = Float32List(1);
  int _writeIndex = 0;
  int _delaySamples = 1;

  final SmoothedParameter _smoothedFeedback;
  final SmoothedParameter _smoothedMix;

  @override
  void prepare(int sampleRate, int blockSize) {
    super.prepare(sampleRate, blockSize);
    final delayMs = parameter('delayTimeMs')!.baseValue.clamp(1.0, 5000.0);
    _delaySamples = (delayMs * sampleRate / 1000).round().clamp(
      1,
      sampleRate * 5,
    );
    _delayLine = Float32List(_delaySamples);
    _writeIndex = 0;
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawFeedback = parameter('feedback')!.finalValue;
    _smoothedFeedback.target = rawFeedback.isFinite ? rawFeedback.clamp(0.0, 0.95) : 0.0;
    _smoothedFeedback.update();
    final feedback = _smoothedFeedback.current.clamp(0.0, 0.95);

    final rawMix = parameter('mix')!.finalValue;
    _smoothedMix.target = rawMix.isFinite ? rawMix.clamp(0.0, 1.0) : 0.0;
    _smoothedMix.update();
    final mix = _smoothedMix.current.clamp(0.0, 1.0);

    final len = _delayLine.length;
    for (var i = 0; i < buffer.length; i++) {
      // Read the oldest sample (delaySamples ago) from the ring buffer.
      final delayedOut = _delayLine[_writeIndex];
      // Overwrite that slot with the current input plus feedback.
      _delayLine[_writeIndex] = buffer[i] + delayedOut * feedback;
      _writeIndex = (_writeIndex + 1) % len;
      buffer[i] = buffer[i] * (1.0 - mix) + delayedOut * mix;
    }
  }
}
