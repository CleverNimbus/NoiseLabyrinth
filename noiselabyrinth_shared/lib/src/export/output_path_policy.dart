import 'dart:io';

import 'package:path/path.dart' as p;

class OutputPathPolicy {
  const OutputPathPolicy();

  Directory userMusicDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory(p.join(home, 'Música'));
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return Directory(p.join(userProfile, 'Música'));
    }

    return Directory.current;
  }

  String timestampForFilename(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}'
        '${two(local.month)}'
        '${two(local.day)}_'
        '${two(local.hour)}'
        '${two(local.minute)}'
        '${two(local.second)}';
  }

  String outputFilename(int menuNumber, DateTime dateTime) {
    return '${menuNumber}_${timestampForFilename(dateTime)}.mp3';
  }

  String outputPath(int menuNumber, DateTime dateTime) {
    final directory = userMusicDirectory();
    return p.join(directory.path, outputFilename(menuNumber, dateTime));
  }
}
