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

void main() {
  group('profile validation harness', () {
    const extractor = AudioFeatureExtractor(
      temporalWindowSize: 4096,
      temporalHopSize: 4096,
    );
    const validator = ProfileValidator();
    const factory = ProfileConstraintFactory();

    ({AudioFeatures features, ValidationResult result}) validatePreset(
      GenerationConfig config,
    ) {
      final spec = factory.resolve(config);
      final samples = _renderConfig(
        config,
        sampleRate: spec.sampleRate,
        totalSamples: spec.totalSamples,
        blockSize: spec.blockSize,
      );
      final features = extractor.extract(samples, sampleRate: spec.sampleRate);
      final result = validator.validate(features, spec.constraints);

      expect(result.failures, isEmpty, reason: result.failures.join('\n'));
      expect(result.passed, isTrue);
      return (features: features, result: result);
    }

    test('white noise profile matches explicit broadband validation spec', () {
      validatePreset(whiteNoiseProfile);
    });

    test('brown sleep-like profile matches explicit low-frequency validation spec', () {
      final validation = validatePreset(brownNoiseDeepField);
      final features = validation.features;
      expect(features.bandEnergy['low'], greaterThan(features.bandEnergy['high']!));
    });

    test('gain-modulated profile matches explicit dynamic-stability validation spec', () {
      final validation = validatePreset(lfoGainTest);
      final features = validation.features;
      expect(features.windowedRms.variance, greaterThan(0.0003));
    });

    test('bandlimited noise profile matches explicit mid-focused validation spec', () {
      final validation = validatePreset(bandlimitedNoiseProfile);
      final features = validation.features;
      expect(features.bandEnergy['mid'], greaterThan(features.bandEnergy['low']!));
      expect(features.bandEnergy['mid'], greaterThan(features.bandEnergy['high']!));
    });

    test('random filter profile matches explicit wandering mid-focus validation spec', () {
      final validation = validatePreset(randomFilterTest);
      final features = validation.features;
      expect(features.windowedSpectralCentroid.variance, greaterThan(150.0));
    });

    test('storm forest vivid profile matches explicit burst-dynamic validation spec', () {
      final validation = validatePreset(stormForestVivid);
      final features = validation.features;
      expect(features.burstFactor, greaterThan(1.05));
    });
  });
}
