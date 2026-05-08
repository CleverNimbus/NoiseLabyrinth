import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

const _smokeTag = <String>['smoke'];
const _qualityTag = <String>['quality'];

void main() {
  group('audio engine', () {
    test(
      'AudioEngine allocates reusable per-layer buffer and optional scratch',
      () {
        final parser = GenerationConfigParser();
        const graphBuilder = RuntimeGraphBuilder();

        final config = parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Engine Patch'},
          'render': <String, dynamic>{
            'durationMinutes': 1,
            'sampleRate': 44100,
            'bitRate': 192,
          },
          'mix': <String, dynamic>{'mix': 1.0},
          'layers': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-a',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{
                  'frequencyHz': 220,
                  'phase': 0.0,
                },
              },
            },
          ],
        });

        final graph = graphBuilder.build(config);

        final engine = AudioEngine(
          graph: graph,
          sampleRate: 44100,
          blockSize: 128,
        );

        final first = engine.layerBuffers('layer-a').main;
        engine.processBlocks(2);
        final second = engine.layerBuffers('layer-a').main;

        expect(identical(first, second), isTrue);
        expect(engine.layerBuffers('layer-a').main.length, 128);
        expect(engine.layerBuffers('layer-a').left.length, 128);
        expect(engine.layerBuffers('layer-a').right.length, 128);
        expect(engine.layerBuffers('layer-a').scratch, isNull);

        final withScratch = AudioEngine(
          graph: graph,
          sampleRate: 44100,
          blockSize: 128,
          enableScratchBuffers: true,
        );

        expect(withScratch.layerBuffers('layer-a').scratch, isNotNull);
        expect(withScratch.layerBuffers('layer-a').scratch!.length, 128);
      },
      tags: _smokeTag,
    );

    test('AudioEngine loop runs stubs without crashing', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Engine Loop Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0.0},
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 1.0},
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 64,
        enableScratchBuffers: true,
      );

      expect(() => engine.processBlocks(10), returnsNormally);
      expect(engine.processedBlocks, 10);
    }, tags: _smokeTag);

    test('engine mixes layers into master buffer', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Mix Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 0.75},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 1.0,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
          },
          <String, dynamic>{
            'id': 'layer-b',
            'gain': 0.5,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 32,
      )..processBlocks(1);

      final layerA = engine.layerBuffers('layer-a').main;
      final layerB = engine.layerBuffers('layer-b').main;
      final master = engine.masterBuffer;
      final masterLeft = engine.masterLeftBuffer;
      final masterRight = engine.masterRightBuffer;

      for (var i = 0; i < master.length; i++) {
        final expected = 0.75 * (layerA[i] + (layerB[i] * 0.5));
        expect(master[i], closeTo(expected, 1e-6));
        expect(masterLeft[i], closeTo(expected, 1e-6));
        expect(masterRight[i], closeTo(expected, 1e-6));
      }
    }, tags: _qualityTag);

    test('engine applies optional master dithering when enabled', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final baseJson = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Dither Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
            },
          },
        ],
      };

      final noDitherConfig = parser.parseJsonMap(<String, dynamic>{
        ...baseJson,
        'mix': <String, dynamic>{'mix': 1.0},
      });
      final withDitherConfig = parser.parseJsonMap(<String, dynamic>{
        ...baseJson,
        'mix': <String, dynamic>{
          'mix': 1.0,
          'dither': <String, dynamic>{
            'enabled': true,
            'type': 'tpdf',
            'bitDepth': 16,
            'amount': 1.0,
          },
        },
      });

      final noDitherEngine = AudioEngine(
        graph: graphBuilder.build(noDitherConfig),
        sampleRate: 44100,
        blockSize: 64,
      )..processBlocks(1);

      final ditherEngineA = AudioEngine(
        graph: graphBuilder.build(withDitherConfig),
        sampleRate: 44100,
        blockSize: 64,
      )..processBlocks(1);

      final ditherEngineB = AudioEngine(
        graph: graphBuilder.build(withDitherConfig),
        sampleRate: 44100,
        blockSize: 64,
      )..processBlocks(1);

      var changedByDither = false;
      for (var i = 0; i < noDitherEngine.masterLeftBuffer.length; i++) {
        if ((noDitherEngine.masterLeftBuffer[i] - ditherEngineA.masterLeftBuffer[i]).abs() > 1e-9) {
          changedByDither = true;
          break;
        }
      }

      expect(changedByDither, isTrue);
      expect(ditherEngineA.masterLeftBuffer, orderedEquals(ditherEngineB.masterLeftBuffer));
      expect(ditherEngineA.masterRightBuffer, orderedEquals(ditherEngineB.masterRightBuffer));
    }, tags: _qualityTag);

    test('engine applies optional render normalization to target dBFS', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final baseJson = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Normalization Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 0.2,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
            },
          },
        ],
      };

      final noNormalizationConfig = parser.parseJsonMap(<String, dynamic>{
        ...baseJson,
        'mix': <String, dynamic>{'mix': 1.0},
      });
      final withNormalizationConfig = parser.parseJsonMap(<String, dynamic>{
        ...baseJson,
        'mix': <String, dynamic>{
          'mix': 1.0,
          'normalization': <String, dynamic>{
            'enabled': true,
            'targetDb': -6.0,
          },
        },
      });

      final noNormalizationEngine = AudioEngine(
        graph: graphBuilder.build(noNormalizationConfig),
        sampleRate: 44100,
        blockSize: 128,
      );
      final withNormalizationEngine = AudioEngine(
        graph: graphBuilder.build(withNormalizationConfig),
        sampleRate: 44100,
        blockSize: 128,
      );

      final withoutNormalization = noNormalizationEngine.renderStereoSamples(totalSamples: 4096);
      final withNormalization = withNormalizationEngine.renderStereoSamples(totalSamples: 4096);

      final rawPeak = withoutNormalization.left.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      final normalizedLeftPeak = withNormalization.left.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      final normalizedRightPeak = withNormalization.right.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
      final normalizedPeak = normalizedLeftPeak > normalizedRightPeak ? normalizedLeftPeak : normalizedRightPeak;

      final target = math.pow(10.0, -6.0 / 20.0).toDouble();
      expect(normalizedPeak, closeTo(target, 1e-6));
      expect((normalizedPeak - rawPeak).abs() > 1e-6, isTrue);
    });

    test('engine applies per-layer pan into stereo channels', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Pan Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'left-layer',
            'pan': -1.0,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
          },
          <String, dynamic>{
            'id': 'right-layer',
            'pan': 1.0,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 64,
      )..processBlocks(1);

      final leftLayer = engine.layerBuffers('left-layer');
      final rightLayer = engine.layerBuffers('right-layer');

      final leftLayerLeftEnergy = leftLayer.left.fold<double>(
        0,
        (sum, s) => sum + s.abs(),
      );
      final leftLayerLeak = leftLayer.right.fold<double>(
        0,
        (sum, s) => sum + s.abs(),
      );
      final rightLayerLeftLeak = rightLayer.left.fold<double>(
        0,
        (sum, s) => sum + s.abs(),
      );
      final rightLayerRightEnergy = rightLayer.right.fold<double>(
        0,
        (sum, s) => sum + s.abs(),
      );

      expect(leftLayer.left.any((sample) => sample != 0.0), isTrue);
      expect(leftLayerLeak, closeTo(0.0, 1e-9));
      expect(rightLayerLeftLeak, closeTo(0.0, 1e-9));
      expect(leftLayerLeftEnergy, greaterThan(0.0));
      expect(rightLayerRightEnergy, greaterThan(0.0));
    });

    test('engine master mix reads finalValue with update cycle', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Mix FinalValue Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 64,
      );

      graph.masterMix.baseValue = 0.0;
      graph.masterMix.update();
      engine.processBlocks(1);
      final silentPeak = engine.masterLeftBuffer.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
      expect(silentPeak, closeTo(0.0, 1e-9));

      graph.masterMix.baseValue = 1.0;
      graph.masterMix.update();
      engine.processBlocks(1);
      final audiblePeak = engine.masterRightBuffer.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
      expect(audiblePeak, greaterThan(0.0));
    });

    test('engine can render raw noise WAV bytes', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'WAV Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 0.8},
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 128,
      );

      final wav = engine.renderWavBytes(durationSeconds: 1);
      final header = ByteData.sublistView(wav, 0, 44);

      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(header.getUint16(22, Endian.little), 2); // stereo
      expect(header.getUint16(34, Endian.little), 16); // 16-bit pcm
      expect(header.getUint32(24, Endian.little), 44100);
      expect(wav.length, 44 + (44100 * 4));
    });

    test('engine renders filtered low-passed noise waveform', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Filtered Noise Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'lp-1',
                'type': 'biquad',
                'biquad': <String, dynamic>{
                  'biquadMode': 'lowpass',
                  'frequency': 400,
                  'q': 0.707,
                  'gainDb': 0.0,
                },
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 128,
      );

      final samples = engine.renderSamples(totalSamples: 2048);

      final allZero = samples.every((sample) => sample == 0.0);
      expect(allZero, isFalse);

      var peak = 0.0;
      for (final sample in samples) {
        final absValue = sample.abs();
        if (absValue > peak) {
          peak = absValue;
        }
      }

      expect(peak, lessThanOrEqualTo(1.0));
      expect(engine.processedBlocks, greaterThan(0));
      expect(peak, greaterThan(0.01));
    }, tags: _qualityTag);

    test('engine applies modulation per block and evolves filtered sound', () {
      final parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Moving Filter Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 20000},
              },
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'lp-1',
                'type': 'biquad',
                'biquad': <String, dynamic>{
                  'biquadMode': 'lowpass',
                  'frequency': 800,
                  'q': 0.707,
                  'gainDb': 0.0,
                },
              },
            ],
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'mod-lfo',
                'type': 'lfo',
                'amount': 250.0,
                'lfoConfig': <String, dynamic>{
                  'type': 'sine',
                  'frequency': 0.5,
                  'depth': 1.0,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[lp-1].biquad.frequency',
                    'amount': 1.0,
                  },
                ],
              },
              <String, dynamic>{
                'id': 'mod-random',
                'type': 'random',
                'amount': 0.15,
                'randomConfig': <String, dynamic>{
                  'rateHz': 2.0,
                  'smooth': 0.92,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].gain',
                    'amount': 1.0,
                  },
                ],
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(
        graph: graph,
        sampleRate: 44100,
        blockSize: 128,
      );

      final layer = graph.layers.single;
      final filter =
          layer.processors.singleWhere(
                (processor) => processor.id.endsWith('lp-1'),
              )
              as BiquadProcessorNode;
      final freqParam = filter.parameter('frequency')!;

      engine.processBlocks(1);
      final frequencyBlock1 = freqParam.finalValue;

      engine.processBlocks(1);
      final frequencyBlock2 = freqParam.finalValue;

      expect(frequencyBlock1, isNot(equals(frequencyBlock2)));
      expect((frequencyBlock2 - frequencyBlock1).abs(), greaterThan(1.0));

      final samples = engine.renderSamples(totalSamples: 4096);
      final allZero = samples.every((sample) => sample == 0.0);
      expect(allZero, isFalse);
    }, tags: _qualityTag);
  });
}
