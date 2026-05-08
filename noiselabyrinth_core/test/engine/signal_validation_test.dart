import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

const _qualityTag = <String>['quality'];

double _rms(Float32List data) {
  var sum = 0.0;
  for (final sample in data) {
    final v = sample;
    sum += v * v;
  }
  return math.sqrt(sum / data.length);
}

double _peakAbs(Float32List data) {
  var peak = 0.0;
  for (final sample in data) {
    peak = math.max(peak, sample.abs());
  }
  return peak;
}

double _binMagnitude(Float32List data, int bin) {
  var real = 0.0;
  var imag = 0.0;
  for (var i = 0; i < data.length; i++) {
    final phase = 2.0 * math.pi * bin * i / data.length;
    real += data[i] * math.cos(phase);
    imag -= data[i] * math.sin(phase);
  }
  return math.sqrt(real * real + imag * imag) / data.length;
}

void main() {
  group('signal validation', () {
    test('RMS sanity: sine source renders near 0.707 RMS', () {
      final parser = GenerationConfigParser();
      const builder = RuntimeGraphBuilder(sampleRate: 8000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'RMS Sine Validation'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 8000,
          'bitRate': 128,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'sine-layer',
            'gain': 1.0,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
            },
          },
        ],
      });

      final graph = builder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 8000,
        blockSize: 256,
      );
      final stereo = engine.renderStereoSamples(totalSamples: 8000);

      final leftRms = _rms(stereo.left);
      expect(leftRms, closeTo(0.707, 0.04));
      expect(_peakAbs(stereo.left), greaterThan(0.95));
    }, tags: _qualityTag);

    test('clipping detection identifies overs after high gain', () {
      final parser = GenerationConfigParser();
      const builder = RuntimeGraphBuilder(sampleRate: 8000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Clipping Validation'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 8000,
          'bitRate': 128,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'hot-layer',
            'gain': 1.0,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0.0},
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-hot',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 2.0},
              },
            ],
          },
        ],
      });

      final graph = builder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 8000,
        blockSize: 256,
      );
      final stereo = engine.renderStereoSamples(totalSamples: 4000);

      final clippedSamples = stereo.left.where((sample) => sample.abs() > 1.0).length;
      final clippedRatio = clippedSamples / stereo.left.length;
      expect(clippedSamples, greaterThan(0));
      expect(clippedRatio, greaterThan(0.2));
    }, tags: _qualityTag);

    test(
      'spectral sanity: low-pass chain attenuates high-frequency content',
      () {
        final parser = GenerationConfigParser();
        const builder = RuntimeGraphBuilder(sampleRate: 8000);

        final config = parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Spectral Validation'},
          'render': <String, dynamic>{
            'durationMinutes': 1,
            'sampleRate': 8000,
            'bitRate': 128,
          },
          'mix': <String, dynamic>{'mix': 1.0},
          'layers': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'noise-layer',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
              'processors': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'lp-1',
                  'type': 'biquad',
                  'biquad': <String, dynamic>{
                    'biquadMode': 'lowpass',
                    'frequency': 350,
                    'q': 0.707,
                    'gainDb': 0.0,
                  },
                },
              ],
            },
          ],
        });

        final graph = builder.build(config);
        final engine = AudioEngine(
          graph: graph,
          sampleRate: 8000,
          blockSize: 256,
        );
        final mono = engine.renderSamples(totalSamples: 2048);

        final lowBin = (200 * 2048 / 8000).round();
        final highBin = (2200 * 2048 / 8000).round();
        final lowMag = _binMagnitude(mono, lowBin);
        final highMag = _binMagnitude(mono, highBin);

        expect(lowMag, greaterThan(0.005));
        expect(highMag, lessThan(lowMag * 0.35));
      },
      tags: _qualityTag,
    );

    test(
      'feature coverage: canonical paths with drift and random events execute',
      () {
        final parser = GenerationConfigParser();
        const builder = RuntimeGraphBuilder(sampleRate: 1000);

        final config = parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Feature Coverage Validation'},
          'render': <String, dynamic>{
            'durationMinutes': 1,
            'sampleRate': 1000,
            'bitRate': 128,
          },
          'mix': <String, dynamic>{'mix': 1.0},
          'layers': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-a',
              'gain': 0.2,
              'pan': 0.0,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'bandlimited',
                  'band': <String, dynamic>{'low': 60, 'high': 350},
                },
              },
              'processors': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'gain-1',
                  'type': 'gain',
                  'gain': <String, dynamic>{'gain': 0.8},
                },
              ],
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'drift-1',
                  'type': 'drift',
                  'amount': 1.0,
                  'driftConfig': <String, dynamic>{'speed': 30.0, 'range': 0.3},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': 'layers[layer-a].pan',
                      'amount': 1.0,
                    },
                  ],
                },
                <String, dynamic>{
                  'id': 'burst-1',
                  'type': 'burst',
                  'amount': 1.0,
                  'burstConfig': <String, dynamic>{
                    'durationMs': 30,
                    'intensity': 1.0,
                    'randomness': 0.2,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': 'layers[layer-a].gain',
                      'amount': 1.0,
                    },
                  ],
                },
              ],
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'evt-random',
                  'trigger': <String, dynamic>{'type': 'random', 'rate': 80.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'modulatorId': 'burst-1',
                      'mode': 'trigger',
                    },
                  ],
                },
              ],
            },
          ],
        });

        final graph = builder.build(config);
        final engine = AudioEngine(
          graph: graph,
          sampleRate: 1000,
          blockSize: 10,
        );

        final panValues = <double>[];
        final gainValues = <double>[];
        for (var i = 0; i < 50; i++) {
          engine.processBlocks(1);
          panValues.add(graph.layers.single.pan.finalValue);
          gainValues.add(graph.layers.single.gain.finalValue);
        }

        final panSpread = panValues.reduce((a, b) => a > b ? a : b) - panValues.reduce((a, b) => a < b ? a : b);
        final gainPeak = gainValues.reduce((a, b) => a > b ? a : b);

        expect(panSpread, greaterThan(0.15));
        expect(gainPeak, greaterThan(0.35));
      },
      tags: _qualityTag,
    );

    test('multiplicative target mode respects min/max clamps', () {
      final parser = GenerationConfigParser();
      const builder = RuntimeGraphBuilder(sampleRate: 1000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Target Strategy Validation'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 1000,
          'bitRate': 128,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 400},
              },
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 0.5},
              },
            ],
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'burst-1',
                'type': 'burst',
                'amount': 1.5,
                'burstConfig': <String, dynamic>{
                  'durationMs': 30,
                  'intensity': 1.0,
                  'randomness': 0.0,
                  'attackMs': 0,
                  'releaseMs': 30,
                  'clusterMin': 2,
                  'clusterMax': 2,
                  'clusterSpreadMs': 10,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[gain-1].gain.gain',
                    'amount': 1.0,
                    'mode': 'multiplicative',
                    'minValue': 0.0,
                    'maxValue': 1.0,
                  },
                ],
              },
            ],
            'events': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'evt-random',
                'trigger': <String, dynamic>{'type': 'periodic', 'rate': 40.0},
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'modulatorId': 'burst-1',
                    'mode': 'trigger',
                  },
                ],
              },
            ],
          },
        ],
      });

      final graph = builder.build(config);
      final engine = AudioEngine(graph: graph, sampleRate: 1000, blockSize: 10);

      final gainParam = (graph.layers.single.processors.single as GainProcessorNode).parameter('gain')!;
      final observed = <double>[];

      for (var i = 0; i < 40; i++) {
        engine.processBlocks(1);
        observed.add(gainParam.finalValue);
      }

      final minGain = observed.reduce((a, b) => a < b ? a : b);
      final maxGain = observed.reduce((a, b) => a > b ? a : b);
      expect(minGain, greaterThanOrEqualTo(0.0));
      expect(maxGain, lessThanOrEqualTo(1.0));
      expect(maxGain, greaterThan(0.5));
    }, tags: _qualityTag);
  });
}
