import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

// Minimal config shared across tests — 1-second WAV at 8 kHz for speed.
GenerationConfig _minimalConfig({
  RenderFormat format = RenderFormat.wav,
  int durationMinutes = 1,
  int sampleRate = 8000,
  bool dcBlockerEnabled = true,
  Map<String, dynamic>? source,
  List<Map<String, dynamic>>? processors,
  double layerGain = 1.0,
}) {
  final parser = GenerationConfigParser();
  return parser.parseJsonMap(<String, dynamic>{
    'metadata': <String, dynamic>{
      'name': 'Renderer Test',
      'description': '',
      'tags': <String>[],
    },
    'render': <String, dynamic>{
      'durationMinutes': durationMinutes,
      'sampleRate': sampleRate,
      'bitRate': 128,
      'format': format.name,
      'dcBlockerEnabled': dcBlockerEnabled,
    },
    'mix': <String, dynamic>{'mix': 1.0},
    'layers': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'layer-a',
        'gain': layerGain,
        'source':
            source ??
            <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{'color': 'white'},
            },
        'processors': ?processors,
      },
    ],
  });
}

double _meanPcmSample(Uint8List wavBytes) {
  final bd = wavBytes.buffer.asByteData();
  var sum = 0.0;
  var count = 0;
  for (var i = 44; i + 1 < wavBytes.length; i += 2) {
    sum += bd.getInt16(i, Endian.little) / 32767.0;
    count++;
  }
  return count == 0 ? 0.0 : sum / count;
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
      const totalSamples = 8000 * 1 * 60; // 1 minute
      expect(bytes.length, equals(44 + totalSamples * 4));
    });

    test('renderWav respects very low sample rate in header and size', () {
      final config = _minimalConfig(sampleRate: 64);
      final bytes = Renderer.renderWav(config);

      final bd = bytes.buffer.asByteData();
      const totalSamples = 64 * 60;
      expect(bd.getUint32(24, Endian.little), equals(64));
      expect(bd.getUint32(40, Endian.little), equals(totalSamples * 4));
      expect(bytes.length, equals(44 + totalSamples * 4));
    });

    test(
      'render() with wav format delegates to renderWav synchronously',
      () async {
        final config = _minimalConfig();
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

    test('renderWav clamps overdriven float samples to PCM-16 limits', () {
      final config = _minimalConfig(
        sampleRate: 128,
        source: <String, dynamic>{
          'type': 'sine',
          'sineConfig': <String, dynamic>{'frequencyHz': 32, 'phase': 0},
        },
        layerGain: 4,
      );

      final bytes = Renderer.renderWav(config);
      final bd = bytes.buffer.asByteData();

      var sawPositiveClip = false;
      var sawNegativeClip = false;

      for (var i = 44; i + 1 < bytes.length; i += 2) {
        final sample = bd.getInt16(i, Endian.little);
        if (sample == 32767) {
          sawPositiveClip = true;
        }
        if (sample == -32767) {
          sawNegativeClip = true;
        }
      }

      expect(sawPositiveClip, isTrue);
      expect(sawNegativeClip, isTrue);
    });

    test('render() wav path returns identical bytes as renderWav()', () async {
      final config = _minimalConfig(
        sampleRate: 256,
        source: <String, dynamic>{
          'type': 'sine',
          'sineConfig': <String, dynamic>{'frequencyHz': 64, 'phase': 0},
        },
      );

      final direct = Renderer.renderWav(config);
      final viaDispatch = await Renderer.render(config);

      expect(viaDispatch, orderedEquals(direct));
    });

    test('renderWav applies final-stage DC blocker by default', () {
      final withoutDcBlocker = Renderer.renderWav(
        _minimalConfig(
          sampleRate: 256,
          dcBlockerEnabled: false,
          source: <String, dynamic>{
            'type': 'impulse',
            'impulseConfig': <String, dynamic>{
              'density': 1.0,
              'randomness': 0.0,
            },
          },
        ),
      );
      final withDcBlocker = Renderer.renderWav(
        _minimalConfig(
          sampleRate: 256,
          source: <String, dynamic>{
            'type': 'impulse',
            'impulseConfig': <String, dynamic>{
              'density': 1.0,
              'randomness': 0.0,
            },
          },
        ),
      );

      final meanWithout = _meanPcmSample(withoutDcBlocker);
      final meanWith = _meanPcmSample(withDcBlocker);

      expect(meanWithout, greaterThan(0.9));
      expect(meanWith.abs(), lessThan(0.05));
    });
  });

  group('Renderer MP3', () {
    test(
      'render() with mp3 format returns bytes',
      () async {
        final config = _minimalConfig(
          format: RenderFormat.mp3,
        );
        final bytes = await Renderer.render(config);
        expect(bytes.isNotEmpty, isTrue);
      },
    );

    test('render() mp3 path does not return a WAV RIFF header', () async {
      final config = _minimalConfig(
        format: RenderFormat.mp3,
      );
      final bytes = await Renderer.render(config);

      if (bytes.length >= 4) {
        final isRiff = bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46;
        expect(isRiff, isFalse);
      }
    });
  });

  group('Renderer RenderFormat enum', () {
    test('RenderFormat values are wav and mp3', () {
      expect(
        RenderFormat.values,
        containsAll([RenderFormat.wav, RenderFormat.mp3]),
      );
    });

    test('RenderConfig default format is mp3', () {
      expect(const RenderConfig().format, RenderFormat.mp3);
    });

    test('RenderConfig enables DC blocker by default', () {
      expect(const RenderConfig().dcBlockerEnabled, isTrue);
    });

    test('RenderConfig toJson includes format name', () {
      const config = RenderConfig(format: RenderFormat.mp3, bitRate: 320);
      expect(config.toJson()['format'], equals('mp3'));
      expect(config.toJson()['dcBlockerEnabled'], isTrue);
    });
  });
}
