import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

import '../test_helpers/modulators_test_helpers.dart';

const _qualityTag = <String>['quality'];

Float32List _renderMono(
  Map<String, dynamic> root, {
  required int sampleRate,
  required int totalSamples,
  int blockSize = 256,
}) {
  final parser = GenerationConfigParser();
  final builder = RuntimeGraphBuilder(sampleRate: sampleRate);

  final config = parser.parseJsonMap(root);
  final graph = builder.build(config);
  final engine = AudioEngine(
    graph: graph,
    sampleRate: sampleRate,
    blockSize: blockSize,
  );

  return engine.renderSamples(totalSamples: totalSamples);
}

Map<String, dynamic> _rootConfig({
  required String name,
  required int sampleRate,
  required List<Map<String, dynamic>> layers,
}) {
  return <String, dynamic>{
    'metadata': <String, dynamic>{'name': name},
    'render': <String, dynamic>{
      'durationMinutes': 1,
      'sampleRate': sampleRate,
      'bitRate': 128,
    },
    'mix': <String, dynamic>{'mix': 1.0},
    'layers': layers,
  };
}

double _peakFrequencyHz(WelchPsdResult psd) {
  var peakBin = 0;
  var peakPower = -double.infinity;
  for (var i = 0; i < psd.power.length; i++) {
    if (psd.power[i] > peakPower) {
      peakPower = psd.power[i];
      peakBin = i;
    }
  }
  return psd.frequenciesHz[peakBin];
}

Float32List _renderFromConfig(
  GenerationConfig config, {
  required int totalSamples,
  int blockSize = 256,
}) {
  final builder = RuntimeGraphBuilder(sampleRate: config.render.sampleRate);
  final graph = builder.build(config);
  final engine = AudioEngine(
    graph: graph,
    sampleRate: config.render.sampleRate,
    blockSize: blockSize,
  );
  return engine.renderSamples(totalSamples: totalSamples);
}

double _peakAbs(Float32List samples) {
  var peak = 0.0;
  for (final sample in samples) {
    final abs = sample.abs();
    if (abs > peak) {
      peak = abs;
    }
  }
  return peak;
}

double _normalizedAutocorrelation(Float32List samples, int lag) {
  var mean = 0.0;
  for (final s in samples) {
    mean += s;
  }
  mean /= samples.length;

  var variance = 0.0;
  for (final s in samples) {
    final c = s - mean;
    variance += c * c;
  }
  if (variance == 0.0) {
    return 0;
  }

  var covariance = 0.0;
  final n = samples.length - lag;
  for (var i = 0; i < n; i++) {
    covariance += (samples[i] - mean) * (samples[i + lag] - mean);
  }
  return covariance / variance;
}

double _powerNearFrequency(
  WelchPsdResult psd,
  double targetHz, {
  double halfWidthHz = 4.0,
}) {
  var power = 0.0;
  for (var i = 0; i < psd.frequenciesHz.length; i++) {
    final f = psd.frequenciesHz[i];
    if ((f - targetHz).abs() <= halfWidthHz) {
      power += psd.power[i];
    }
  }
  return power;
}

