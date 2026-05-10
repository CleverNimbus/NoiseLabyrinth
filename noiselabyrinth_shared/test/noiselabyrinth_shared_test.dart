import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

import 'package:noiselabyrinth_shared/noiselabyrinth_shared.dart';

void main() {
  test('exports reusable shared services', () {
    const id3Writer = Id3TagWriter();
    const mfccExtractor = MfccExtractor();
    const mp3Renderer = Mp3Renderer();
    const outputPathPolicy = OutputPathPolicy();
    const renderConfigPolicy = RenderConfigPolicy();

    expect(id3Writer, isA<Id3TagWriter>());
    expect(mfccExtractor, isA<MfccExtractor>());
    expect(mp3Renderer, isA<Mp3Renderer>());
    expect(outputPathPolicy, isA<OutputPathPolicy>());
    expect(renderConfigPolicy, isA<RenderConfigPolicy>());
  });

  test('output path policy builds deterministic file names', () {
    const outputPathPolicy = OutputPathPolicy();
    final timestamp = DateTime(2026, 5, 10, 18, 7, 2);

    final filename = outputPathPolicy.outputFilename(3, timestamp);
    expect(filename, '3_20260510_180702.mp3');
  });

  test('render config policy keeps render fields when forcing mp3', () {
    const renderConfigPolicy = RenderConfigPolicy();
    final input = whiteNoiseProfile;

    final normalized = renderConfigPolicy.forceMp3(input);

    expect(normalized.render.durationMinutes, input.render.durationMinutes);
    expect(normalized.render.sampleRate, input.render.sampleRate);
    expect(normalized.render.bitRate, input.render.bitRate);
    expect(normalized.render.dcBlockerEnabled, input.render.dcBlockerEnabled);
    expect(normalized.layers.length, input.layers.length);
  });

  test('shared profile catalog provides default profiles', () {
    expect(SharedProfileCatalog.defaultProfiles, isNotEmpty);
    expect(SharedProfileCatalog.defaultProfiles.first.metadata.name, isNotEmpty);
  });
}
