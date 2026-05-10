import 'dart:math' as math;
import 'dart:typed_data';

abstract class Modulator {
  void process(int blockSize, Float32List buffer);

  void trigger() {}

  void reset() {}
}

class LfoSineModulator implements Modulator {
  LfoSineModulator({
    required this.sampleRate,
    required this.frequency,
    required this.depth,
  }) : _phaseStep = sampleRate > 0 ? _twoPi * frequency / sampleRate : 0.0;
  static const double _twoPi = 2.0 * math.pi;

  final int sampleRate;
  final double frequency;
  final double depth;
  final double _phaseStep;

  double _phase = 0;

  @override
  void process(int blockSize, Float32List buffer) {
    var phase = _phase;

    for (var i = 0; i < blockSize; i++) {
      buffer[i] = math.sin(phase) * depth;
      phase += _phaseStep;
      if (phase >= _twoPi) {
        phase -= _twoPi;
      }
    }

    _phase = phase;
  }

  @override
  void trigger() {
    _phase = 0.0;
  }

  @override
  void reset() {
    _phase = 0.0;
  }
}
