import 'package:flutter_test/flutter_test.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

Map<String, dynamic> _baseValidConfigJson() {
  return <String, dynamic>{
    'metadata': <String, dynamic>{'name': 'Base Valid Patch'},
    'render': <String, dynamic>{
      'durationMinutes': 1,
      'sampleRate': 44100,
      'bitRate': 192,
      'format': 'wav',
    },
    'mix': <String, dynamic>{'mix': 1.0},
    'layers': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'layer-a',
        'gain': 1.0,
        'pan': 0.0,
        'source': <String, dynamic>{
          'type': 'noise',
          'noiseConfig': <String, dynamic>{
            'color': 'white',
            'band': <String, dynamic>{'low': 20, 'high': 18000},
          },
        },
      },
    ],
  };
}

void main() {
  group('configuration models', () {
    test('MetadataConfig serializes and deserializes safely', () {
      final config = MetadataConfig(
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
      expect(restored.format, RenderFormat.mp3);
      expect(restored.dcBlockerEnabled, isTrue);

      expect(
        RenderConfig(
          durationMinutes: 10,
          sampleRate: 48000,
          bitRate: 256,
          dcBlockerEnabled: false,
        ).toJson(),
        <String, dynamic>{
          'durationMinutes': 10,
          'sampleRate': 48000,
          'bitRate': 256,
          'format': 'mp3',
          'dcBlockerEnabled': false,
        },
      );
    });

    test('RenderConfig round-trips mp3 format', () {
      final config = RenderConfig(
        durationMinutes: 5,
        bitRate: 128,
        format: RenderFormat.mp3,
      );
      final restored = RenderConfig.fromJson(config.toJson());
      expect(restored.format, RenderFormat.mp3);
      expect(restored.bitRate, 128);
      expect(restored.dcBlockerEnabled, isTrue);
    });

    test('MixConfig supports optional dither config with defaults', () {
      final defaults = MixConfig.fromJson(<String, dynamic>{});
      expect(defaults.mix, closeTo(1.0, 1e-9));
      expect(defaults.dither.enabled, isFalse);
      expect(defaults.dither.type, DitherType.tpdf);
      expect(defaults.dither.bitDepth, 16);
      expect(defaults.dither.amount, closeTo(1.0, 1e-9));
      expect(defaults.normalization.enabled, isFalse);
      expect(defaults.normalization.targetDb, closeTo(-1.0, 1e-9));

      final configured = MixConfig(
        mix: 0.85,
        dither: DitherConfig(
          enabled: true,
          bitDepth: 24,
          amount: 0.5,
        ),
        normalization: NormalizationConfig(
          enabled: true,
          targetDb: -6,
        ),
      );

      final restored = MixConfig.fromJson(configured.toJson());
      expect(restored.mix, closeTo(0.85, 1e-9));
      expect(restored.dither.enabled, isTrue);
      expect(restored.dither.type, DitherType.tpdf);
      expect(restored.dither.bitDepth, 24);
      expect(restored.dither.amount, closeTo(0.5, 1e-9));
      expect(restored.normalization.enabled, isTrue);
      expect(restored.normalization.targetDb, closeTo(-6.0, 1e-9));
    });

    test(
      'RenderConfig fromJson falls back to mp3 for unknown format string',
      () {
        final config = RenderConfig.fromJson(<String, dynamic>{
          'format': 'ogg',
        });
        expect(config.format, RenderFormat.mp3);
      },
    );

    test('ModulationConfig serializes enum name with canonical fields', () {
      final config = ModulationConfig(
        id: 'mod-1',
        type: ModulationType.drift,
        seed: 4242,
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
      expect(restored.seed, 4242);
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
      final config = EventConfig(
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
      final config = ProcessorConfig(
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
      final config = ProcessorConfig(
        id: 'hp-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.highpass,
          frequency: 900,
          q: 1.2,
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
      final bandpass = ProcessorConfig(
        id: 'bp-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.bandpass,
          frequency: 1400,
          q: 4,
          resonant: true,
        ),
      );
      final peak = ProcessorConfig(
        id: 'peak-1',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.peak,
          frequency: 900,
          q: 2.5,
          gainDb: 6,
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
      final parser = GenerationConfigParser();

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
        final parser = GenerationConfigParser();

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
        final parser = GenerationConfigParser();

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
              (error) => error.issues.any((issue) => issue.path.endsWith('.path')),
              'path issue',
              isTrue,
            ),
          ),
        );
      },
    );

    test('GenerationConfigParser rejects non-finite gain processor values', () {
      final parser = GenerationConfigParser();

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

    test(
      'GenerationConfigParser rejects target minValue greater than maxValue',
      () {
        final parser = GenerationConfigParser();

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
              (error) => error.issues.any((issue) => issue.path.contains('.targets[')),
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
        final parser = GenerationConfigParser();

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
                        'path': 'layers[layer-a].processors[gain-1].config.gain',
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

    test('GenerationConfigParser parseJsonString rejects non-object root', () {
      final parser = GenerationConfigParser();

      expect(
        () => parser.parseJsonString('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('GenerationConfigParser rejects duplicate layer ids', () {
      final parser = GenerationConfigParser();

      final json = _baseValidConfigJson();
      json['layers'] = <Map<String, dynamic>>[
        (json['layers'] as List<Map<String, dynamic>>).first,
        <String, dynamic>{
          'id': 'layer-a',
          'source': <String, dynamic>{
            'type': 'sine',
            'sineConfig': <String, dynamic>{'frequencyHz': 110, 'phase': 0},
          },
        },
      ];

      expect(
        () => parser.parseJsonMap(json),
        throwsA(
          isA<ConfigValidationException>().having(
            (error) => error.issues.any((issue) => issue.message.contains('must be unique')),
            'duplicate layer issue',
            isTrue,
          ),
        ),
      );
    });

    test(
      'GenerationConfigParser rejects duplicate processor and modulation ids in a layer',
      () {
        final parser = GenerationConfigParser();

        final json = _baseValidConfigJson();
        final layers = json['layers'] as List<Map<String, dynamic>>;
        layers[0]['processors'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'gain-1',
            'type': 'gain',
            'gain': <String, dynamic>{'gain': 1.0},
          },
          <String, dynamic>{
            'id': 'gain-1',
            'type': 'gain',
            'gain': <String, dynamic>{'gain': 0.5},
          },
        ];
        layers[0]['modulations'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'mod-1',
            'type': 'lfo',
            'amount': 1.0,
            'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
            'targets': <Map<String, dynamic>>[
              <String, dynamic>{'path': 'layers[layer-a].gain'},
            ],
          },
          <String, dynamic>{
            'id': 'mod-1',
            'type': 'lfo',
            'amount': 1.0,
            'lfoConfig': <String, dynamic>{'frequency': 0.5, 'depth': 0.6},
            'targets': <Map<String, dynamic>>[
              <String, dynamic>{'path': 'layers[layer-a].pan'},
            ],
          },
        ];

        expect(
          () => parser.parseJsonMap(json),
          throwsA(
            isA<ConfigValidationException>().having(
              (error) => error.issues.where((issue) => issue.message.contains('must be unique inside a layer')).length,
              'duplicate processor/modulation issues',
              greaterThanOrEqualTo(2),
            ),
          ),
        );
      },
    );

    test('GenerationConfigParser rejects event action modulator references that do not exist', () {
      final parser = GenerationConfigParser();

      final json = _baseValidConfigJson();
      final layer = (json['layers'] as List<Map<String, dynamic>>).first;
      layer['modulations'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'mod-existing',
          'type': 'lfo',
          'amount': 1.0,
          'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'path': 'layers[layer-a].gain'},
          ],
        },
      ];
      layer['events'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'event-1',
          'trigger': <String, dynamic>{'type': 'periodic', 'rate': 1.0},
          'actions': <Map<String, dynamic>>[
            <String, dynamic>{'modulatorId': 'missing-mod', 'mode': 'trigger'},
          ],
        },
      ];

      expect(
        () => parser.parseJsonMap(json),
        throwsA(
          isA<ConfigValidationException>().having(
            (error) => error.issues.any(
              (issue) => issue.path.endsWith('.modulatorId') && issue.message.contains('does not exist'),
            ),
            'unknown modulator reference issue',
            isTrue,
          ),
        ),
      );
    });

    test('GenerationConfigParser validates modulation-type specific numeric ranges', () {
      final parser = GenerationConfigParser();

      final json = _baseValidConfigJson();
      final layer = (json['layers'] as List<Map<String, dynamic>>).first;
      layer['modulations'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'mod-random-bad',
          'type': 'random',
          'randomConfig': <String, dynamic>{'rateHz': 0, 'smooth': 1.5},
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'path': 'layers[layer-a].gain'},
          ],
        },
        <String, dynamic>{
          'id': 'mod-env-bad',
          'type': 'envelope',
          'envelopeConfig': <String, dynamic>{
            'attackMs': -1,
            'decayMs': -1,
            'releaseMs': -1,
            'sustain': 1.5,
          },
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'path': 'layers[layer-a].pan'},
          ],
        },
        <String, dynamic>{
          'id': 'mod-burst-bad',
          'type': 'burst',
          'burstConfig': <String, dynamic>{
            'durationMs': 0,
            'intensity': 2.0,
            'randomness': -1.0,
            'attackMs': -1,
            'releaseMs': 0,
            'clusterMin': 0,
            'clusterMax': -1,
            'clusterSpreadMs': -1,
          },
          'targets': <Map<String, dynamic>>[
            <String, dynamic>{'path': 'layers[layer-a].gain'},
          ],
        },
      ];

      expect(
        () => parser.parseJsonMap(json),
        throwsA(
          isA<ConfigValidationException>().having(
            (error) => error.issues.length,
            'issues.length',
            greaterThanOrEqualTo(10),
          ),
        ),
      );
    });
  });
}
