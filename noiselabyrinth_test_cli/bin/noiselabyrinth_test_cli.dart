import 'dart:io';

import 'package:noiselabyrinth_shared/noiselabyrinth_shared.dart';
import 'package:noiselabyrinth_test_cli/noiselabyrinth_test_cli.dart';

Future<void> main(List<String> arguments) async {
  const mfccExtractor = MfccExtractor();
  const id3TagWriter = Id3TagWriter();
  const mp3Renderer = Mp3Renderer();
  const outputPathPolicy = OutputPathPolicy();
  const renderConfigPolicy = RenderConfigPolicy();

  stdout
    ..writeln('NoiseLabyrinth core runtime test CLI')
    ..writeln();

  while (true) {
    for (var i = 0; i < hardcodedProfiles.length; i++) {
      final profile = hardcodedProfiles[i];
      stdout.writeln(
        '${i + 1}. ${profile.metadata.name} '
        '(${profile.render.durationMinutes} min, '
        '${profile.render.sampleRate} Hz, '
        '${profile.render.bitRate} kbps)',
      );
    }

    stdout
      ..writeln('0. Exit')
      ..write('\nChoose a profile number: ');
    final input = stdin.readLineSync()?.trim();
    final selectedNumber = int.tryParse(input ?? '');

    if (selectedNumber == 0) {
      stdout.writeln('Goodbye.');
      return;
    }

    if (selectedNumber == null || selectedNumber < 1 || selectedNumber > hardcodedProfiles.length) {
      stderr.writeln('Invalid selection. Please enter a number from the list.');
      stdout.writeln();
      continue;
    }

    final profile = hardcodedProfiles[selectedNumber - 1];
    final config = renderConfigPolicy.forceMp3(profile);
    final outputDirectory = outputPathPolicy.userMusicDirectory();
    final outputPath = outputPathPolicy.outputPath(selectedNumber, DateTime.now());

    stdout
      ..writeln('\nRendering "${profile.metadata.name}" with AudioEngine...')
      ..writeln('Output: $outputPath');

    try {
      await outputDirectory.create(recursive: true);
      final generationStopwatch = Stopwatch()..start();
      final bytes = await mp3Renderer.render(config);
      await File(outputPath).writeAsBytes(bytes, flush: true);
      generationStopwatch.stop();
      final generationDuration = generationStopwatch.elapsed;
      final mfccPayload = mfccExtractor.extractPayload(config);
      stdout.writeln('Done.');
      await id3TagWriter.writeTags(
        outputPath,
        config,
        generationDuration: generationDuration,
        mfccPayload: mfccPayload,
        artist: 'NoiseLabyrinth Test CLI',
      );
    } on Object catch (error, stackTrace) {
      stderr
        ..writeln('Render failed: $error')
        ..writeln(stackTrace);
    }

    stdout.writeln();
  }
}
