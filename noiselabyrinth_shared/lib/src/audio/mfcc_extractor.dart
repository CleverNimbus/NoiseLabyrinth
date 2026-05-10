import 'dart:math';

import 'package:mcfcc_nsn/mcfcc_nsn.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class MfccExtractor {
  const MfccExtractor();

  Map<String, Object?> extractPayload(GenerationConfig config) {
    final sampleRate = config.render.sampleRate;
    final windowLength = max(1, (sampleRate * 0.025).round());
    final windowStride = max(1, (sampleRate * 0.010).round());
    final fftSize = _nextPowerOfTwo(windowLength);
    const numFilters = 40;
    const numCoefs = 13;

    final stereo = Renderer.renderPcm(config);
    final totalSamples = stereo.left.length;

    if (totalSamples < windowLength) {
      return {
        'sampleRate': sampleRate,
        'windowLength': windowLength,
        'windowStride': windowStride,
        'fftSize': fftSize,
        'numFilters': numFilters,
        'numCoefs': numCoefs,
        'features': <List<double>>[],
      };
    }

    final monoSignal = List<double>.generate(
      totalSamples,
      (i) => (stereo.left[i] + stereo.right[i]) * 0.5,
      growable: false,
    );

    final features = MFCC.mfccFeats(monoSignal, sampleRate, windowLength, windowStride, fftSize, numFilters, numCoefs);

    return {
      'sampleRate': sampleRate,
      'windowLength': windowLength,
      'windowStride': windowStride,
      'fftSize': fftSize,
      'numFilters': numFilters,
      'numCoefs': numCoefs,
      'features': features,
    };
  }

  int _nextPowerOfTwo(int value) {
    var power = 1;
    while (power < value) {
      power <<= 1;
    }
    return power;
  }
}
