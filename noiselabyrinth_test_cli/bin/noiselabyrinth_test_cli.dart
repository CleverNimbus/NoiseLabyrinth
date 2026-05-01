import 'dart:io';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_test_cli/noiselabyrinth_test_cli.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
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
    final config = forceMp3(profile);
    final outputDirectory = userMusicDirectory();
    final outputPath = p.join(
      outputDirectory.path,
      outputFilename(selectedNumber, DateTime.now()),
    );

    stdout
      ..writeln('\nRendering "${profile.metadata.name}" with AudioEngine...')
      ..writeln('Output: $outputPath');

    try {
      await outputDirectory.create(recursive: true);
      final bytes = await Renderer.renderMp3(config);
      await File(outputPath).writeAsBytes(bytes, flush: true);
      stdout.writeln('Done.');
    } on Object catch (error, stackTrace) {
      stderr
        ..writeln('Render failed: $error')
        ..writeln(stackTrace);
    }

    stdout.writeln();
  }
}
