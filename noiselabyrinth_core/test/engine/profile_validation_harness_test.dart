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
  });
}
