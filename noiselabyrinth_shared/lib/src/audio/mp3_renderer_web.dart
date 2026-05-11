import 'dart:typed_data';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class Mp3Renderer {
  const Mp3Renderer();

  /// Web builds do not support MP3 rendering.
  /// Use native platforms (mobile/desktop) for audio export.
  Future<Uint8List> render(GenerationConfig config) async {
    throw UnsupportedError(
      'MP3 rendering is not supported on web. Use a native platform (iOS, Android, macOS, Windows, or Linux) to export audio.',
    );
  }
}
