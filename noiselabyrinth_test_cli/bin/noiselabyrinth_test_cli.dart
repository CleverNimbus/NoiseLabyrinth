import 'dart:io';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_test_cli/noiselabyrinth_test_cli.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  stdout.writeln('NoiseLabyrinth core runtime test CLI');
  stdout.writeln('');

  while (true) {
    for (var i = 0; i < hardcodedProfiles.length; i++) {
      final profile = hardcodedProfiles[i];
      final config = profile.config;
      stdout.writeln(
        '${i + 1}. ${profile.title} '
        '(${config.render.durationMinutes} min, '
        '${config.render.sampleRate} Hz, '
        '${config.render.bitRate} kbps)',
      );
    }

    stdout.writeln('0. Exit');
    stdout.write('\nChoose a profile number: ');
    final input = stdin.readLineSync()?.trim();
    final selectedNumber = int.tryParse(input ?? '');

    if (selectedNumber == 0) {
      stdout.writeln('Goodbye.');
      return;
    }

    if (selectedNumber == null ||
        selectedNumber < 1 ||
        selectedNumber > hardcodedProfiles.length) {
      stderr.writeln('Invalid selection. Please enter a number from the list.');
      stdout.writeln('');
      continue;
    }

    final profile = hardcodedProfiles[selectedNumber - 1];
    final config = forceMp3(profile.config);
    final outputDirectory = userMusicDirectory();
    final outputPath = p.join(
      outputDirectory.path,
      outputFilename(selectedNumber, DateTime.now()),
    );

    stdout.writeln('\nRendering "${profile.title}" with AudioEngine...');
    stdout.writeln('Output: $outputPath');

    try {
      await outputDirectory.create(recursive: true);
      final bytes = await Renderer.renderMp3(config);
      await File(outputPath).writeAsBytes(bytes, flush: true);
      stdout.writeln('Done.');
    } on Object catch (error, stackTrace) {
      stderr.writeln('Render failed: $error');
      stderr.writeln(stackTrace);
    }

    stdout.writeln('');
  }
}
