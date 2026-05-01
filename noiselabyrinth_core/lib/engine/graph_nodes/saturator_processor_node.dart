import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class SaturatorProcessorNode extends ProcessorNode {
  SaturatorProcessorNode({
    required super.id,
    required this.curve,
    required double drive,
  }) : _smoothedDrive = SmoothedParameter(drive, _driveSmoothing),
       super(parameters: <String, Parameter>{'drive': Parameter(drive)});
  static const double _driveSmoothing = 0.1;

  final SaturatorCurve curve;
  final SmoothedParameter _smoothedDrive;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawDrive = parameter('drive')!.finalValue;
    _smoothedDrive.target = rawDrive.isFinite ? rawDrive.clamp(0.0, 1.0) : 0.0;
    _smoothedDrive.update();
    final drive = _smoothedDrive.current.clamp(0.0, 1.0);

    if (drive <= 0.0) {
      return;
    }

    switch (curve) {
      case SaturatorCurve.tanh:
        _processTanh(buffer, drive);
      case SaturatorCurve.soft:
        _processSoft(buffer, drive);
    }
  }

  void _processTanh(Float32List buffer, double drive) {
    // preGain scales from 1× (drive=0) to 10× (drive=1).
    final preGain = 1.0 + drive * 9.0;
    // normFactor ensures unity gain for full-scale (1.0) input.
    final normFactor = 1.0 / _tanh(preGain);
    final dry = 1.0 - drive;
    for (var i = 0; i < buffer.length; i++) {
      final x = buffer[i];
      final satOut = _tanh(x * preGain) * normFactor;
      buffer[i] = x * dry + satOut * drive;
    }
  }

  void _processSoft(Float32List buffer, double drive) {
    // preGain scales from 1× (drive=0) to 4× (drive=1).
    final preGain = 1.0 + drive * 3.0;
    final dry = 1.0 - drive;
    for (var i = 0; i < buffer.length; i++) {
      final x = buffer[i];
      final driven = (x * preGain).clamp(-1.0, 1.0);
      // Cubic soft-clip: y = (3/2) * x * (1 - x²/3).  Max output ±1.0 at x=±1.
      final satOut = 1.5 * driven * (1.0 - driven * driven / 3.0);
      buffer[i] = x * dry + satOut * drive;
    }
  }

  // dart:math has no tanh; this identity is numerically stable.
  static double _tanh(double x) {
    if (x > 20.0) return 1;
    if (x < -20.0) return -1;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }
}
