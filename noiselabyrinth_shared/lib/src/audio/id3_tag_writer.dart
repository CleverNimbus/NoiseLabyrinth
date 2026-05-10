import 'dart:convert';
import 'dart:io';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:phonic/phonic.dart';

class Id3TagWriter {
  const Id3TagWriter();

  Future<bool> writeTags(
    String outputPath,
    GenerationConfig config, {
    required Duration generationDuration,
    required Map<String, Object?> mfccPayload,
    String artist = 'NoiseLabyrinth',
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
        ..setTag(ArtistTag(artist))
        ..setTag(GenreTag(config.metadata.tags));

      final updatedBytes = await audioFile.encode();
      await File(outputPath).writeAsBytes(updatedBytes, flush: true);
      return true;
    } finally {
      audioFile.dispose();
    }
  }
}
