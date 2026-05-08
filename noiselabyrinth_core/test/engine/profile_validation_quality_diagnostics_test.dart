import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

import '../test_helpers/profile_validation_harness.dart';

Float32List _renderConfig(
  GenerationConfig config, {
  required int sampleRate,
  required int totalSamples,
  int blockSize = 256,
}) {
  final builder = RuntimeGraphBuilder(sampleRate: sampleRate);
  final graph = builder.build(config);
  final engine = AudioEngine(
    graph: graph,
    sampleRate: sampleRate,
    blockSize: blockSize,
  );
  return engine.renderSamples(totalSamples: totalSamples);
}

AudioFeatures _extractFeatures(
  GenerationConfig config, {
  int sampleRate = 8000,
  int totalSamples = 65536,
  int blockSize = 256,
}) {
  const extractor = AudioFeatureExtractor(
    temporalWindowSize: 4096,
    temporalHopSize: 4096,
  );
  final samples = _renderConfig(
    config,
    sampleRate: sampleRate,
    totalSamples: totalSamples,
    blockSize: blockSize,
  );
  return extractor.extract(samples, sampleRate: sampleRate);
}

void main() {
  group('profile quality diagnostics', () {
    test('bandlimited profile should strongly suppress high-band energy', () {
      final white = _extractFeatures(whiteNoiseProfile);
      final bandlimited = _extractFeatures(bandlimitedNoiseProfile);

      expect(
        bandlimited.bandEnergy['high'],
        lessThan(0.20),
        reason: 'Bandlimited profile should not retain broad high-frequency energy.',
      );
      expect(
        bandlimited.bandEnergy['mid'],
        greaterThan(bandlimited.bandEnergy['high']! * 2.0),
        reason: 'Bandlimited profile should be clearly mid-focused.',
      );
      expect(
        bandlimited.bandEnergy['high'],
        lessThan(white.bandEnergy['high']! * 0.6),
        reason: 'Bandlimited profile should suppress highs relative to white noise.',
      );
    });
  });
}
