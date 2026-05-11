import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/engine/modulators/modulator_factory.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import '../test_helpers/modulators_test_helpers.dart';

const _smokeTag = <String>['smoke'];
const _qualityTag = <String>['quality'];

void main() {
  group('event scheduling smoke', () {
    test(
      'runtime graph resolves modulation targets once to direct Parameters',
      () {
        final parser = GenerationConfigParser();
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
      tags: _smokeTag,
    );

    test(
      'runtime graph resolves event actions to direct modulation bindings',
      () {
        final parser = GenerationConfigParser();
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
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 1.0},
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
      tags: _smokeTag,
    );

    test(
      'runtime graph ignores blank event action modulator ids during editing',
      () {
        const graphBuilder = RuntimeGraphBuilder();

        final config = GenerationConfig.fromJson(<String, dynamic>{
          'metadata': <String, dynamic>{'name': 'Event Editing Patch'},
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
                  'id': 'evt-blank',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 1.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'modulatorId': '',
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

        expect(layer.eventBindings, isEmpty);
      },
      tags: _smokeTag,
    );
  });

  group('event scheduling quality', () {
    test(
      'EventScheduler periodic triggers dispatch trigger and gate actions',
      () {
        final counter = CounterModulator();
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

        // 20 Hz over 0.5 s should yield exactly 10 periodic firings.
        expect(counter.triggerCount, 10);
        expect(counter.resetCount, 10);
        expect(counter.triggerCount, counter.resetCount);
      },
      tags: _qualityTag,
    );

    test('EventScheduler Poisson schedule is deterministic for same seed', () {
      final counterA = CounterModulator();
      final counterB = CounterModulator();

      RuntimeEventBinding makeEvent(CounterModulator modulator) {
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
      const seconds = (200 * 10) / 100.0;
      const expected = 4.0 * seconds;
      expect(counterA.triggerCount, greaterThan(expected * 0.6));
      expect(counterA.triggerCount, lessThan(expected * 1.4));
    }, tags: _qualityTag);

    test('EventScheduler random trigger is deterministic for same seed', () {
      final counterA = CounterModulator();
      final counterB = CounterModulator();

      RuntimeEventBinding makeEvent(CounterModulator modulator) {
        return RuntimeEventBinding(
          id: 'evt-random',
          type: TriggerType.random,
          rate: 4.5,
          actions: <RuntimeEventAction>[
            RuntimeEventAction(
              mode: ActionMode.trigger,
              modulation: RuntimeModulationBinding(
                id: 'mod-counter-random',
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
        seed: 54321,
      );
      final schedulerB = EventScheduler(
        events: <RuntimeEventBinding>[makeEvent(counterB)],
        sampleRate: 100,
        blockSize: 10,
        seed: 54321,
      );

      final firedA = <String>[];
      final firedB = <String>[];
      for (var i = 0; i < 200; i++) {
        firedA.addAll(schedulerA.processBlock());
        firedB.addAll(schedulerB.processBlock());
      }

      expect(counterA.triggerCount, greaterThan(0));
      expect(counterA.triggerCount, counterB.triggerCount);
      expect(firedA.join(','), firedB.join(','));
      const seconds = (200 * 10) / 100.0;
      const expected = 4.5 * seconds;
      expect(counterA.triggerCount, greaterThan(expected * 0.5));
      expect(counterA.triggerCount, lessThan(expected * 1.5));
    }, tags: _qualityTag);

    test('engine events can modulate gain processor parameter', () {
      final parser = GenerationConfigParser();
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
      expect(peak - floor, greaterThan(0.3));
    }, tags: _qualityTag);
  });
}
