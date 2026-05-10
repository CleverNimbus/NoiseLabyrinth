import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

Map<String, dynamic> _validRoot({required List<Map<String, dynamic>> layers}) {
  return <String, dynamic>{
    'metadata': <String, dynamic>{'name': 'Validation Test Patch'},
    'render': <String, dynamic>{
      'durationMinutes': 1,
      'sampleRate': 44100,
      'bitRate': 192,
      'format': 'wav',
    },
    'mix': <String, dynamic>{'mix': 1.0},
    'layers': layers,
  };
}

ConfigValidationException _expectValidationFailure(
  GenerationConfigParser parser,
  Map<String, dynamic> json,
) {
  try {
    parser.parseJsonMap(json);
    fail('Expected ConfigValidationException');
  } on ConfigValidationException catch (error) {
    return error;
  }
}

void main() {
  group('config validation', () {
    test('ConfigValidationIssue and exception provide useful string output', () {
      final issue = ConfigValidationIssue(
        path: 'render.durationMinutes',
        message: 'durationMinutes must be > 0.',
      );
      expect(issue.toString(), 'render.durationMinutes: durationMinutes must be > 0.');

      final exception = ConfigValidationException(<ConfigValidationIssue>[issue]);
      expect(exception.toString(), contains('Configuration validation failed with 1 issue(s):'));
      expect(exception.toString(), contains('- render.durationMinutes: durationMinutes must be > 0.'));
    });

    test('parseJsonString accepts valid object JSON and rejects non-object root', () {
      final parser = GenerationConfigParser();

      final validJson = jsonEncode(
        _validRoot(
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-a',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
              },
            },
          ],
        ),
      );

      final parsed = parser.parseJsonString(validJson);
      expect(parsed.layers.single.id, 'layer-a');

      expect(
        () => parser.parseJsonString('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validation rejects invalid dither settings', () {
      final parser = GenerationConfigParser();

      final error = _expectValidationFailure(
        parser,
        _validRoot(
            layers: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'layer-a',
                'source': <String, dynamic>{
                  'type': 'sine',
                  'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
                },
              },
            ],
          )
          ..['mix'] = <String, dynamic>{
            'mix': 1.0,
            'dither': <String, dynamic>{
              'enabled': true,
              'bitDepth': 0,
              'amount': -0.5,
            },
          },
      );

      expect(
        error.issues.any((issue) => issue.path == 'mix.dither.bitDepth'),
        isTrue,
      );
      expect(
        error.issues.any((issue) => issue.path == 'mix.dither.amount'),
        isTrue,
      );
    });

    test('validation rejects invalid normalization targetDb settings', () {
      final parser = GenerationConfigParser();

      final tooHigh = _expectValidationFailure(
        parser,
        _validRoot(
            layers: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'layer-a',
                'source': <String, dynamic>{
                  'type': 'sine',
                  'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
                },
              },
            ],
          )
          ..['mix'] = <String, dynamic>{
            'mix': 1.0,
            'normalization': <String, dynamic>{
              'enabled': true,
              'targetDb': 1.0,
            },
          },
      );

      final tooLow = _expectValidationFailure(
        parser,
        _validRoot(
            layers: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'layer-a',
                'source': <String, dynamic>{
                  'type': 'sine',
                  'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
                },
              },
            ],
          )
          ..['mix'] = <String, dynamic>{
            'mix': 1.0,
            'normalization': <String, dynamic>{
              'enabled': true,
              'targetDb': -140.0,
            },
          },
      );

      expect(
        tooHigh.issues.any((issue) => issue.path == 'mix.normalization.targetDb'),
        isTrue,
      );
      expect(
        tooLow.issues.any((issue) => issue.path == 'mix.normalization.targetDb'),
        isTrue,
      );
    });

    test('root and cross-layer constraints reject empty layer set and duplicate ids', () {
      final parser = GenerationConfigParser();

      final emptyLayersError = _expectValidationFailure(
        parser,
        _validRoot(layers: <Map<String, dynamic>>[]),
      );
      expect(
        emptyLayersError.issues.any((issue) => issue.path == 'layers'),
        isTrue,
      );

      final duplicateLayerError = _expectValidationFailure(
        parser,
        _validRoot(
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-dup',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
              },
            },
            <String, dynamic>{
              'id': 'layer-dup',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 20000},
                },
              },
            },
          ],
        ),
      );
      expect(
        duplicateLayerError.issues.any((issue) => issue.message.contains('must be unique')),
        isTrue,
      );
    });

    test('validation reports source, processor, modulation, and event branch errors', () {
      final parser = GenerationConfigParser();

      final error = _expectValidationFailure(
        parser,
        _validRoot(
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-noise-missing',
              'source': <String, dynamic>{'type': 'noise'},
            },
            <String, dynamic>{
              'id': 'layer-impulse-bounds',
              'source': <String, dynamic>{
                'type': 'impulse',
                'impulseConfig': <String, dynamic>{'density': 1.5, 'randomness': -0.5},
              },
            },
            <String, dynamic>{
              'id': 'layer-sine-missing',
              'source': <String, dynamic>{'type': 'sine'},
            },
            <String, dynamic>{
              'id': 'layer-rules',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': -1, 'high': -2},
                },
              },
              'processors': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '',
                  'type': 'gain',
                  'gain': <String, dynamic>{'gain': 1.0},
                },
                <String, dynamic>{'id': 'biquad-missing', 'type': 'biquad'},
                <String, dynamic>{
                  'id': 'biquad-invalid',
                  'type': 'biquad',
                  'biquad': <String, dynamic>{'frequency': 0, 'q': 0},
                },
                <String, dynamic>{'id': 'gain-missing', 'type': 'gain'},
                <String, dynamic>{'id': 'sat-missing', 'type': 'saturator'},
                <String, dynamic>{
                  'id': 'sat-invalid',
                  'type': 'saturator',
                  'saturator': <String, dynamic>{'drive': -0.1},
                },
                <String, dynamic>{'id': 'delay-missing', 'type': 'delay'},
                <String, dynamic>{
                  'id': 'delay-invalid',
                  'type': 'delay',
                  'delay': <String, dynamic>{
                    'delayTimeMs': -1,
                    'feedback': 1.5,
                    'mix': -0.1,
                  },
                },
                <String, dynamic>{
                  'id': 'gain-dup',
                  'type': 'gain',
                  'gain': <String, dynamic>{'gain': 1.0},
                },
                <String, dynamic>{
                  'id': 'gain-dup',
                  'type': 'gain',
                  'gain': <String, dynamic>{'gain': 0.5},
                },
              ],
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '',
                  'type': 'lfo',
                  'amount': double.nan,
                  'targets': <Map<String, dynamic>>[],
                },
                <String, dynamic>{
                  'id': 'lfo-missing',
                  'type': 'lfo',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].gain'},
                  ],
                },
                <String, dynamic>{
                  'id': 'lfo-invalid',
                  'type': 'lfo',
                  'lfoConfig': <String, dynamic>{'frequency': 0.0, 'depth': -1.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': '',
                      'amount': double.nan,
                      'minValue': double.nan,
                      'maxValue': double.nan,
                    },
                  ],
                },
                <String, dynamic>{
                  'id': 'random-missing',
                  'type': 'random',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].pan'},
                  ],
                },
                <String, dynamic>{
                  'id': 'random-invalid',
                  'type': 'random',
                  'randomConfig': <String, dynamic>{'rateHz': 0.0, 'smooth': 2.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].gain', 'minValue': 1.0, 'maxValue': 0.0},
                  ],
                },
                <String, dynamic>{
                  'id': 'drift-missing',
                  'type': 'drift',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].pan'},
                  ],
                },
                <String, dynamic>{
                  'id': 'drift-invalid',
                  'type': 'drift',
                  'driftConfig': <String, dynamic>{'speed': -1.0, 'range': -2.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].gain'},
                  ],
                },
                <String, dynamic>{
                  'id': 'env-missing',
                  'type': 'envelope',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].pan'},
                  ],
                },
                <String, dynamic>{
                  'id': 'env-invalid',
                  'type': 'envelope',
                  'envelopeConfig': <String, dynamic>{
                    'attackMs': -1,
                    'decayMs': -1,
                    'releaseMs': -1,
                    'sustain': 1.5,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].gain'},
                  ],
                },
                <String, dynamic>{
                  'id': 'burst-missing',
                  'type': 'burst',
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].pan'},
                  ],
                },
                <String, dynamic>{
                  'id': 'burst-invalid',
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
                    <String, dynamic>{'path': 'layers[layer-rules].gain'},
                  ],
                },
                <String, dynamic>{
                  'id': 'unknown-target',
                  'type': 'lfo',
                  'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].processors[missing].gain.gain'},
                  ],
                },
                <String, dynamic>{
                  'id': 'mod-existing',
                  'type': 'lfo',
                  'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-rules].gain'},
                  ],
                },
              ],
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': '',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 0.0},
                  'actions': <Map<String, dynamic>>[],
                },
                <String, dynamic>{
                  'id': 'event-empty-mod',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 1.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{'modulatorId': '', 'mode': 'trigger'},
                  ],
                },
                <String, dynamic>{
                  'id': 'event-missing-mod-ref',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 1.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{'modulatorId': 'does-not-exist', 'mode': 'trigger'},
                  ],
                },
              ],
            },
          ],
        ),
      );

      final issuePaths = error.issues.map((issue) => issue.path).toSet();
      final issueMessages = error.issues.map((issue) => issue.message).toSet();

      expect(issuePaths.contains('layers[0].source.noiseConfig'), isTrue);
      expect(issuePaths.contains('layers[1].source.impulseConfig.density'), isTrue);
      expect(issuePaths.contains('layers[1].source.impulseConfig.randomness'), isTrue);
      expect(issuePaths.contains('layers[2].source.sineConfig'), isTrue);
      expect(issuePaths.contains('layers[3].source.noiseConfig.band.low'), isTrue);
      expect(issuePaths.contains('layers[3].source.noiseConfig.band.high'), isTrue);
      expect(issuePaths.contains('layers[3].processors[0].id'), isTrue);
      expect(issuePaths.contains('layers[3].processors[1].biquad'), isTrue);
      expect(issuePaths.contains('layers[3].processors[2].biquad.frequency'), isTrue);
      expect(issuePaths.contains('layers[3].processors[2].biquad.q'), isTrue);
      expect(issuePaths.contains('layers[3].processors[3].gain'), isTrue);
      expect(issuePaths.contains('layers[3].processors[4].saturator'), isTrue);
      expect(issuePaths.contains('layers[3].processors[5].saturator.drive'), isTrue);
      expect(issuePaths.contains('layers[3].processors[6].delay'), isTrue);
      expect(issuePaths.contains('layers[3].processors[7].delay.delayTimeMs'), isTrue);
      expect(issuePaths.contains('layers[3].processors[7].delay.feedback'), isTrue);
      expect(issuePaths.contains('layers[3].processors[7].delay.mix'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[0].id'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[0].amount'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[0].targets'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[1].lfoConfig'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].targets[0].path'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].targets[0].amount'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].targets[0].minValue'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].targets[0].maxValue'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].lfoConfig.frequency'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[2].lfoConfig.depth'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[4].targets[0]'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[4].randomConfig.rateHz'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[4].randomConfig.smooth'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[5].driftConfig'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[6].driftConfig.speed'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[6].driftConfig.range'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[7].envelopeConfig'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[8].envelopeConfig.attackMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[8].envelopeConfig.decayMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[8].envelopeConfig.releaseMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[8].envelopeConfig.sustain'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[9].burstConfig'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.durationMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.intensity'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.randomness'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.attackMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.releaseMs'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.clusterMin'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.clusterMax'), isTrue);
      expect(issuePaths.contains('layers[3].modulations[10].burstConfig.clusterSpreadMs'), isTrue);
      expect(issuePaths.contains('layers[3].events[0].id'), isTrue);
      expect(issuePaths.contains('layers[3].events[0].trigger.rate'), isTrue);
      expect(issuePaths.contains('layers[3].events[0].actions'), isTrue);
      expect(issuePaths.contains('layers[3].events[1].actions[0].modulatorId'), isTrue);
      expect(issuePaths.contains('layers[3].events[2].actions[0].modulatorId'), isTrue);
      expect(
        issueMessages.any((message) => message.contains('unknown modulation target path')),
        isTrue,
      );
    });

    test('validation rejects cross-layer modulation targets', () {
      final parser = GenerationConfigParser();

      final error = _expectValidationFailure(
        parser,
        _validRoot(
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-a',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 220, 'phase': 0},
              },
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'mod-1',
                  'type': 'lfo',
                  'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[layer-b].pan'},
                  ],
                },
              ],
            },
            <String, dynamic>{
              'id': 'layer-b',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 330, 'phase': 0},
              },
            },
          ],
        ),
      );

      expect(
        error.issues.any(
          (issue) => issue.path == 'layers[0].modulations[0].targets[0].path',
        ),
        isTrue,
      );
    });

    test('validation rejects targets for inactive processor branches', () {
      final parser = GenerationConfigParser();

      final error = _expectValidationFailure(
        parser,
        _validRoot(
          layers: <Map<String, dynamic>>[
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
                  'id': 'mod-1',
                  'type': 'lfo',
                  'lfoConfig': <String, dynamic>{'frequency': 1.0, 'depth': 1.0},
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': 'layers[layer-a].processors[gain-1].delay.mix',
                    },
                  ],
                },
              ],
            },
          ],
        ),
      );

      expect(
        error.issues.any(
          (issue) => issue.path == 'layers[0].modulations[0].targets[0].path',
        ),
        isTrue,
      );
    });
  });
}
