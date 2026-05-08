import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/engine/modulators/adsr_envelope_modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/burst_modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator_factory.dart';
import 'package:noiselabyrinth_core/engine/modulators/smooth_random_modulator.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
  group('configuration models', () {
    test('MetadataConfig serializes and deserializes safely', () {
      const config = MetadataConfig(
        name: 'Patch A',
        description: 'Test patch',
        tags: <String>['alpha', 'noise'],
        version: 2,
      );

      final restored = MetadataConfig.fromJson(config.toJson());

      expect(restored.name, 'Patch A');
      expect(restored.description, 'Test patch');
      expect(restored.tags, <String>['alpha', 'noise']);
      expect(restored.version, 2);
    });

    test('RenderConfig serializes and deserializes with defaults', () {
      final restored = RenderConfig.fromJson(<String, dynamic>{});
      expect(restored.durationMinutes, 120);
      expect(restored.sampleRate, 44100);
      expect(restored.bitRate, 192);

      expect(
        const RenderConfig(
          durationMinutes: 10,
          sampleRate: 48000,
          bitRate: 256,
        ).toJson(),
        <String, dynamic>{
          'durationMinutes': 10,
          'sampleRate': 48000,
          'bitRate': 256,
          'format': 'mp3',
        },
      );
    });

    test('ModulationConfig serializes enum name with canonical fields', () {
      const config = ModulationConfig(
        id: 'mod-1',
        type: ModulationType.drift,
        amount: 12,
        targets: <ModulationTargetConfig>[
          ModulationTargetConfig(
            path: 'layers[layer-a].processors[gain-1].gain',
            amount: 0.5,
            mode: ModulationApplyMode.multiplicative,
            minValue: 0,
            maxValue: 1,
          ),
        ],
      );

      final restored = ModulationConfig.fromJson(config.toJson());
      expect(restored.id, 'mod-1');
      expect(restored.type, ModulationType.drift);
      expect(restored.amount, 12);
      expect(
        restored.targets.single.path,
        'layers[layer-a].processors[gain-1].gain',
      );
      expect(restored.targets.single.amount, 0.5);
      expect(restored.targets.single.mode, ModulationApplyMode.multiplicative);
      expect(restored.targets.single.minValue, 0.0);
      expect(restored.targets.single.maxValue, 1.0);

      final fallback = ModulationConfig.fromJson(<String, dynamic>{
        'id': 'mod-2',
        'type': 'not-a-real-type',
      });
      expect(fallback.type, ModulationType.lfo);
      expect(fallback.amount, 0);

      final legacyRandom = ModulationConfig.fromJson(<String, dynamic>{
        'id': 'mod-3',
        'type': 'randomWalk',
        'amount': 2,
        'randomWalkConfig': <String, dynamic>{'rateHz': 2, 'smooth': 0.25},
      });
      expect(legacyRandom.type, ModulationType.lfo);
      expect(legacyRandom.randomConfig, isNull);

      final burst = ModulationConfig.fromJson(<String, dynamic>{
        'id': 'mod-burst',
        'type': 'burst',
        'burstConfig': <String, dynamic>{
          'durationMs': 90,
          'intensity': 0.8,
          'randomness': 0.3,
        },
      });
      expect(burst.burstConfig?.durationMs, 90);
      expect(burst.burstConfig?.intensity, closeTo(0.8, 1e-9));
      expect(burst.burstConfig?.randomness, closeTo(0.3, 1e-9));
      expect(burst.burstConfig?.clusterMin, 1);
      expect(burst.burstConfig?.clusterMax, 1);

      final legacyBurst = ModulationConfig.fromJson(<String, dynamic>{
        'id': 'mod-burst-legacy',
        'type': 'amplitudeMod',
        'burstConfig': <String, dynamic>{'density': 0.6, 'randomness': 0.25},
      });
      expect(legacyBurst.type, ModulationType.lfo);
      expect(legacyBurst.burstConfig?.intensity, closeTo(1.0, 1e-9));
      expect(legacyBurst.burstConfig?.durationMs, 120);
    });

    test('EventConfig serializes enum names safely', () {
      const config = EventConfig(
        id: 'event-1',
        trigger: TriggerConfig(type: TriggerType.poisson, rate: 0.75),
        actions: <ActionConfig>[
          ActionConfig(modulatorId: 'mod-1', mode: ActionMode.gate),
        ],
      );

      final restored = EventConfig.fromJson(config.toJson());

      expect(restored.trigger.type, TriggerType.poisson);
      expect(restored.trigger.rate, closeTo(0.75, 1e-9));
      expect(restored.actions.single.mode, ActionMode.gate);
    });

    test('ProcessorConfig gain serializes and deserializes safely', () {
      const config = ProcessorConfig(
        id: 'gain-1',
        type: ProcessorType.gain,
        gain: GainConfig(gain: 0.75),
      );

      final restored = ProcessorConfig.fromJson(config.toJson());
      expect(restored.id, 'gain-1');
      expect(restored.type, ProcessorType.gain);
      expect(restored.gain, isNotNull);
      expect(restored.gain!.gain, closeTo(0.75, 1e-9));
    });

    test('GenerationConfigParser parses and validates a valid config tree', () {
      const parser = GenerationConfigParser();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Valid Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 5,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 0.8},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 1.0,
            'pan': 0.0,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0.0},
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 1.1},
              },
            ],
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'mod-1',
                'type': 'lfo',
                'amount': 0.5,
                'lfoConfig': <String, dynamic>{
                  'type': 'sine',
                  'frequency': 0.5,
                  'depth': 1.0,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[gain-1].gain.gain',
                    'amount': 1.0,
                  },
                ],
              },
            ],
            'events': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'event-1',
                'trigger': <String, dynamic>{'type': 'periodic', 'rate': 0.5},
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{'modulatorId': 'mod-1', 'mode': 'trigger'},
                ],
              },
            ],
          },
        ],
      });

      expect(config.metadata.name, 'Valid Patch');
      expect(config.layers.single.modulations.single.id, 'mod-1');
    });

    test(
      'GenerationConfigParser rejects invalid ranges and missing required fields',
      () {
        const parser = GenerationConfigParser();

        expect(
          () => parser.parseJsonMap(<String, dynamic>{
            'metadata': <String, dynamic>{'name': ''},
            'render': <String, dynamic>{
              'durationMinutes': 0,
              'sampleRate': 0,
              'bitRate': 0,
            },
            'mix': <String, dynamic>{'mix': 2.0},
            'layers': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '',
                'gain': -1.0,
                'pan': 2.0,
                'source': <String, dynamic>{
                  'type': 'sine',
                  'sineConfig': <String, dynamic>{'frequencyHz': 0},
                },
              },
            ],
          }),
          throwsA(
            isA<ConfigValidationException>().having(
              (error) => error.issues.length,
              'issues.length',
              greaterThan(0),
            ),
          ),
        );
      },
    );

    test(
      'GenerationConfigParser rejects unknown modulation target references',
      () {
        const parser = GenerationConfigParser();

        expect(
          () => parser.parseJsonMap(<String, dynamic>{
            'metadata': <String, dynamic>{'name': 'Patch'},
            'render': <String, dynamic>{
              'durationMinutes': 5,
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
                    'band': <String, dynamic>{'low': 20, 'high': 18000},
                  },
                },
                'modulations': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'mod-1',
                    'type': 'random',
                    'randomConfig': <String, dynamic>{
                      'rateHz': 1.0,
                      'smooth': 0.5,
                    },
                    'targets': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'path': 'layers[layer-a].processors[missing].gain.gain',
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          throwsA(
            isA<ConfigValidationException>().having(
              (error) => error.issues.any((issue) => issue.path.endsWith('.path')),
              'path issue',
              isTrue,
            ),
          ),
        );
      },
    );

    test('GenerationConfigParser rejects non-finite gain processor values', () {
      const parser = GenerationConfigParser();

      expect(
        () => parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Invalid Gain Patch'},
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
                  'gain': <String, dynamic>{'gain': double.nan},
                },
              ],
            },
          ],
        }),
        throwsA(
          isA<ConfigValidationException>().having(
            (error) => error.issues.any((issue) => issue.path.endsWith('.gain.gain')),
            'gain issue',
            isTrue,
          ),
        ),
      );
    });
  });

  group('parameter models', () {
    test('Parameter applies modulation per block and resets accumulator', () {
      final parameter = Parameter(0.5);
      expect(parameter.finalValue, 0.5);

      parameter
        ..modulationValue = 0.25
        ..update();
      expect(parameter.finalValue, closeTo(0.75, 1e-9));
      expect(parameter.modulationValue, 0.0);
    });

    test('SmoothedParameter clamps smoothing and interpolates', () {
      final smoothed = SmoothedParameter(0, 2)
        ..target = 1.0
        ..update();

      expect(smoothed.smoothing, 1.0);
      expect(smoothed.current, closeTo(1.0, 1e-9));
    });
  });

  group('runtime graph builder', () {
    test('builds a wired layer graph with wrapped parameters', () {
      const parser = GenerationConfigParser();
      const builder = RuntimeGraphBuilder();

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Graph Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 3,
          'sampleRate': 44100,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 0.9},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 0.8,
            'pan': -0.2,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0.1},
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 1.2},
              },
              <String, dynamic>{
                'id': 'delay-1',
                'type': 'delay',
                'delay': <String, dynamic>{
                  'delayTimeMs': 120,
                  'feedback': 0.3,
                  'mix': 0.25,
                },
              },
            ],
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'mod-1',
                'type': 'lfo',
                'amount': 1.0,
                'lfoConfig': <String, dynamic>{
                  'type': 'sine',
                  'frequency': 1.0,
                  'depth': 1.0,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[gain-1].gain.gain',
                    'amount': 0.5,
                  },
                ],
              },
            ],
          },
        ],
      });

      final runtime = builder.build(config);

      expect(runtime.layers.length, 1);

      final layer = runtime.layers.single;
      expect(layer.id, 'layer-a');
      expect(layer.source, isA<SineSourceNode>());
      expect(layer.processors.length, 2);
      expect(layer.processors.first.inputNodeId, 'layer-a.source');
      expect(layer.processors.last.inputNodeId, 'layer-a.gain-1');
      expect(layer.outputNodeId, 'layer-a.delay-1');

      expect(layer.gain, isA<Parameter>());
      expect(layer.pan, isA<Parameter>());
      expect(layer.gain.baseValue, closeTo(0.8, 1e-9));
      expect(layer.pan.baseValue, closeTo(-0.2, 1e-9));

      final byNode = runtime.resolveNodeParameter('layer-a.gain-1', 'gain');
      expect(byNode, isNotNull);
      expect(byNode!.parameter.baseValue, closeTo(1.2, 1e-9));

      final byPath = runtime.resolvePath(
        'layers[layer-a].processors[gain-1].gain.gain',
      );
      expect(byPath, isNotNull);
      expect(identical(byNode.parameter, byPath!.parameter), isTrue);

      expect(layer.resolvedModulationTargets.length, 1);
      expect(layer.resolvedModulationTargets.single.modulationId, 'mod-1');
      expect(
        identical(
          layer.resolvedModulationTargets.single.reference.parameter,
          byNode.parameter,
        ),
        isTrue,
      );
    });

    test('throws when runtime target path cannot be resolved', () {
      const builder = RuntimeGraphBuilder();

      final config = GenerationConfig.fromJson(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Invalid Runtime Patch'},
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
              'sineConfig': <String, dynamic>{'frequencyHz': 220},
            },
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'mod-1',
                'type': 'lfo',
                'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[missing].gain.gain',
                  },
                ],
              },
            ],
          },
        ],
      });

      expect(() => builder.build(config), throwsStateError);
    });
  });

  group('core dsp infrastructure', () {
    test('AudioNode base classes prepare and keep parameters', () {
      final source = SineSourceNode(
        id: 'source-1',
        frequencyHz: 220,
        phase: 0,
      );
      final processor = GainProcessorNode(id: 'proc-1', gain: 1);

      source.prepare(48000, 256);
      processor.prepare(48000, 256);

      expect(source.sampleRate, 48000);
      expect(source.blockSize, 256);
      expect(processor.sampleRate, 48000);
      expect(processor.blockSize, 256);
      expect(source.parameter('frequencyHz'), isA<Parameter>());
      expect(processor.parameter('gain'), isA<Parameter>());
    });

    test(
      'AudioEngine allocates reusable per-layer buffer and optional scratch',
      () {
        const parser = GenerationConfigParser();
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
    );

    test('AudioEngine loop runs stubs without crashing', () {
      const parser = GenerationConfigParser();
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
    });

    test('white noise source produces non-silent samples', () {
      final source = NoiseSourceNode(
        id: 'noise-source',
        color: NoiseColor.white,
        low: 20,
        high: 20000,
      )..prepare(44100, 64);
      for (final parameter in source.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(64);
      source.process(buffer);

      final allZero = buffer.every((sample) => sample == 0.0);
      expect(allZero, isFalse);

      final first = buffer.first;
      final allEqual = buffer.every((sample) => sample == first);
      expect(allEqual, isFalse);
    });

    test('pink and brown noise sources produce valid non-silent buffers', () {
      final pink = NoiseSourceNode(
        id: 'pink-source',
        color: NoiseColor.pink,
        low: 20,
        high: 20000,
      );
      final brown = NoiseSourceNode(
        id: 'brown-source',
        color: NoiseColor.brown,
        low: 20,
        high: 20000,
      );

      pink.prepare(44100, 256);
      brown.prepare(44100, 256);
      for (final parameter in pink.parameters.values) {
        parameter.update();
      }
      for (final parameter in brown.parameters.values) {
        parameter.update();
      }

      final pinkBuffer = Float32List(256);
      final brownBuffer = Float32List(256);
      pink.process(pinkBuffer);
      brown.process(brownBuffer);

      expect(pinkBuffer.every((sample) => sample == 0.0), isFalse);
      expect(brownBuffer.every((sample) => sample == 0.0), isFalse);

      for (final sample in pinkBuffer) {
        expect(sample, greaterThanOrEqualTo(-1.0));
        expect(sample, lessThanOrEqualTo(1.0));
      }
      for (final sample in brownBuffer) {
        expect(sample, greaterThanOrEqualTo(-1.0));
        expect(sample, lessThanOrEqualTo(1.0));
      }
    });

    test('pink and brown are temporally smoother than white noise', () {
      final white = NoiseSourceNode(
        id: 'white-compare',
        color: NoiseColor.white,
        low: 20,
        high: 20000,
      );
      final pink = NoiseSourceNode(
        id: 'pink-compare',
        color: NoiseColor.pink,
        low: 20,
        high: 20000,
      );
      final brown = NoiseSourceNode(
        id: 'brown-compare',
        color: NoiseColor.brown,
        low: 20,
        high: 20000,
      );

      white.prepare(44100, 1024);
      pink.prepare(44100, 1024);
      brown.prepare(44100, 1024);
      for (final parameter in white.parameters.values) {
        parameter.update();
      }
      for (final parameter in pink.parameters.values) {
        parameter.update();
      }
      for (final parameter in brown.parameters.values) {
        parameter.update();
      }

      final whiteBuffer = Float32List(1024);
      final pinkBuffer = Float32List(1024);
      final brownBuffer = Float32List(1024);

      white.process(whiteBuffer);
      pink.process(pinkBuffer);
      brown.process(brownBuffer);

      double averageDelta(Float32List buffer) {
        var sum = 0.0;
        for (var i = 1; i < buffer.length; i++) {
          sum += (buffer[i] - buffer[i - 1]).abs();
        }
        return sum / (buffer.length - 1);
      }

      final whiteDelta = averageDelta(whiteBuffer);
      final pinkDelta = averageDelta(pinkBuffer);
      final brownDelta = averageDelta(brownBuffer);

      expect(pinkDelta, lessThan(whiteDelta));
      expect(brownDelta, lessThan(whiteDelta));
    });

    test('impulse source generates sparse clicks', () {
      final impulse = ImpulseSourceNode(
        id: 'impulse-sparse',
        density: 0.01,
        randomness: 0,
      )..prepare(44100, 1024);
      for (final parameter in impulse.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(1024);
      impulse.process(buffer);

      var nonZeroCount = 0;
      for (final sample in buffer) {
        if (sample != 0.0) {
          nonZeroCount++;
        }
      }

      expect(nonZeroCount, greaterThan(0));
      expect(nonZeroCount, lessThan(80));
    });

    test('impulse source supports amplitude variation', () {
      final impulse = ImpulseSourceNode(
        id: 'impulse-randomness',
        density: 1,
        randomness: 0.8,
      )..prepare(44100, 256);
      for (final parameter in impulse.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(256);
      impulse.process(buffer);

      final allOne = buffer.every((sample) => (sample - 1.0).abs() < 1e-9);
      expect(allOne, isFalse);

      for (final sample in buffer) {
        expect(sample, greaterThan(0.19));
        expect(sample, lessThanOrEqualTo(1.0));
      }
    });

    test('gain processor scales buffer samples', () {
      final gain = GainProcessorNode(id: 'gain-node', gain: 0.5)..prepare(44100, 4);
      for (final parameter in gain.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List.fromList(<double>[1, -1, 0.5, -0.25]);
      gain.process(buffer);

      expect(buffer[0], closeTo(0.5, 1e-9));
      expect(buffer[1], closeTo(-0.5, 1e-9));
      expect(buffer[2], closeTo(0.25, 1e-9));
      expect(buffer[3], closeTo(-0.125, 1e-9));
    });

    test('gain processor supports negative gain for polarity inversion', () {
      final gain = GainProcessorNode(id: 'gain-invert', gain: -1)..prepare(44100, 3);
      for (final parameter in gain.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List.fromList(<double>[0.3, -0.5, 1]);
      gain.process(buffer);

      expect(buffer[0], closeTo(-0.3, 1e-6));
      expect(buffer[1], closeTo(0.5, 1e-6));
      expect(buffer[2], closeTo(-1.0, 1e-6));
    });

    test('gain processor guards against non-finite finalValue', () {
      final gain = GainProcessorNode(id: 'gain-safe', gain: 1)..prepare(44100, 4);

      gain.parameter('gain')!.baseValue = double.nan;
      gain.parameter('gain')!.update();

      final buffer = Float32List.fromList(<double>[1, -1, 0.5, -0.5]);
      gain.process(buffer);

      // Smoothed gain moves gradually toward the safety fallback target.
      for (final sample in buffer) {
        expect(sample.isFinite, isTrue);
        expect(sample.abs(), lessThanOrEqualTo(1.0));
      }

      for (var i = 0; i < 30; i++) {
        final decay = Float32List.fromList(<double>[1]);
        gain.process(decay);
      }

      final settled = Float32List.fromList(<double>[1]);
      gain.process(settled);
      expect(settled[0], lessThan(0.01));
    });

    test('gain processor reads finalValue and requires update cycle', () {
      final gain = GainProcessorNode(id: 'gain-cycle', gain: 1)..prepare(44100, 2);
      gain.parameter('gain')!.update(); // finalValue = 1.0

      gain.parameter('gain')!.baseValue = 0.25;
      final noUpdate = Float32List.fromList(<double>[1, 1]);
      gain.process(noUpdate);
      expect(noUpdate[0], closeTo(1.0, 1e-9));

      gain.parameter('gain')!.update(); // finalValue now reflects baseValue
      final updated = Float32List.fromList(<double>[1, 1]);
      gain.process(updated);
      expect(updated[0], lessThan(1.0));
      expect(updated[0], greaterThan(0.25));
    });

    test('gain smoothing eases abrupt target changes', () {
      final gain = GainProcessorNode(id: 'gain-smoothing', gain: 1)..prepare(44100, 1);
      gain.parameter('gain')!.update();

      final first = Float32List.fromList(<double>[1]);
      gain.process(first);
      expect(first[0], closeTo(1.0, 1e-9));

      gain.parameter('gain')!.baseValue = 0.0;
      gain.parameter('gain')!.update();

      final second = Float32List.fromList(<double>[1]);
      gain.process(second);
      expect(second[0], greaterThan(0.0));
      expect(second[0], lessThan(1.0));
      expect(gain.smoothedGain, closeTo(second[0], 1e-6));
    });

    test('low-pass biquad attenuates fast alternating signal', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-lp',
        mode: BiquadMode.lowpass,
        frequency: 300,
        q: 0.707,
        gainDb: 0,
      )..prepare(44100, 128);
      for (final parameter in biquad.parameters.values) {
        parameter.update();
      }

      final input = Float32List(128);
      for (var i = 0; i < input.length; i++) {
        input[i] = i.isEven ? 1.0 : -1.0;
      }

      biquad.process(input);

      var sumAbs = 0.0;
      for (final sample in input) {
        sumAbs += sample.abs();
      }
      final averageAbs = sumAbs / input.length;

      expect(averageAbs, lessThan(0.6));
      expect(biquad.coefficientUpdateCount, 1);
    });

    test('biquad updates coefficients only when frequency or q changes', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-cache',
        mode: BiquadMode.lowpass,
        frequency: 1000,
        q: 0.8,
        gainDb: 0,
      )..prepare(44100, 32);
      for (final parameter in biquad.parameters.values) {
        parameter.update();
      }

      final bufferA = Float32List(32);
      biquad.process(bufferA);
      final afterFirstProcess = biquad.coefficientUpdateCount;

      final bufferB = Float32List(32);
      biquad.process(bufferB);
      final afterSecondProcess = biquad.coefficientUpdateCount;

      expect(afterFirstProcess, 1);
      expect(afterSecondProcess, afterFirstProcess);

      biquad.parameter('frequency')!.baseValue = 500.0;
      biquad.parameter('frequency')!.update();

      final bufferC = Float32List(32);
      biquad.process(bufferC);

      expect(biquad.coefficientUpdateCount, afterSecondProcess + 1);
    });

    test('biquad reads frequency from finalValue after update cycle', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-final',
        mode: BiquadMode.lowpass,
        frequency: 1200,
        q: 0.707,
        gainDb: 0,
      )..prepare(44100, 16);
      biquad.parameter('frequency')!.update();
      biquad.parameter('q')!.update();
      biquad.parameter('gainDb')!.update();

      biquad.process(Float32List(16));
      final initialUpdates = biquad.coefficientUpdateCount;

      biquad.parameter('frequency')!.baseValue = 500.0;
      biquad.process(Float32List(16));
      expect(biquad.coefficientUpdateCount, initialUpdates);
      expect(biquad.smoothedFrequency, greaterThan(500.0));

      biquad.parameter('frequency')!.update();
      biquad.process(Float32List(16));
      expect(biquad.coefficientUpdateCount, initialUpdates + 1);
      expect(biquad.smoothedFrequency, lessThan(1200.0));
      expect(biquad.smoothedFrequency, greaterThan(500.0));
    });

    test('engine mixes layers into master buffer', () {
      const parser = GenerationConfigParser();
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

      for (var i = 0; i < master.length; i++) {
        final expected = 0.75 * (layerA[i] + (layerB[i] * 0.5));
        expect(master[i], closeTo(expected, 1e-6));
      }
    });

    test('engine master mix reads finalValue with update cycle', () {
      const parser = GenerationConfigParser();
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
      final silentPeak = engine.masterBuffer.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
      expect(silentPeak, closeTo(0.0, 1e-9));

      graph.masterMix.baseValue = 1.0;
      graph.masterMix.update();
      engine.processBlocks(1);
      final audiblePeak = engine.masterBuffer.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
      expect(audiblePeak, greaterThan(0.0));
    });

    test('engine can render raw noise WAV bytes', () {
      const parser = GenerationConfigParser();
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
      const parser = GenerationConfigParser();
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
    });

    test(
      'LfoSineModulator fills control buffer through Modulator interface',
      () {
        final Modulator modulator = LfoSineModulator(
          sampleRate: 44100,
          frequency: 2,
          depth: 1,
        );

        final buffer = Float32List(64);
        modulator.process(64, buffer);

        final allZero = buffer.every((sample) => sample == 0.0);
        expect(allZero, isFalse);
      },
    );

    test(
      'SmoothRandomModulator produces smooth, non-constant control values',
      () {
        final random = SmoothRandomModulator(
          sampleRate: 44100,
          rateHz: 3,
          smooth: 0.95,
        );

        final buffer = Float32List(256);
        random.process(256, buffer);

        final allEqual = buffer.every((sample) => sample == buffer.first);
        expect(allEqual, isFalse);

        var maxDelta = 0.0;
        for (var i = 1; i < buffer.length; i++) {
          final delta = (buffer[i] - buffer[i - 1]).abs();
          if (delta > maxDelta) {
            maxDelta = delta;
          }
        }
        expect(maxDelta, lessThan(0.5));
      },
    );

    test('AdsrEnvelopeModulator follows ADSR shape and reset', () {
      final envelope = AdsrEnvelopeModulator(
        sampleRate: 1000,
        attackMs: 10,
        decayMs: 20,
        sustain: 0.4,
        releaseMs: 30,
      );

      final idle = Float32List(10);
      envelope.process(10, idle);
      expect(idle.every((sample) => sample == 0.0), isTrue);

      envelope.trigger();
      final attackDecay = Float32List(40);
      envelope.process(40, attackDecay);

      expect(attackDecay[5], greaterThan(0.3));
      expect(attackDecay[10], greaterThan(0.8));
      expect(attackDecay.last, closeTo(0.4, 0.08));

      envelope.reset();
      final released = Float32List(40);
      envelope.process(40, released);
      expect(released.last, closeTo(0.0, 1e-6));
    });

    test('engine events can trigger envelope modulation on layer gain', () {
      const parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder(sampleRate: 1000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Envelope Event Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 1000,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 0.0,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 400},
              },
            },
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'env-1',
                'type': 'envelope',
                'amount': 1.0,
                'envelopeConfig': <String, dynamic>{
                  'attackMs': 15,
                  'decayMs': 30,
                  'sustain': 0.0,
                  'releaseMs': 40,
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
                'id': 'evt-env',
                'trigger': <String, dynamic>{'type': 'periodic', 'rate': 25.0},
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{'modulatorId': 'env-1', 'mode': 'trigger'},
                ],
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(graph: graph, sampleRate: 1000, blockSize: 10);

      final gains = <double>[];
      for (var i = 0; i < 25; i++) {
        engine.processBlocks(1);
        gains.add(graph.layers.single.gain.finalValue);
      }

      final maxGain = gains.reduce((a, b) => a > b ? a : b);
      expect(maxGain, greaterThan(0.1));

      final distinct = gains.toSet().length;
      expect(distinct, greaterThan(5));
    });

    test('BurstModulator creates short-lived triggered windows', () {
      final burst = BurstModulator(
        sampleRate: 1000,
        durationMs: 20,
        intensity: 1,
        randomness: 0,
        attackMs: 0,
        releaseMs: 20,
        clusterMin: 1,
        clusterMax: 1,
        clusterSpreadMs: 0,
      );

      final idle = Float32List(10);
      burst.process(10, idle);
      expect(idle.every((sample) => sample == 0.0), isTrue);

      burst.trigger();
      final active = Float32List(30);
      burst.process(30, active);

      var nonZero = 0;
      for (final sample in active) {
        if (sample > 0.0) {
          nonZero++;
        }
      }

      expect(nonZero, greaterThanOrEqualTo(18));
      expect(active.first, closeTo(1.0, 1e-9));
      expect(active[15], greaterThan(0.0));
      expect(active.last, closeTo(0.0, 1e-9));

      burst.reset();
      final resetBuffer = Float32List(10);
      burst.process(10, resetBuffer);
      expect(resetBuffer.every((sample) => sample == 0.0), isTrue);
    });

    test('BurstModulator random intensity varies between triggers', () {
      final burst = BurstModulator(
        sampleRate: 1000,
        durationMs: 10,
        intensity: 1,
        randomness: 1,
        attackMs: 0,
        releaseMs: 10,
        clusterMin: 1,
        clusterMax: 1,
        clusterSpreadMs: 0,
      )..trigger();
      final first = Float32List(10);
      burst
        ..process(10, first)
        ..trigger();
      final second = Float32List(10);
      burst.process(10, second);

      expect(first.first, isNot(equals(second.first)));
      expect(first.first, greaterThanOrEqualTo(0.0));
      expect(first.first, lessThanOrEqualTo(1.0));
      expect(second.first, greaterThanOrEqualTo(0.0));
      expect(second.first, lessThanOrEqualTo(1.0));
    });

    test('engine events can trigger burst modulation on layer gain', () {
      const parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder(sampleRate: 1000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Burst Event Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 1000,
          'bitRate': 192,
        },
        'mix': <String, dynamic>{'mix': 1.0},
        'layers': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 0.0,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 500},
              },
            },
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'burst-1',
                'type': 'burst',
                'amount': 1.0,
                'burstConfig': <String, dynamic>{
                  'durationMs': 20,
                  'intensity': 1.0,
                  'randomness': 0.4,
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
                'id': 'evt-burst',
                'trigger': <String, dynamic>{'type': 'periodic', 'rate': 20.0},
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

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(graph: graph, sampleRate: 1000, blockSize: 10);

      final gains = <double>[];
      for (var i = 0; i < 30; i++) {
        engine.processBlocks(1);
        gains.add(graph.layers.single.gain.finalValue);
      }

      final peak = gains.reduce((a, b) => a > b ? a : b);
      final floor = gains.reduce((a, b) => a < b ? a : b);
      expect(peak, greaterThan(0.05));
      expect(floor, closeTo(0.0, 1e-6));

      final uniqueCount = gains.toSet().length;
      expect(uniqueCount, greaterThan(6));
    });

    test('engine events can modulate gain processor parameter', () {
      const parser = GenerationConfigParser();
      const graphBuilder = RuntimeGraphBuilder(sampleRate: 1000);

      final config = parser.parseJsonMap(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Processor Gain Event Patch'},
        'render': <String, dynamic>{
          'durationMinutes': 1,
          'sampleRate': 1000,
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
                'band': <String, dynamic>{'low': 20, 'high': 400},
              },
            },
            'processors': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'gain-1',
                'type': 'gain',
                'gain': <String, dynamic>{'gain': 0.0},
              },
            ],
            'modulations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'env-1',
                'type': 'envelope',
                'amount': 1.0,
                'envelopeConfig': <String, dynamic>{
                  'attackMs': 10,
                  'decayMs': 20,
                  'sustain': 0.0,
                  'releaseMs': 30,
                },
                'targets': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'path': 'layers[layer-a].processors[gain-1].gain.gain',
                    'amount': 1.0,
                  },
                ],
              },
            ],
            'events': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'evt-gain',
                'trigger': <String, dynamic>{'type': 'periodic', 'rate': 20.0},
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{'modulatorId': 'env-1', 'mode': 'trigger'},
                ],
              },
            ],
          },
        ],
      });

      final graph = graphBuilder.build(config);
      final engine = AudioEngine(graph: graph, sampleRate: 1000, blockSize: 10);
      final layer = graph.layers.single;
      final gainProcessor = layer.processors.single as GainProcessorNode;
      final gainParam = gainProcessor.parameter('gain')!;

      final values = <double>[];
      for (var i = 0; i < 20; i++) {
        engine.processBlocks(1);
        values.add(gainParam.finalValue);
      }

      final peak = values.reduce((a, b) => a > b ? a : b);
      final floor = values.reduce((a, b) => a < b ? a : b);
      expect(peak, greaterThan(0.1));
      expect(floor, closeTo(0.0, 1e-6));
      expect(values.toSet().length, greaterThan(3));
    });

    test(
      'runtime graph resolves modulation targets once to direct Parameters',
      () {
        const parser = GenerationConfigParser();
        const graphBuilder = RuntimeGraphBuilder();

        final config = parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Mod Binding Patch'},
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
                    'q': 0.8,
                    'gainDb': 0.0,
                  },
                },
              ],
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'mod-lfo',
                  'type': 'lfo',
                  'amount': 200.0,
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
              ],
            },
          ],
        });

        final graph = graphBuilder.build(config);
        final layer = graph.layers.single;
        expect(layer.modulationBindings.length, 1);

        final binding = layer.modulationBindings.single;
        expect(binding.id, 'mod-lfo');
        expect(binding.targets.length, 1);

        final directTarget = binding.targets.single.parameter;
        final resolved = graph.resolvePath(
          'layers[layer-a].processors[lp-1].biquad.frequency',
        );
        expect(resolved, isNotNull);
        expect(identical(directTarget, resolved!.parameter), isTrue);
      },
    );

    test(
      'runtime graph resolves event actions to direct modulation bindings',
      () {
        const parser = GenerationConfigParser();
        const graphBuilder = RuntimeGraphBuilder();

        final config = parser.parseJsonMap(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Event Binding Patch'},
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
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'mod-random',
                  'type': 'random',
                  'amount': 1.0,
                  'randomConfig': <String, dynamic>{
                    'rateHz': 0.2,
                    'smooth': 0.95,
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
                  'id': 'evt-1',
                  'trigger': <String, dynamic>{'type': 'poisson', 'rate': 2.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'modulatorId': 'mod-random',
                      'mode': 'trigger',
                    },
                  ],
                },
              ],
            },
          ],
        });

        final graph = graphBuilder.build(config);
        final layer = graph.layers.single;

        expect(layer.eventBindings.length, 1);
        expect(layer.eventBindings.single.id, 'evt-1');
        expect(layer.eventBindings.single.actions.length, 1);
        expect(
          layer.eventBindings.single.actions.single.modulation.id,
          'mod-random',
        );
      },
    );

    test(
      'EventScheduler periodic triggers dispatch trigger and gate actions',
      () {
        final counter = _CounterModulator();
        final modulation = RuntimeModulationBinding(
          id: 'mod-counter',
          modulator: counter,
          amount: 1,
          targets: const <ModulationTargetBinding>[],
        );

        final scheduler = EventScheduler(
          events: <RuntimeEventBinding>[
            RuntimeEventBinding(
              id: 'evt-periodic',
              type: TriggerType.periodic,
              rate: 20,
              actions: <RuntimeEventAction>[
                RuntimeEventAction(
                  mode: ActionMode.trigger,
                  modulation: modulation,
                ),
                RuntimeEventAction(
                  mode: ActionMode.gate,
                  modulation: modulation,
                ),
              ],
            ),
          ],
          sampleRate: 100,
          blockSize: 10,
        );

        for (var i = 0; i < 5; i++) {
          scheduler.processBlock();
        }

        expect(counter.triggerCount, greaterThan(0));
        expect(counter.resetCount, greaterThan(0));
        expect(counter.triggerCount, counter.resetCount);
      },
    );

    test('EventScheduler Poisson schedule is deterministic for same seed', () {
      final counterA = _CounterModulator();
      final counterB = _CounterModulator();

      RuntimeEventBinding makeEvent(_CounterModulator modulator) {
        return RuntimeEventBinding(
          id: 'evt-poisson',
          type: TriggerType.poisson,
          rate: 4,
          actions: <RuntimeEventAction>[
            RuntimeEventAction(
              mode: ActionMode.trigger,
              modulation: RuntimeModulationBinding(
                id: 'mod-counter',
                modulator: modulator,
                amount: 1,
                targets: const <ModulationTargetBinding>[],
              ),
            ),
          ],
        );
      }

      final schedulerA = EventScheduler(
        events: <RuntimeEventBinding>[makeEvent(counterA)],
        sampleRate: 100,
        blockSize: 10,
        seed: 12345,
      );
      final schedulerB = EventScheduler(
        events: <RuntimeEventBinding>[makeEvent(counterB)],
        sampleRate: 100,
        blockSize: 10,
        seed: 12345,
      );

      final firedA = <String>[];
      final firedB = <String>[];
      for (var i = 0; i < 200; i++) {
        firedA.addAll(schedulerA.processBlock());
        firedB.addAll(schedulerB.processBlock());
      }

      expect(firedA.length, firedB.length);
      expect(counterA.triggerCount, counterB.triggerCount);
      expect(firedA.join(','), firedB.join(','));
    });

    test('engine applies modulation per block and evolves filtered sound', () {
      const parser = GenerationConfigParser();
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
                  'frequency': 600,
                  'q': 0.8,
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
                  'frequency': 1.0,
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

      final samples = engine.renderSamples(totalSamples: 4096);
      final allZero = samples.every((sample) => sample == 0.0);
      expect(allZero, isFalse);
    });
  });

  group('saturator processor', () {
    test(
      'saturator config serializes and deserializes with both curve types',
      () {
        const tanhConfig = ProcessorConfig(
          id: 'sat-1',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.7),
        );
        final softJson = <String, dynamic>{
          'id': 'sat-2',
          'type': 'saturator',
          'saturator': <String, dynamic>{'drive': 0.4, 'curve': 'soft'},
        };

        final tanhRound = ProcessorConfig.fromJson(tanhConfig.toJson());
        expect(tanhRound.id, 'sat-1');
        expect(tanhRound.saturator!.drive, closeTo(0.7, 1e-9));
        expect(tanhRound.saturator!.curve, SaturatorCurve.tanh);

        final softConfig = ProcessorConfig.fromJson(softJson);
        expect(softConfig.saturator!.drive, closeTo(0.4, 1e-6));
        expect(softConfig.saturator!.curve, SaturatorCurve.soft);
      },
    );

    test('saturator drive=0 passes buffer unchanged', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-bypass',
        curve: SaturatorCurve.tanh,
        drive: 0,
      )..prepare(44100, 4);
      for (final p in sat.parameters.values) {
        p.update();
      }

      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.3, -0.8]);
      final original = Float32List.fromList(buffer);
      sat.process(buffer);

      for (var i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(original[i], 1e-9));
      }
    });

    test(
      'saturator tanh drive=1 compresses and normalizes high-amplitude input',
      () {
        final sat = SaturatorProcessorNode(
          id: 'sat-tanh',
          curve: SaturatorCurve.tanh,
          drive: 1,
        )..prepare(44100, 4);
        for (final p in sat.parameters.values) {
          p.update();
        }

        // Input 0.5 with drive=1: tanh(5.0)/tanh(10.0) ≈ 1.0 — strongly saturated.
        final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.5, -0.5]);
        sat.process(buffer);

        for (final s in buffer) {
          expect(s.isFinite, isTrue);
        }
        // 0.5 input pushed strongly toward ±1.0 (gain+saturation).
        expect(buffer[0], greaterThan(0.9));
        expect(buffer[1], lessThan(-0.9));
        // Normalization keeps output within ±1.0.
        for (final s in buffer) {
          expect(s.abs(), lessThanOrEqualTo(1.0 + 1e-6));
        }
      },
    );

    test('saturator soft drive=1 clips and shapes high-amplitude input', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-soft',
        curve: SaturatorCurve.soft,
        drive: 1,
      )..prepare(44100, 4);
      for (final p in sat.parameters.values) {
        p.update();
      }

      // Input 0.5 with soft+drive=1: preGain=4, driven=clamp(2.0,-1,1)=1.0
      // satOut = 1.5*1.0*(1-1/3) = 1.0 — full soft clip output.
      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.5, -0.5]);
      sat.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
        expect(s.abs(), lessThanOrEqualTo(1.0 + 1e-6));
      }
      expect(buffer[0], greaterThan(0.9));
      expect(buffer[1], lessThan(-0.9));
    });

    test('saturator guards against non-finite drive parameter', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-safe',
        curve: SaturatorCurve.tanh,
        drive: 1,
      )..prepare(44100, 4);
      sat.parameter('drive')!.baseValue = double.nan;
      sat.parameter('drive')!.update();

      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.3, -0.3]);
      sat.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
      }
    });
  });

  group('delay processor', () {
    test('delay config serializes and deserializes safely', () {
      const config = ProcessorConfig(
        id: 'delay-proc',
        type: ProcessorType.delay,
        delay: DelayConfig(delayTimeMs: 200, feedback: 0.4, mix: 0.5),
      );
      final roundTrip = ProcessorConfig.fromJson(config.toJson());

      expect(roundTrip.id, 'delay-proc');
      expect(roundTrip.delay!.delayTimeMs, 200);
      expect(roundTrip.delay!.feedback, closeTo(0.4, 1e-9));
      expect(roundTrip.delay!.mix, closeTo(0.5, 1e-9));
    });

    test('delay mix=0 passes buffer unchanged (dry bypass)', () {
      final delay = DelayProcessorNode(
        id: 'delay-dry',
        delayTimeMs: 10,
        feedback: 0,
        mix: 0,
      )..prepare(44100, 8);
      for (final p in delay.parameters.values) {
        p.update();
      }

      final buffer = Float32List.fromList(<double>[
        0.1,
        0.2,
        0.3,
        0.4,
        0.5,
        0.6,
        0.7,
        0.8,
      ]);
      final original = Float32List.fromList(buffer);
      delay.process(buffer);

      for (var i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(original[i], 1e-6));
      }
    });

    test(
      'delay mix=1 feedback=0 outputs delayed signal after delaySamples',
      () {
        // 10ms × 44100 Hz = 441 samples of delay.
        final delay = DelayProcessorNode(
          id: 'delay-impulse',
          delayTimeMs: 10,
          feedback: 0,
          mix: 1,
        );
        const blockSize = 512;
        delay.prepare(44100, blockSize);
        for (final p in delay.parameters.values) {
          p.update();
        }

        // Single impulse at index 0; rest silent.
        final buffer = Float32List(blockSize);
        buffer[0] = 1.0;
        delay.process(buffer);

        // Samples before the delay window should be silent.
        expect(buffer[0], closeTo(0.0, 1e-6));
        for (var i = 1; i < 441; i++) {
          expect(buffer[i], closeTo(0.0, 1e-6));
        }
        // Impulse emerges exactly 441 samples later.
        expect(buffer[441], closeTo(1.0, 1e-4));
      },
    );

    test('delay feedback accumulates signal energy over time', () {
      final delay = DelayProcessorNode(
        id: 'delay-feedback',
        delayTimeMs: 5,
        feedback: 0.5,
        mix: 0.5,
      );
      const blockSize = 256;
      delay.prepare(44100, blockSize);
      for (final p in delay.parameters.values) {
        p.update();
      }

      // Drive the delay with a constant signal for one block.
      final block1 = Float32List(blockSize)..fillRange(0, blockSize, 0.5);
      delay.process(block1);

      // Feed silence into the delay — energy should appear from feedback tails.
      final block2 = Float32List(blockSize);
      delay.process(block2);
      final energy = block2.fold<double>(0, (sum, s) => sum + s * s);

      expect(energy, greaterThan(0.0));
    });

    test('delay guards against non-finite feedback parameter', () {
      final delay = DelayProcessorNode(
        id: 'delay-safe',
        delayTimeMs: 10,
        feedback: 0.5,
        mix: 0.5,
      )..prepare(44100, 8);
      delay.parameter('feedback')!.baseValue = double.nan;
      delay.parameter('feedback')!.update();

      final buffer = Float32List(8)..fillRange(0, 8, 0.5);
      delay.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
      }
    });
  });
}

class _CounterModulator implements Modulator {
  int triggerCount = 0;
  int resetCount = 0;

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      buffer[i] = 0.0;
    }
  }

  @override
  void trigger() {
    triggerCount++;
  }

  @override
  void reset() {
    resetCount++;
  }
}
