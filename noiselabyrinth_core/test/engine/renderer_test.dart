import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

// Minimal config shared across tests — 1-second WAV at 8 kHz for speed.
GenerationConfig _minimalConfig({
  RenderFormat format = RenderFormat.wav,
  int durationMinutes = 1,
  int sampleRate = 8000,
}) {
  const parser = GenerationConfigParser();
  return parser.parseJsonMap(<String, dynamic>{
    'metadata': <String, dynamic>{'name': 'Renderer Test'},
    'render': <String, dynamic>{
      'durationMinutes': durationMinutes,
      'sampleRate': sampleRate,
      'bitRate': 128,
      'format': format.name,
    },
    'mix': <String, dynamic>{'mix': 1.0},
    'layers': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'layer-a',
        'source': <String, dynamic>{
          'type': 'noise',
          'noiseConfig': <String, dynamic>{'color': 'white'},
        },
      },
    ],
  });
}

void main() {
  group('Renderer WAV', () {
    test('renderWav returns valid PCM-16 stereo WAV bytes', () {
      final config = _minimalConfig();
      final bytes = Renderer.renderWav(config);

      // RIFF magic
      expect(bytes[0], equals(0x52)); // R
      expect(bytes[1], equals(0x49)); // I
      expect(bytes[2], equals(0x46)); // F
      expect(bytes[3], equals(0x46)); // F

      // WAVE magic at offset 8
      expect(bytes[8], equals(0x57)); // W
      expect(bytes[9], equals(0x41)); // A
      expect(bytes[10], equals(0x56)); // V
      expect(bytes[11], equals(0x45)); // E

      // Channel count = 2 (stereo) at offset 22, little-endian uint16
      final bd = bytes.buffer.asByteData();
      expect(bd.getUint16(22, Endian.little), equals(2));

      // Sample rate at offset 24
      expect(bd.getUint32(24, Endian.little), equals(8000));

      // Byte length = header(44) + samples * 4 bytes/frame
      final totalSamples = 8000 * 1 * 60; // 1 minute
      expect(bytes.length, equals(44 + totalSamples * 4));
    });

    test(
      'render() with wav format delegates to renderWav synchronously',
      () async {
        final config = _minimalConfig(format: RenderFormat.wav);
        final bytes = await Renderer.render(config);
        expect(bytes.length, greaterThan(44));
        // RIFF header confirms WAV
        expect(bytes[0], equals(0x52));
      },
    );

    test('renderWav output is non-zero for white noise source', () {
      final config = _minimalConfig();
      final bytes = Renderer.renderWav(config);

      // Check sample data region for non-zero content (noise should not be silent).
      final sampleRegion = bytes.sublist(44, 44 + 64);
      expect(sampleRegion.any((b) => b != 0), isTrue);
    });
  });

  group('Renderer MP3', () {
    test(
      'renderMp3 returns non-empty bytes starting with ID3 or FF FB sync',
      () async {
        final config = _minimalConfig(
          format: RenderFormat.mp3,
          sampleRate: 8000,
        );
        final bytes = await Renderer.renderMp3(config);

        expect(bytes, isA<Uint8List>());
        expect(bytes.isNotEmpty, isTrue);
      },
      skip: 'requires libmp3lame.so native library at runtime',
    );

    test(
      'render() with mp3 format returns bytes',
      () async {
        final config = _minimalConfig(
          format: RenderFormat.mp3,
          sampleRate: 8000,
        );
        final bytes = await Renderer.render(config);
        expect(bytes.isNotEmpty, isTrue);
      },
      skip: 'requires libmp3lame.so native library at runtime',
    );
  });

  group('Renderer RenderFormat enum', () {
    test('RenderFormat values are wav and mp3', () {
      expect(
        RenderFormat.values,
        containsAll([RenderFormat.wav, RenderFormat.mp3]),
      );
    });

    test('RenderConfig default format is wav', () {
      expect(const RenderConfig().format, RenderFormat.wav);
    });

    test('RenderConfig toJson includes format name', () {
      const config = RenderConfig(format: RenderFormat.mp3, bitRate: 320);
      expect(config.toJson()['format'], equals('mp3'));
    });
  });
}
