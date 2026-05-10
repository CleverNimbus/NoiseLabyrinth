import 'dart:typed_data';

import 'package:flutter_lame/flutter_lame.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class Mp3Renderer {
  const Mp3Renderer();

  /// Renders [config] to MP3 bytes by consuming stereo float PCM chunks.
  Future<Uint8List> render(GenerationConfig config) async {
    final encoder = LameMp3Encoder(sampleRate: config.render.sampleRate, bitRate: config.render.bitRate);
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

  int _toPcm16(double sample) {
    final clamped = sample < -1.0 ? -1.0 : (sample > 1.0 ? 1.0 : sample);
    return (clamped * 32767.0).round();
  }
}
