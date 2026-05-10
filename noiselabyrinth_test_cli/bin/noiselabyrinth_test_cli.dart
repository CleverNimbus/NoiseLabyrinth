import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mcfcc_nsn/mcfcc_nsn.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_test_cli/noiselabyrinth_test_cli.dart';
import 'package:path/path.dart' as p;
import 'package:phonic/phonic.dart';

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
      final generationStopwatch = Stopwatch()..start();
      final bytes = await Renderer.renderMp3(config);
      await File(outputPath).writeAsBytes(bytes, flush: true);
      generationStopwatch.stop();
      final generationDuration = generationStopwatch.elapsed;
      final mfccPayload = extractMfccPayload(config);
      stdout.writeln('Done.');
      await writeId3Tags(
        outputPath,
        config,
        generationDuration: generationDuration,
        mfccPayload: mfccPayload,
      );
    } on Object catch (error, stackTrace) {
      stderr
        ..writeln('Render failed: $error')
        ..writeln(stackTrace);
    }

    stdout.writeln();
  }
}

Future<bool> writeId3Tags(
  String outputPath,
  GenerationConfig config, {
  required Duration generationDuration,
  required Map<String, Object?> mfccPayload,
}) async {
  final audioFile = await Phonic.fromFileAsync(outputPath);
  try {
    final title = config.metadata.name.trim();
    if (title.isNotEmpty) {
      audioFile.setTag(TitleTag(title));
    }

    final description = config.metadata.description.trim();
    if (description.isNotEmpty) {
      audioFile.setTag(CommentTag(description));
    }

    final customPayload = jsonEncode({
      'generationDuration': generationDuration.toString(),
      'config': config.toJson(),
      'mfcc': mfccPayload,
    });

    final recordedDateIso = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';
    audioFile
      ..setTag(CustomTag(customPayload))
      ..setTag(DateRecordedTag(recordedDateIso))
      ..setTag(const ArtistTag('NoiseLabyrinth Test CLI'))
      ..setTag(GenreTag(config.metadata.tags));

    final updatedBytes = await audioFile.encode();
    await File(outputPath).writeAsBytes(updatedBytes, flush: true);
    return true;
  } finally {
    audioFile.dispose();
  }
}

Map<String, Object?> extractMfccPayload(GenerationConfig config) {
  final sampleRate = config.render.sampleRate;
  final windowLength = max(1, (sampleRate * 0.025).round());
  final windowStride = max(1, (sampleRate * 0.010).round());
  final fftSize = _nextPowerOfTwo(windowLength);
  const numFilters = 40;
  const numCoefs = 13;

  final wavBytes = Renderer.renderWav(config);
  final monoSignal = _decodeMonoSignalFromPcm16StereoWav(wavBytes);
  if (monoSignal.length < windowLength) {
    return {
      'sampleRate': sampleRate,
      'windowLength': windowLength,
      'windowStride': windowStride,
      'fftSize': fftSize,
      'numFilters': numFilters,
      'numCoefs': numCoefs,
      'features': <List<double>>[],
    };
  }

  final features = MFCC.mfccFeats(
    monoSignal,
    sampleRate,
    windowLength,
    windowStride,
    fftSize,
    numFilters,
    numCoefs,
  );

  return {
    'sampleRate': sampleRate,
    'windowLength': windowLength,
    'windowStride': windowStride,
    'fftSize': fftSize,
    'numFilters': numFilters,
    'numCoefs': numCoefs,
    'features': features,
  };
}

List<double> _decodeMonoSignalFromPcm16StereoWav(Uint8List wavBytes) {
  if (wavBytes.lengthInBytes < 44) {
    throw const FormatException('Invalid WAV data: header is too short.');
  }

  final byteData = ByteData.sublistView(wavBytes);
  final channels = byteData.getUint16(22, Endian.little);
  final bitsPerSample = byteData.getUint16(34, Endian.little);
  if (channels != 2 || bitsPerSample != 16) {
    throw FormatException(
      'Unsupported WAV format for MFCC extraction: '
      'channels=$channels, bitsPerSample=$bitsPerSample.',
    );
  }

  final dataSize = byteData.getUint32(40, Endian.little);
  final sampleCount = dataSize ~/ 4;
  final mono = List<double>.filled(sampleCount, 0);

  var offset = 44;
  for (var i = 0; i < sampleCount; i++) {
    final left = byteData.getInt16(offset, Endian.little) / 32768.0;
    final right = byteData.getInt16(offset + 2, Endian.little) / 32768.0;
    mono[i] = (left + right) * 0.5;
    offset += 4;
  }

  return mono;
}

int _nextPowerOfTwo(int value) {
  var power = 1;
  while (power < value) {
    power <<= 1;
  }
  return power;
}
