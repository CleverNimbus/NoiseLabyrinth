import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

// Minimal config shared across tests — 1-minute run at 8 kHz for speed.
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

double _meanFloat32(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return count == 0 ? 0.0 : sum / count;
}

void main() {
  group('Renderer PCM', () {
    test('renderPcm returns StereoSamples with correct sample count', () {
      final config = _minimalConfig();
      final pcm = Renderer.renderPcm(config);

      const expectedSamples = 8000 * 1 * 60; // 1 minute
      expect(pcm.left.length, equals(expectedSamples));
      expect(pcm.right.length, equals(expectedSamples));
    });

    test('renderPcm respects very low sample rate in output length', () {
      final config = _minimalConfig(sampleRate: 64);
      final pcm = Renderer.renderPcm(config);

      const expectedSamples = 64 * 60;
      expect(pcm.left.length, equals(expectedSamples));
      expect(pcm.right.length, equals(expectedSamples));
    });

    test('renderPcm output is non-zero for white noise source', () {
      final config = _minimalConfig(sampleRate: 512, durationMinutes: 1);
      final pcm = Renderer.renderPcm(config);

      final firstLeft = pcm.left.take(64);
      expect(firstLeft.any((s) => s != 0.0), isTrue);
    });

    test('renderPcm preserves float headroom for overdriven sources', () {
      // In float PCM, overdriven samples are NOT hard-clipped to [-1.0, 1.0].
      // The consumer is responsible for clamping when converting to integer PCM.
      final config = _minimalConfig(
        sampleRate: 128,
        source: <String, dynamic>{
          'type': 'sine',
          'sineConfig': <String, dynamic>{'frequencyHz': 32, 'phase': 0},
        },
        layerGain: 4,
      );

      final pcm = Renderer.renderPcm(config);

      // A 4× overdriven sine should produce peaks well outside [-1.0, 1.0].
      expect(pcm.left.any((s) => s > 1.0 || s < -1.0), isTrue);
    });

    test('renderPcm applies final-stage DC blocker by default', () {
      final withoutDcBlocker = Renderer.renderPcm(
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
      final withDcBlocker = Renderer.renderPcm(
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

      final meanWithout = _meanFloat32(withoutDcBlocker.left);
      final meanWith = _meanFloat32(withDcBlocker.left);

      expect(meanWithout, greaterThan(0.9));
      expect(meanWith.abs(), lessThan(0.05));
    });

    test('renderPcmChunks total sample count matches renderPcm', () async {
      final config = _minimalConfig(sampleRate: 256);
      final expected = Renderer.renderPcm(config).left.length;

      var streamedSamples = 0;
      await for (final chunk in Renderer.renderPcmChunks(config)) {
        streamedSamples += chunk.left.length;
      }

      expect(streamedSamples, equals(expected));
    });

    test('renderPcmChunks produces samples identical to renderPcm', () async {
      final config = _minimalConfig(
        sampleRate: 256,
        source: <String, dynamic>{
          'type': 'sine',
          'sineConfig': <String, dynamic>{'frequencyHz': 64, 'phase': 0},
        },
      );

      final direct = Renderer.renderPcm(config);

      final leftFromChunks = <double>[];
      final rightFromChunks = <double>[];
      await for (final chunk in Renderer.renderPcmChunks(config)) {
        leftFromChunks.addAll(chunk.left);
        rightFromChunks.addAll(chunk.right);
      }

      expect(leftFromChunks, orderedEquals(direct.left));
      expect(rightFromChunks, orderedEquals(direct.right));
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
      expect(RenderConfig().format, RenderFormat.mp3);
    });

    test('RenderConfig enables DC blocker by default', () {
      expect(RenderConfig().dcBlockerEnabled, isTrue);
    });

    test('RenderConfig toJson includes format name', () {
      final config = RenderConfig(format: RenderFormat.mp3, bitRate: 320);
      expect(config.toJson()['format'], equals('mp3'));
      expect(config.toJson()['dcBlockerEnabled'], isTrue);
    });
  });
}