void main() {
  group('audio metrics engine validation', () {
    test('sine render is tonal, stable, and unclipped', () {
      const sampleRate = 8000;
      final samples = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Sine',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'sine-layer',
              'gain': 1.0,
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{
                  'frequencyHz': 440,
                  'phase': 0.0,
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 16384,
      );

      final psd = computeWelchPsd(
        samples,
        sampleRate: sampleRate,
        segmentLength: 1024,
      );
      final rms = computeRmsMeanVariance(
        samples,
        windowSize: 512,
        hopSize: 512,
      );
      final crest = computeCrestFactor(samples);
      final flatness = computeSpectralFlatness(
        psd,
        minFrequencyHz: 20,
        maxFrequencyHz: 3500,
      );
      final clipping = analyzeClippingAndDcOffset(
        samples,
        clipThreshold: 1.0001,
        dcOffsetThreshold: 0.02,
      );

      expect(_peakFrequencyHz(psd), closeTo(440.0, 8.0));
      expect(rms.mean, closeTo(0.707, 0.05));
      expect(rms.variance, lessThan(0.002));
      expect(crest, closeTo(math.sqrt(2.0), 0.08));
      expect(flatness, lessThan(0.15));
      expect(clipping.hasClipping, isFalse);
      expect(clipping.dcOffset.abs(), lessThan(0.05));
    });

    test('brown noise render is darker than white noise by spectral metrics', () {
      const sampleRate = 8000;
      final white = _renderMono(
        _rootConfig(
          name: 'Engine Metrics White',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'white-layer',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32768,
      );
      final brown = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Brown',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'brown-layer',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'brown',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32768,
      );

      final whitePsd = computeWelchPsd(
        white,
        sampleRate: sampleRate,
        segmentLength: 2048,
      );
      final brownPsd = computeWelchPsd(
        brown,
        sampleRate: sampleRate,
        segmentLength: 2048,
      );

      final whiteSlope = computeSpectralSlope(
        whitePsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );
      final brownSlope = computeSpectralSlope(
        brownPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );
      final whiteBands = computeBandEnergyRatios(
        whitePsd,
        const <FrequencyBand>[
          FrequencyBand(label: 'low', lowHz: 50, highHz: 400),
          FrequencyBand(label: 'mid', lowHz: 400, highHz: 1500),
          FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
        ],
      );
      final brownBands = computeBandEnergyRatios(
        brownPsd,
        const <FrequencyBand>[
          FrequencyBand(label: 'low', lowHz: 50, highHz: 400),
          FrequencyBand(label: 'mid', lowHz: 400, highHz: 1500),
          FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
        ],
      );
      final whiteFlatness = computeSpectralFlatness(
        whitePsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );
      final brownFlatness = computeSpectralFlatness(
        brownPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );

      expect(brownSlope, lessThan(whiteSlope - 0.5));
      expect(brownBands['low'], greaterThan(whiteBands['low']!));
      expect(brownBands['high'], lessThan(whiteBands['high']!));
      expect(brownFlatness, lessThan(whiteFlatness));
    });

    test('low-pass filtered noise shifts energy downward and reduces flatness', () {
      const sampleRate = 8000;
      final unfiltered = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Raw White',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'white-layer',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32768,
      );
      final filtered = _renderMono(
        _rootConfig(
          name: 'Engine Metrics LP White',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'lp-layer',
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
        ),
        sampleRate: sampleRate,
        totalSamples: 32768,
      );

      final rawPsd = computeWelchPsd(
        unfiltered,
        sampleRate: sampleRate,
        segmentLength: 2048,
      );
      final filteredPsd = computeWelchPsd(
        filtered,
        sampleRate: sampleRate,
        segmentLength: 2048,
      );
      final rawBands = computeBandEnergyRatios(
        rawPsd,
        const <FrequencyBand>[
          FrequencyBand(label: 'low', lowHz: 50, highHz: 400),
          FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
        ],
      );
      final filteredBands = computeBandEnergyRatios(
        filteredPsd,
        const <FrequencyBand>[
          FrequencyBand(label: 'low', lowHz: 50, highHz: 400),
          FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
        ],
      );
      final rawFlatness = computeSpectralFlatness(
        rawPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );
      final filteredFlatness = computeSpectralFlatness(
        filteredPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: 3000,
      );

      expect(filteredBands['low'], greaterThan(rawBands['low']!));
      expect(filteredBands['high'], lessThan(rawBands['high']! * 0.5));
      expect(filteredFlatness, lessThan(rawFlatness));
    });

    test('gain LFO increases RMS variance relative to a static sine render', () {
      const sampleRate = 8000;
      final staticSine = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Static Sine',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'static-layer',
              'gain': 0.5,
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{
                  'frequencyHz': 440,
                  'phase': 0.0,
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32000,
      );
      final modulatedSine = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Modulated Sine',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'mod-layer',
              'gain': 0.5,
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{
                  'frequencyHz': 440,
                  'phase': 0.0,
                },
              },
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'gain-lfo',
                  'type': 'lfo',
                  'amount': 0.35,
                  'lfoConfig': <String, dynamic>{
                    'type': 'sine',
                    'frequency': 2.0,
                    'depth': 1.0,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': 'layers[mod-layer].gain',
                      'amount': 1.0,
                    },
                  ],
                },
              ],
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32000,
      );

      final staticRms = computeRmsMeanVariance(
        staticSine,
        windowSize: 400,
        hopSize: 400,
      );
      final modulatedRms = computeRmsMeanVariance(
        modulatedSine,
        windowSize: 400,
        hopSize: 400,
      );

      expect(modulatedRms.variance, greaterThan(staticRms.variance * 20.0));
      expect(modulatedRms.mean, greaterThan(staticRms.mean * 0.7));
      expect(modulatedRms.mean, lessThan(staticRms.mean * 1.3));
    });

    test('hot sine render is detected as clipped without meaningful DC offset', () {
      const sampleRate = 8000;
      final samples = _renderMono(
        _rootConfig(
          name: 'Engine Metrics Hot Sine',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'hot-layer',
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{
                  'frequencyHz': 220,
                  'phase': 0.0,
                },
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
        ),
        sampleRate: sampleRate,
        totalSamples: 8192,
      );

      final clipping = analyzeClippingAndDcOffset(
        samples,
        clipThreshold: 1,
        dcOffsetThreshold: 0.02,
      );
      final crest = computeCrestFactor(samples);

      expect(clipping.hasClipping, isTrue);
      expect(clipping.clippedRatio, greaterThan(0.25));
      expect(clipping.hasDcOffset, isFalse);
      expect(crest, lessThan(math.sqrt(2.0)));
    });

    test('white/mid/brown profiles match DSP-standard spectral identities', () {
      const sampleRate = 8000;
      final white = _renderMono(
        _rootConfig(
          name: 'Std White',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'white',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );
      final mid = _renderMono(
        _rootConfig(
          name: 'Std Mid',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'mid',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'bandlimited',
                  'band': <String, dynamic>{'low': 400, 'high': 1200},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );
      final brown = _renderMono(
        _rootConfig(
          name: 'Std Brown',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'brown',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'brown',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );

      final whitePsd = computeWelchPsd(white, sampleRate: sampleRate, segmentLength: 2048);
      final midPsd = computeWelchPsd(mid, sampleRate: sampleRate, segmentLength: 2048);
      final brownPsd = computeWelchPsd(brown, sampleRate: sampleRate, segmentLength: 2048);

      final whiteSlope = computeSpectralSlope(whitePsd, minFrequencyHz: 50, maxFrequencyHz: 3000);
      final brownSlope = computeSpectralSlope(brownPsd, minFrequencyHz: 50, maxFrequencyHz: 3000);

      final whiteBands = computeBandEnergyRatios(whitePsd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 80, highHz: 500),
        FrequencyBand(label: 'mid', lowHz: 500, highHz: 1500),
        FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
      ]);
      final midBands = computeBandEnergyRatios(midPsd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 80, highHz: 350),
        FrequencyBand(label: 'mid', lowHz: 500, highHz: 1200),
        FrequencyBand(label: 'high', lowHz: 1800, highHz: 3000),
      ]);
      final brownBands = computeBandEnergyRatios(brownPsd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 80, highHz: 500),
        FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
      ]);

      final whiteFlatness = computeSpectralFlatness(whitePsd, minFrequencyHz: 50, maxFrequencyHz: 3000);
      final midFlatness = computeSpectralFlatness(midPsd, minFrequencyHz: 50, maxFrequencyHz: 3000);
      final brownFlatness = computeSpectralFlatness(brownPsd, minFrequencyHz: 50, maxFrequencyHz: 3000);

      expect(whiteSlope, closeTo(0.0, 0.35));
      expect(whiteBands['low'], greaterThan(0.13));
      expect(whiteBands['high'], greaterThan(0.13));
      expect(whiteFlatness, greaterThan(0.45));

      expect(midBands['mid'], greaterThan(midBands['low']! * 1.4));
      expect(midBands['mid'], greaterThan(midBands['high']! * 1.6));
      expect(midFlatness, lessThan(whiteFlatness));

      expect(brownSlope, lessThan(-0.8));
      expect(brownBands['low'], greaterThan(brownBands['high']! * 2.0));
      expect(brownFlatness, lessThan(whiteFlatness));
    }, tags: _qualityTag);

    test('event-driven burst modulation produces strong transient dynamics', () {
      const sampleRate = 8000;
      final staticNoise = _renderMono(
        _rootConfig(
          name: 'Static Noise',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-static',
              'gain': 0.6,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32000,
      );
      final burstyNoise = _renderMono(
        _rootConfig(
          name: 'Bursty Noise',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'layer-burst',
              'gain': 0.3,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'burst-1',
                  'type': 'burst',
                  'amount': 1.0,
                  'burstConfig': <String, dynamic>{
                    'durationMs': 60,
                    'intensity': 1.0,
                    'randomness': 0.2,
                    'attackMs': 0,
                    'releaseMs': 45,
                    'clusterMin': 1,
                    'clusterMax': 2,
                    'clusterSpreadMs': 20,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'path': 'layers[layer-burst].gain',
                      'amount': 1.0,
                    },
                  ],
                },
              ],
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'evt-burst',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 8.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{'modulatorId': 'burst-1', 'mode': 'trigger'},
                  ],
                },
              ],
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32000,
      );

      final staticRms = computeRmsMeanVariance(staticNoise, windowSize: 400, hopSize: 400);
      final burstRms = computeRmsMeanVariance(burstyNoise, windowSize: 400, hopSize: 400);
      final staticCrest = computeCrestFactor(staticNoise);
      final burstCrest = computeCrestFactor(burstyNoise);

      expect(burstRms.variance, greaterThan(staticRms.variance * 3.0));
      expect(burstCrest, greaterThan(staticCrest * 1.15));
    }, tags: _qualityTag);

    test('normalization reaches target dBFS while preserving spectral character', () {
      const sampleRate = 8000;
      final baseRoot = _rootConfig(
        name: 'Normalization Base',
        sampleRate: sampleRate,
        layers: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-a',
            'gain': 0.2,
            'source': <String, dynamic>{
              'type': 'noise',
              'noiseConfig': <String, dynamic>{
                'color': 'white',
                'band': <String, dynamic>{'low': 20, 'high': 3800},
              },
            },
          },
        ],
      );
      final withoutNorm = _renderMono(
        baseRoot,
        sampleRate: sampleRate,
        totalSamples: 32768,
      );
      final withNorm = _renderMono(
        <String, dynamic>{
          ...baseRoot,
          'mix': <String, dynamic>{
            'mix': 1.0,
            'normalization': <String, dynamic>{'enabled': true, 'targetDb': -6.0},
          },
        },
        sampleRate: sampleRate,
        totalSamples: 32768,
      );

      final rawPeak = _peakAbs(withoutNorm);
      final normPeak = _peakAbs(withNorm);
      final targetPeak = math.pow(10.0, -6.0 / 20.0).toDouble();

      final rawPsd = computeWelchPsd(withoutNorm, sampleRate: sampleRate, segmentLength: 2048);
      final normPsd = computeWelchPsd(withNorm, sampleRate: sampleRate, segmentLength: 2048);
      final rawSlope = computeSpectralSlope(rawPsd, minFrequencyHz: 50, maxFrequencyHz: 3000);
      final normSlope = computeSpectralSlope(normPsd, minFrequencyHz: 50, maxFrequencyHz: 3000);

      expect((normPeak - rawPeak).abs(), greaterThan(0.05));
      expect(normPeak, closeTo(targetPeak, 0.03));
      expect((normSlope - rawSlope).abs(), lessThan(0.15));
    }, tags: _qualityTag);

    test('dithering injects broadband decorrelated residual noise floor', () {
      const sampleRate = 8000;
      final baseRoot = _rootConfig(
        name: 'Dither Base',
        sampleRate: sampleRate,
        layers: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'layer-sine',
            'gain': 0.3,
            'source': <String, dynamic>{
              'type': 'sine',
              'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
            },
          },
        ],
      );

      final dry = _renderMono(baseRoot, sampleRate: sampleRate, totalSamples: 32768);
      final dithered = _renderMono(
        <String, dynamic>{
          ...baseRoot,
          'mix': <String, dynamic>{
            'mix': 1.0,
            'dither': <String, dynamic>{'enabled': true, 'type': 'tpdf', 'bitDepth': 16, 'amount': 1.0},
          },
        },
        sampleRate: sampleRate,
        totalSamples: 32768,
      );

      final residual = Float32List(dry.length);
      for (var i = 0; i < dry.length; i++) {
        residual[i] = dithered[i] - dry[i];
      }

      final residualRms = math.sqrt(
        residual.fold<double>(0, (sum, s) => sum + s * s) / residual.length,
      );
      final residualMean = residual.fold<double>(0, (sum, s) => sum + s) / residual.length;
      final residualPsd = computeWelchPsd(residual, sampleRate: sampleRate, segmentLength: 2048);
      final residualFlatness = computeSpectralFlatness(
        residualPsd,
        minFrequencyHz: 100,
        maxFrequencyHz: 3000,
      );

      expect(residualRms, greaterThan(1e-6));
      expect(residualMean.abs(), lessThan(1e-3));
      expect(residualFlatness, greaterThan(0.45));
    }, tags: _qualityTag);

    test('mixing and generation merge preserve predictable spectral behavior', () {
      const sampleRate = 8000;
      final merger = GenerationsMerger(parser: GenerationConfigParser());

      final merged = merger.merge(whiteNoiseProfile, brownNoiseProfile);
      final mergedSamples = _renderFromConfig(merged, totalSamples: 65536);
      final whiteSamples = _renderFromConfig(whiteNoiseProfile, totalSamples: 65536);
      final brownSamples = _renderFromConfig(brownNoiseProfile, totalSamples: 65536);

      final mergedPsd = computeWelchPsd(mergedSamples, sampleRate: merged.render.sampleRate, segmentLength: 2048);
      final whitePsd = computeWelchPsd(
        whiteSamples,
        sampleRate: whiteNoiseProfile.render.sampleRate,
        segmentLength: 2048,
      );
      final brownPsd = computeWelchPsd(
        brownSamples,
        sampleRate: brownNoiseProfile.render.sampleRate,
        segmentLength: 2048,
      );

      final mergedSlope = computeSpectralSlope(mergedPsd, minFrequencyHz: 80, maxFrequencyHz: 8000);
      final whiteSlope = computeSpectralSlope(whitePsd, minFrequencyHz: 80, maxFrequencyHz: 8000);
      final brownSlope = computeSpectralSlope(brownPsd, minFrequencyHz: 80, maxFrequencyHz: 8000);

      expect(mergedSlope, lessThan(whiteSlope));
      expect(mergedSlope, greaterThan(brownSlope));

      final mixCompare = _renderMono(
        _rootConfig(
          name: 'Mix Compare',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'low-layer',
              'gain': 0.8,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'bandlimited',
                  'band': <String, dynamic>{'low': 80, 'high': 350},
                },
              },
            },
            <String, dynamic>{
              'id': 'high-layer',
              'gain': 0.2,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'bandlimited',
                  'band': <String, dynamic>{'low': 1800, 'high': 3200},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );
      final mixPsd = computeWelchPsd(mixCompare, sampleRate: sampleRate, segmentLength: 2048);
      final mixBands = computeBandEnergyRatios(mixPsd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 80, highHz: 500),
        FrequencyBand(label: 'high', lowHz: 1800, highHz: 3200),
      ]);
      expect(mixBands['low'], greaterThan(mixBands['high']! * 1.5));
    }, tags: _qualityTag);

    test('white-noise implementation conforms to whiteness invariants', () {
      const sampleRate = 8000;
      final samples = _renderMono(
        _rootConfig(
          name: 'White Conformance',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'white-conformance',
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 131072,
      );

      final psd = computeWelchPsd(samples, sampleRate: sampleRate, segmentLength: 2048);
      final slope = computeSpectralSlope(psd, minFrequencyHz: 80, maxFrequencyHz: 3000);
      final flatness = computeSpectralFlatness(psd, minFrequencyHz: 80, maxFrequencyHz: 3000);

      final bands = computeBandEnergyRatios(psd, const <FrequencyBand>[
        FrequencyBand(label: 'b1', lowHz: 80, highHz: 600),
        FrequencyBand(label: 'b2', lowHz: 600, highHz: 1200),
        FrequencyBand(label: 'b3', lowHz: 1200, highHz: 2000),
        FrequencyBand(label: 'b4', lowHz: 2000, highHz: 3000),
      ]);

      final minBand = bands.values.reduce((a, b) => a < b ? a : b);
      final maxBand = bands.values.reduce((a, b) => a > b ? a : b);
      final bandSpreadDb = 10.0 * math.log(maxBand / minBand) / math.ln10;

      var maxLagCorr = 0.0;
      for (var lag = 1; lag <= 32; lag++) {
        final corr = _normalizedAutocorrelation(samples, lag).abs();
        if (corr > maxLagCorr) {
          maxLagCorr = corr;
        }
      }

      expect(slope, closeTo(0.0, 0.3));
      expect(flatness, greaterThan(0.5));
      expect(bandSpreadDb, lessThan(4.0));
      expect(maxLagCorr, lessThan(0.08));
    }, tags: _qualityTag);

    test('gain LFO modulation creates expected AM sidebands', () {
      const sampleRate = 8000;
      final staticSine = _renderMono(
        _rootConfig(
          name: 'AM Static',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tone-static',
              'gain': 0.5,
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );
      final amSine = _renderMono(
        _rootConfig(
          name: 'AM Modulated',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'tone-am',
              'gain': 0.5,
              'source': <String, dynamic>{
                'type': 'sine',
                'sineConfig': <String, dynamic>{'frequencyHz': 440, 'phase': 0.0},
              },
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'lfo-gain',
                  'type': 'lfo',
                  'amount': 0.35,
                  'lfoConfig': <String, dynamic>{
                    'type': 'sine',
                    'frequency': 2.0,
                    'depth': 1.0,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[tone-am].gain', 'amount': 1.0},
                  ],
                },
              ],
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 65536,
      );

      final staticPsd = computeWelchPsd(staticSine, sampleRate: sampleRate, segmentLength: 4096);
      final amPsd = computeWelchPsd(amSine, sampleRate: sampleRate, segmentLength: 4096);

      final carrier = _powerNearFrequency(amPsd, 440);
      final lowerSidebandAm = _powerNearFrequency(amPsd, 438);
      final upperSidebandAm = _powerNearFrequency(amPsd, 442);
      final lowerSidebandStatic = _powerNearFrequency(staticPsd, 438);
      final upperSidebandStatic = _powerNearFrequency(staticPsd, 442);

      final sidebandSymmetry = lowerSidebandAm / (upperSidebandAm + 1e-12);
      final staticCarrier = _powerNearFrequency(staticPsd, 440);
      final amSidebandRatio = (lowerSidebandAm + upperSidebandAm) / (carrier + 1e-12);
      final staticSidebandRatio = (lowerSidebandStatic + upperSidebandStatic) / (staticCarrier + 1e-12);

      expect(carrier, greaterThan(1e-6));
      expect(sidebandSymmetry, greaterThan(0.5));
      expect(sidebandSymmetry, lessThan(2.0));
      expect(amSidebandRatio, greaterThan(staticSidebandRatio * 0.95));
      expect(amSidebandRatio, greaterThan(0.08));
    }, tags: _qualityTag);

    test('normalization behaves as near-constant linear gain in unclipped region', () {
      const sampleRate = 8000;
      final base = _renderMono(
        _rootConfig(
          name: 'Norm Linearity Base',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'norm-lin',
              'gain': 0.25,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 32768,
      );
      final normalized = _renderMono(
        <String, dynamic>{
          ..._rootConfig(
            name: 'Norm Linearity Enabled',
            sampleRate: sampleRate,
            layers: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'norm-lin',
                'gain': 0.25,
                'source': <String, dynamic>{
                  'type': 'noise',
                  'noiseConfig': <String, dynamic>{
                    'color': 'white',
                    'band': <String, dynamic>{'low': 20, 'high': 3800},
                  },
                },
              },
            ],
          ),
          'mix': <String, dynamic>{
            'mix': 1.0,
            'normalization': <String, dynamic>{'enabled': true, 'targetDb': -6.0},
          },
        },
        sampleRate: sampleRate,
        totalSamples: 32768,
      );

      final ratios = <double>[];
      for (var i = 0; i < base.length; i++) {
        final x = base[i];
        final y = normalized[i];
        if (x.abs() > 0.02 && y.abs() < 0.95) {
          ratios.add(y / x);
        }
      }

      var mean = 0.0;
      for (final r in ratios) {
        mean += r;
      }
      mean /= ratios.length;

      var variance = 0.0;
      for (final r in ratios) {
        final d = r - mean;
        variance += d * d;
      }
      variance /= ratios.length;
      final stdDev = math.sqrt(variance);

      expect(ratios.length, greaterThan(8000));
      expect(mean, greaterThan(1.2));
      expect(stdDev / mean.abs(), lessThan(0.08));
    }, tags: _qualityTag);

    test('periodic events leave periodic envelope fingerprint in RMS series', () {
      const sampleRate = 8000;
      final burstyNoise = _renderMono(
        _rootConfig(
          name: 'Periodic Envelope Fingerprint',
          sampleRate: sampleRate,
          layers: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'evt-layer',
              'gain': 0.25,
              'source': <String, dynamic>{
                'type': 'noise',
                'noiseConfig': <String, dynamic>{
                  'color': 'white',
                  'band': <String, dynamic>{'low': 20, 'high': 3800},
                },
              },
              'modulations': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'evt-burst',
                  'type': 'burst',
                  'amount': 1.0,
                  'burstConfig': <String, dynamic>{
                    'durationMs': 40,
                    'intensity': 1.0,
                    'randomness': 0.0,
                    'attackMs': 0,
                    'releaseMs': 40,
                    'clusterMin': 1,
                    'clusterMax': 1,
                    'clusterSpreadMs': 0,
                  },
                  'targets': <Map<String, dynamic>>[
                    <String, dynamic>{'path': 'layers[evt-layer].gain', 'amount': 1.0},
                  ],
                },
              ],
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'evt-periodic',
                  'trigger': <String, dynamic>{'type': 'periodic', 'rate': 10.0},
                  'actions': <Map<String, dynamic>>[
                    <String, dynamic>{'modulatorId': 'evt-burst', 'mode': 'trigger'},
                  ],
                },
              ],
            },
          ],
        ),
        sampleRate: sampleRate,
        totalSamples: 64000,
      );

      final rms = computeRmsMeanVariance(burstyNoise, windowSize: 400, hopSize: 400).values;
      final rmsAsF32 = Float32List(rms.length);
      for (var i = 0; i < rms.length; i++) {
        rmsAsF32[i] = rms[i];
      }

      // 10 Hz events and 20 RMS frames/s => period ~2 frames.
      final corrLag2 = _normalizedAutocorrelation(rmsAsF32, 2);
      final corrLag1 = _normalizedAutocorrelation(rmsAsF32, 1);

      expect(corrLag2, greaterThan(0.15));
      expect(corrLag2, greaterThan(corrLag1));
    }, tags: _qualityTag);
  });
}
