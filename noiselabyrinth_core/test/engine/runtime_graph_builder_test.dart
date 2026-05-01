import 'package:flutter_test/flutter_test.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
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

    test('build maps biquad highpass mode and resonant flag into node', () {
      const builder = RuntimeGraphBuilder();

      final config = GenerationConfig.fromJson(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Biquad Mapping'},
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
                'id': 'hp-1',
                'type': 'biquad',
                'biquad': <String, dynamic>{
                  'biquadMode': 'highpass',
                  'frequency': 1000,
                  'q': 2.0,
                  'gainDb': 0.0,
                  'resonant': true,
                },
              },
            ],
          },
        ],
      });

      final runtime = builder.build(config);
      final processor = runtime.layers.single.processors.single;

      expect(processor, isA<BiquadProcessorNode>());
      final biquad = processor as BiquadProcessorNode;
      expect(biquad.mode, BiquadMode.highpass);
      expect(biquad.resonant, isTrue);
    });

    test('build maps bandpass and peak biquad nodes with resonant flags', () {
      const builder = RuntimeGraphBuilder();

      final config = GenerationConfig.fromJson(<String, dynamic>{
        'metadata': <String, dynamic>{'name': 'Biquad Mapping Expanded'},
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
                'id': 'bp-1',
                'type': 'biquad',
                'biquad': <String, dynamic>{
                  'biquadMode': 'bandpass',
                  'frequency': 1400,
                  'q': 4.0,
                  'gainDb': 0.0,
                  'resonant': true,
                },
              },
              <String, dynamic>{
                'id': 'peak-1',
                'type': 'biquad',
                'biquad': <String, dynamic>{
                  'biquadMode': 'peak',
                  'frequency': 900,
                  'q': 2.0,
                  'gainDb': 6.0,
                  'resonant': false,
                },
              },
            ],
          },
        ],
      });

      final runtime = builder.build(config);
      expect(runtime.layers.single.processors.length, 2);

      final bandpass = runtime.layers.single.processors[0] as BiquadProcessorNode;
      final peak = runtime.layers.single.processors[1] as BiquadProcessorNode;

      expect(bandpass.mode, BiquadMode.bandpass);
      expect(bandpass.resonant, isTrue);
      expect(peak.mode, BiquadMode.peak);
      expect(peak.resonant, isFalse);
    });
  });
}
