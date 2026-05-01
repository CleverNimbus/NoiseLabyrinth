import 'package:flutter_test/flutter_test.dart';

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
      expect(restored.format, RenderFormat.wav);

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
          'format': 'wav',
        },
      );
    });

    test('RenderConfig round-trips mp3 format', () {
      const config = RenderConfig(
        durationMinutes: 5,
        sampleRate: 44100,
        bitRate: 128,
        format: RenderFormat.mp3,
      );
      final restored = RenderConfig.fromJson(config.toJson());
      expect(restored.format, RenderFormat.mp3);
      expect(restored.bitRate, 128);
    });

    test(
      'RenderConfig fromJson falls back to wav for unknown format string',
      () {
        final config = RenderConfig.fromJson(<String, dynamic>{
          'format': 'ogg',
        });
        expect(config.format, RenderFormat.wav);
      },
    );

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
            minValue: 0.0,
            maxValue: 1.0,
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

    test('ProcessorConfig biquad preserves highpass and resonant flags', () {
      const config = ProcessorConfig(
        id: 'hp-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.highpass,
          frequency: 900,
          q: 1.2,
          gainDb: 0.0,
          resonant: true,
        ),
      );

      final restored = ProcessorConfig.fromJson(config.toJson());

      expect(restored.id, 'hp-1');
      expect(restored.type, ProcessorType.biquad);
      expect(restored.biquad, isNotNull);
      expect(restored.biquad!.biquadMode, BiquadMode.highpass);
      expect(restored.biquad!.frequency, 900);
      expect(restored.biquad!.q, closeTo(1.2, 1e-9));
      expect(restored.biquad!.resonant, isTrue);
    });

    test('ProcessorConfig biquad preserves bandpass and peak modes', () {
      const bandpass = ProcessorConfig(
        id: 'bp-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.bandpass,
          frequency: 1400,
          q: 4.0,
          gainDb: 0.0,
          resonant: true,
        ),
      );
      const peak = ProcessorConfig(
        id: 'peak-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.peak,
          frequency: 900,
          q: 2.5,
          gainDb: 6.0,
          resonant: false,
        ),
      );

      final restoredBandpass = ProcessorConfig.fromJson(bandpass.toJson());
      final restoredPeak = ProcessorConfig.fromJson(peak.toJson());

      expect(restoredBandpass.biquad!.biquadMode, BiquadMode.bandpass);
      expect(restoredBandpass.biquad!.resonant, isTrue);
      expect(restoredPeak.biquad!.biquadMode, BiquadMode.peak);
      expect(restoredPeak.biquad!.gainDb, closeTo(6.0, 1e-9));
      expect(restoredPeak.biquad!.resonant, isFalse);
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
                    'path': 'layers[layer-a].gain',
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
                    'id': 'mod-bad',
                    'type': 'lfo',
                    'lfoConfig': <String, dynamic>{
                      'frequency': 1.0,
                      'depth': 1.0,
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
              (error) =>
                  error.issues.any((issue) => issue.path.endsWith('.path')),
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
            (error) =>
                error.issues.any((issue) => issue.path.endsWith('.gain.gain')),
            'gain issue',
            isTrue,
          ),
        ),
      );
    });

    test(
      'GenerationConfigParser rejects target minValue greater than maxValue',
      () {
        const parser = GenerationConfigParser();

        expect(
          () => parser.parseJsonMap(<String, dynamic>{
            'metadata': <String, dynamic>{'name': 'Invalid Target Clamp Patch'},
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
                    'id': 'mod-1',
                    'type': 'lfo',
                    'amount': 1.0,
                    'lfoConfig': <String, dynamic>{
                      'frequency': 1.0,
                      'depth': 1.0,
                    },
                    'targets': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'path': 'layers[layer-a].gain',
                        'mode': 'additive',
                        'minValue': 1.0,
                        'maxValue': 0.0,
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          throwsA(
            isA<ConfigValidationException>().having(
              (error) =>
                  error.issues.any((issue) => issue.path.contains('.targets[')),
              'target bounds issue',
              isTrue,
            ),
          ),
        );
      },
    );

    test(
      'GenerationConfigParser rejects legacy processor config path aliases',
      () {
        const parser = GenerationConfigParser();

        expect(
          () => parser.parseJsonMap(<String, dynamic>{
            'metadata': <String, dynamic>{'name': 'Legacy Path Alias Patch'},
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
                    'gain': <String, dynamic>{'gain': 1.0},
                  },
                ],
                'modulations': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'mod-legacy-path',
                    'type': 'lfo',
                    'amount': 0.5,
                    'lfoConfig': <String, dynamic>{
                      'type': 'sine',
                      'frequency': 1.0,
                      'depth': 1.0,
                    },
                    'targets': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'path':
                            'layers[layer-a].processors[gain-1].config.gain',
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          throwsA(
            isA<ConfigValidationException>().having(
              (error) =>
                  error.issues.any((issue) => issue.path.endsWith('.path')),
              'path issue',
              isTrue,
            ),
          ),
        );
      },
    );
  });
}
