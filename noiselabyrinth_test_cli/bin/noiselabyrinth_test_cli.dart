import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_lame/flutter_lame.dart';
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
      final bytes = await _renderMp3(config);
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

/// Renders [config] to MP3 bytes by consuming stereo float PCM chunks
/// from core and encoding them directly with LAME.
Future<Uint8List> _renderMp3(GenerationConfig config) async {
  final encoder = LameMp3Encoder(
    sampleRate: config.render.sampleRate,
    bitRate: config.render.bitRate,
  );
  final encoded = BytesBuilder(copy: false);

  try {
    await for (final chunk in Renderer.renderPcmChunks(config)) {
      final sampleCount = chunk.left.length;
      final left = Int16List(sampleCount);
      final right = Int16List(sampleCount);
      for (var i = 0; i < sampleCount; i++) {
        left[i] = _toPcm16(chunk.left[i]);
        right[i] = _toPcm16(chunk.right[i]);
      }
      encoded.add(await encoder.encode(leftChannel: left, rightChannel: right));
    }

    encoded.add(await encoder.flush());
    return encoded.takeBytes();
  } finally {
    await encoder.close();
  }
}

/// Converts a normalized float sample [-1.0, 1.0] to a signed 16-bit integer.
int _toPcm16(double sample) {
  final clamped = sample < -1.0 ? -1.0 : (sample > 1.0 ? 1.0 : sample);
  return (clamped * 32767.0).round();
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

/// Extracts MFCC features from the rendered audio described by [config].
///
/// Audio is rendered as float stereo PCM directly; no WAV encode/decode round-trip.
Map<String, Object?> extractMfccPayload(GenerationConfig config) {
  final sampleRate = config.render.sampleRate;
  final windowLength = max(1, (sampleRate * 0.025).round());
  final windowStride = max(1, (sampleRate * 0.010).round());
  final fftSize = _nextPowerOfTwo(windowLength);
  const numFilters = 40;
  const numCoefs = 13;

  final stereo = Renderer.renderPcm(config);
  final totalSamples = stereo.left.length;

  if (totalSamples < windowLength) {
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

  // Mix stereo to mono directly in the float domain.
  final monoSignal = List<double>.generate(
    totalSamples,
    (i) => (stereo.left[i] + stereo.right[i]) * 0.5,
    growable: false,
  );

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

int _nextPowerOfTwo(int value) {
  var power = 1;
  while (power < value) {
    power <<= 1;
  }
  return power;
}
