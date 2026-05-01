import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
  group('Curated preset catalog', () {
    test('all curated presets are individually valid', () {
      const parser = GenerationConfigParser();

      for (final profile in curatedNoiseProfiles) {
        final issues = parser.validate(profile);
        expect(
          issues,
          isEmpty,
          reason: 'Expected ${profile.metadata.name} to validate cleanly.',
        );
      }
    });

    test('category selections can be merged into one valid config', () {
      const merger = GenerationsMerger();
      const parser = GenerationConfigParser();

      final merged = merger.mergeAll(<GenerationConfig>[
        relaxEnergyProfile,
        focusPersonalityProfile,
        mutedStyleProfile,
        psychoacousticFeatureProfile,
      ]);

      expect(parser.validate(merged), isEmpty);
      expect(merged.layers.length, greaterThanOrEqualTo(4));
      expect(merged.metadata.tags, contains('merged'));
    });
  });
}
