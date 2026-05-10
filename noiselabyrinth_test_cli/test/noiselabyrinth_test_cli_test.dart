import 'package:noiselabyrinth_test_cli/noiselabyrinth_test_cli.dart';
import 'package:test/test.dart';

void main() {
  test('hardcoded profiles are valid mp3 configs', () {
    expect(hardcodedProfiles, isNotEmpty);

    for (final profile in hardcodedProfiles) {
      expect(profile.metadata.name, isNotEmpty);
      expect(profile.metadata.name, isNotEmpty);
      expect(profile.render.durationMinutes, greaterThan(0));
      expect(profile.render.format.name, 'mp3');
      expect(profile.layers, isNotEmpty);
    }
  });

  test('output filename includes menu entry and timestamp', () {
    final filename = outputFilename(2, DateTime(2026, 5, 1, 9, 8, 7));

    expect(filename, '2_20260501_090807.mp3');
  });
}
