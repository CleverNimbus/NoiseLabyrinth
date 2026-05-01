import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_core/presets/tests.dart';

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

    test('random filter profile should produce substantial centroid drift over time', () {
      final features = _extractFeatures(randomFilterTest);

      expect(
        features.windowedSpectralCentroid.variance,
        greaterThan(2000.0),
        reason: 'A wandering filter should measurably move the spectral center over windows.',
      );
    });

    test('storm forest vivid should remain dynamic without excessive clipping', () {
      final features = _extractFeatures(stormForestVivid);

      expect(
        features.clippedRatio,
        lessThan(0.05),
        reason: 'Dynamic ambience should not spend a large fraction of samples clipped.',
      );
      expect(
        features.burstFactor,
        greaterThan(1.3),
        reason: 'Burst-driven ambience should show stronger transient-to-average contrast.',
      );
    });

    test('storm forest vivid should be burstier than slow gain modulation', () {
      final storm = _extractFeatures(stormForestVivid);
      final lfo = _extractFeatures(lfoGainTest);

      expect(
        storm.burstFactor,
        greaterThan(lfo.burstFactor * 1.2),
        reason: 'Poisson bursts and thunder envelopes should exceed slow breathing modulation.',
      );
    });
  });
}
