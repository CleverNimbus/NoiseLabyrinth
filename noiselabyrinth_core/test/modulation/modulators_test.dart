import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

const _smokeTag = <String>['smoke'];
const _qualityTag = <String>['quality'];

void main() {
  group('modulators smoke', () {
    test(
      'LfoSineModulator fills control buffer through Modulator interface',
      () {
        final Modulator modulator = LfoSineModulator(
          sampleRate: 1000,
          frequency: 5,
          depth: 1,
        );

        final buffer = Float32List(1000);
        modulator.process(1000, buffer);

        final allZero = buffer.every((sample) => sample == 0.0);
        expect(allZero, isFalse);

        final peak = buffer.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
        final mean = buffer.reduce((a, b) => a + b) / buffer.length;
        final rms = math.sqrt(
          buffer.fold<double>(0, (sum, v) => sum + v * v) / buffer.length,
        );
        var zeroCrossings = 0;
        for (var i = 1; i < buffer.length; i++) {
          if ((buffer[i - 1] <= 0 && buffer[i] > 0) || (buffer[i - 1] >= 0 && buffer[i] < 0)) {
            zeroCrossings++;
          }
        }

        expect(peak, closeTo(1.0, 0.05));
        expect(mean.abs(), lessThan(0.05));
        expect(rms, closeTo(math.sqrt(0.5), 0.06));
        expect(zeroCrossings, closeTo(10, 2));
      },
      tags: _smokeTag,
    );
  });

  group('modulators quality', () {
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
        var lag1 = 0.0;
        var energy = 0.0;
        for (var i = 1; i < buffer.length; i++) {
          final delta = (buffer[i] - buffer[i - 1]).abs();
          if (delta > maxDelta) {
            maxDelta = delta;
          }
          lag1 += buffer[i] * buffer[i - 1];
          energy += buffer[i] * buffer[i];
        }
        expect(maxDelta, lessThan(0.2));
        expect(lag1 / (energy + 1e-12), greaterThan(0.7));
      },
      tags: _qualityTag,
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
      expect(attackDecay[10], greaterThanOrEqualTo(attackDecay[9]));
      expect(attackDecay[30], lessThanOrEqualTo(attackDecay[20]));

      envelope.reset();
      final released = Float32List(40);
      envelope.process(40, released);
      expect(released.last, closeTo(0.0, 1e-6));
      expect(released[0], lessThanOrEqualTo(0.4));
    }, tags: _qualityTag);

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
      expect(active.where((s) => s > 0.0).length, lessThanOrEqualTo(20));

      burst.reset();
      final resetBuffer = Float32List(10);
      burst.process(10, resetBuffer);
      expect(resetBuffer.every((sample) => sample == 0.0), isTrue);
    }, tags: _qualityTag);

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
      expect((first.first - second.first).abs(), greaterThan(0.05));
    }, tags: _qualityTag);

    test('BurstModulator supports clustered trigger behavior', () {
      final burst = BurstModulator(
        sampleRate: 1000,
        durationMs: 40,
        intensity: 1,
        randomness: 0,
        attackMs: 0,
        releaseMs: 40,
        clusterMin: 3,
        clusterMax: 3,
        clusterSpreadMs: 30,
      )..trigger();
      final buffer = Float32List(120);
      burst.process(120, buffer);

      final nonZeroCount = buffer.where((sample) => sample > 0.0).length;
      expect(nonZeroCount, greaterThan(50));
      expect(buffer.take(10).any((sample) => sample > 0.0), isTrue);
      expect(buffer.skip(25).take(25).any((sample) => sample > 0.0), isTrue);
      expect(buffer.skip(55).take(35).any((sample) => sample > 0.0), isTrue);
    }, tags: _qualityTag);

    test('DriftModulator stays bounded and evolves over time', () {
      final drift = DriftModulator(sampleRate: 1000, speed: 30, range: 0.25);

      final buffer = Float32List(256);
      drift.process(256, buffer);

      final minValue = buffer.reduce((a, b) => a < b ? a : b);
      final maxValue = buffer.reduce((a, b) => a > b ? a : b);
      expect(minValue, greaterThanOrEqualTo(-0.25));
      expect(maxValue, lessThanOrEqualTo(0.25));

      final unique = buffer.toSet().length;
      expect(unique, greaterThan(8));

      var avgDelta = 0.0;
      for (var i = 1; i < buffer.length; i++) {
        avgDelta += (buffer[i] - buffer[i - 1]).abs();
      }
      avgDelta /= buffer.length - 1;
      expect(avgDelta, lessThan(0.03));

      drift.reset();
      final resetBuffer = Float32List(64);
      drift.process(64, resetBuffer);
      final resetPeak = resetBuffer.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
      expect(resetPeak, lessThanOrEqualTo(0.25));
    }, tags: _qualityTag);
  });

  group('modulators with events', () {
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
                  'decayMs': 20,
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
      expect(distinct, greaterThanOrEqualTo(5));
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
                  'durationMs': 50,
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
  });
}
