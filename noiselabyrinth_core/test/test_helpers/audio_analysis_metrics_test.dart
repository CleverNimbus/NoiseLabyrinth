import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'modulators_test_helpers.dart';

Float32List _sine({
  required int length,
  required double sampleRate,
  required double frequencyHz,
  double amplitude = 1.0,
  double dcOffset = 0.0,
}) {
  final out = Float32List(length);
  for (var i = 0; i < length; i++) {
    out[i] = amplitude * math.sin(2.0 * math.pi * frequencyHz * i / sampleRate) + dcOffset;
  }
  return out;
}

Float32List _whiteNoise({required int length, int seed = 42}) {
  final random = math.Random(seed);
  final out = Float32List(length);
  for (var i = 0; i < length; i++) {
    out[i] = random.nextDouble() * 2.0 - 1.0;
  }
  return out;
}

Float32List _brownNoise({required int length, int seed = 42}) {
  final random = math.Random(seed);
  final out = Float32List(length);

  var state = 0.0;
  for (var i = 0; i < length; i++) {
    final white = random.nextDouble() * 2.0 - 1.0;
    state += white;
    out[i] = state;
  }

  var peak = 0.0;
  for (final sample in out) {
    peak = math.max(peak, sample.abs());
  }
  final scale = peak > 0.0 ? 1.0 / peak : 1.0;
  for (var i = 0; i < out.length; i++) {
    out[i] *= scale;
  }

  return out;
}

Float32List _singleSegmentRectangularPsd(
  Float32List samples, {
  required int sampleRate,
  required int segmentLength,
  bool removeDc = true,
}) {
  final halfBins = (segmentLength ~/ 2) + 1;
  final power = Float32List(halfBins);

  var mean = 0.0;
  if (removeDc) {
    for (var i = 0; i < segmentLength; i++) {
      mean += samples[i];
    }
    mean /= segmentLength;
  }

  final normalization = 1.0 / (sampleRate * segmentLength);
  for (var k = 0; k < halfBins; k++) {
    var real = 0.0;
    var imag = 0.0;
    final phaseScale = 2.0 * math.pi * k / segmentLength;
    for (var n = 0; n < segmentLength; n++) {
      final value = samples[n] - mean;
      final phase = phaseScale * n;
      real += value * math.cos(phase);
      imag -= value * math.sin(phase);
    }

    var p = (real * real + imag * imag) * normalization;
    if (k != 0 && k != halfBins - 1) {
      p *= 2.0;
    }
    power[k] = p;
  }

  return power;
}

double _farLeakageRatio(List<double> bins, {int excludeRadius = 3}) {
  var peakBin = 0;
  var peakValue = -double.infinity;
  for (var i = 0; i < bins.length; i++) {
    if (bins[i] > peakValue) {
      peakValue = bins[i];
      peakBin = i;
    }
  }

  final minBin = math.max(0, peakBin - excludeRadius);
  final maxBin = math.min(bins.length - 1, peakBin + excludeRadius);

  var total = 0.0;
  var far = 0.0;
  for (var i = 0; i < bins.length; i++) {
    final value = bins[i];
    total += value;
    if (i < minBin || i > maxBin) {
      far += value;
    }
  }

  if (total <= 0.0) {
    return 0;
  }
  return far / total;
}

Float32List _lowPassOnePole(Float32List input, {required double alpha}) {
  final out = Float32List(input.length);
  var state = 0.0;
  for (var i = 0; i < input.length; i++) {
    state = state + alpha * (input[i] - state);
    out[i] = state;
  }
  return out;
}

double _spectralCentroidHz(
  WelchPsdResult psd, {
  double minFrequencyHz = 20.0,
  double? maxFrequencyHz,
}) {
  final upperBound = maxFrequencyHz ?? psd.frequenciesHz[psd.frequenciesHz.length - 1];

  var weightedSum = 0.0;
  var weightSum = 0.0;
  for (var i = 0; i < psd.frequenciesHz.length; i++) {
    final f = psd.frequenciesHz[i];
    if (f < minFrequencyHz || f > upperBound) {
      continue;
    }
    final w = psd.power[i];
    weightedSum += f * w;
    weightSum += w;
  }

  if (weightSum <= 0.0) {
    return 0;
  }
  return weightedSum / weightSum;
}

double _normalizedAutocorrelation(
  Float32List samples,
  int lag,
) {
  if (lag <= 0 || lag >= samples.length) {
    throw ArgumentError.value(lag, 'lag', 'Must be in (0, samples.length)');
  }

  var mean = 0.0;
  for (final sample in samples) {
    mean += sample;
  }
  mean /= samples.length;

  var variance = 0.0;
  for (final sample in samples) {
    final centered = sample - mean;
    variance += centered * centered;
  }
  if (variance <= 0.0) {
    return 0;
  }

  var covariance = 0.0;
  final n = samples.length - lag;
  for (var i = 0; i < n; i++) {
    covariance += (samples[i] - mean) * (samples[i + lag] - mean);
  }

  return covariance / variance;
}

void main() {
  group('audio analysis metrics helpers', () {
    test('Welch PSD peaks near the expected sine frequency', () {
      const sampleRate = 8000;
      const frequencyHz = 440.0;
      final samples = _sine(
        length: 8192,
        sampleRate: sampleRate.toDouble(),
        frequencyHz: frequencyHz,
      );

      final psd = computeWelchPsd(
        samples,
        sampleRate: sampleRate,
      );

      var peakBin = 0;
      var peakPower = -double.infinity;
      for (var i = 0; i < psd.power.length; i++) {
        if (psd.power[i] > peakPower) {
          peakPower = psd.power[i];
          peakBin = i;
        }
      }

      final expectedBin = (frequencyHz * 1024 / sampleRate).round();
      // Welch uses a Hann window. Because 440 Hz is not exactly bin-centered
      // for N=1024 at 8 kHz, the dominant bin may be one of the adjacent bins.
      expect(
        peakBin,
        anyOf(equals(expectedBin - 1), equals(expectedBin), equals(expectedBin + 1)),
      );

      final peakFrequency = psd.frequenciesHz[peakBin];
      expect(peakFrequency, closeTo(frequencyHz, 8.0));

      var avgPower = 0.0;
      for (final p in psd.power) {
        avgPower += p;
      }
      avgPower /= psd.power.length;
      expect(peakPower, greaterThan(avgPower * 20.0));
    });

    test('Welch PSD windowing and overlap reduce leakage and increase averaging', () {
      const sampleRate = 8000;
      const segmentLength = 1024;
      final samples = _sine(
        length: 8192,
        sampleRate: sampleRate.toDouble(),
        frequencyHz: 440,
      );

      final welchOverlap = computeWelchPsd(
        samples,
        sampleRate: sampleRate,
        segmentLength: segmentLength,
      );
      final welchNoOverlap = computeWelchPsd(
        samples,
        sampleRate: sampleRate,
        segmentLength: segmentLength,
        hopLength: segmentLength,
      );
      final rectangular = _singleSegmentRectangularPsd(
        samples,
        sampleRate: sampleRate,
        segmentLength: segmentLength,
      );

      // Default Welch overlap is 50%, so this should produce more segments.
      expect(welchOverlap.segmentCount, greaterThan(welchNoOverlap.segmentCount));

      final hannFarLeakage = _farLeakageRatio(
        welchNoOverlap.power,
        excludeRadius: 3,
      );
      final rectangularFarLeakage = _farLeakageRatio(
        rectangular,
        excludeRadius: 3,
      );

      // Hann window should reduce far-out sidelobe leakage versus rectangular.
      expect(hannFarLeakage, lessThan(rectangularFarLeakage));
    });

    test('spectral slope is near 0 for white noise and negative for brown noise', () {
      const sampleRate = 8000;

      final white = _whiteNoise(length: 32768, seed: 7);
      final brown = _brownNoise(length: 32768, seed: 7);

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

      expect(whiteSlope, closeTo(0.0, 0.2));
      expect(brownSlope, closeTo(-2.0, 0.4));
    });

    test('band energy ratios highlight dominant low-frequency content', () {
      const sampleRate = 8000.0;
      const length = 8192;
      final samples = Float32List(length);
      final noise = _whiteNoise(length: length, seed: 123);

      for (var i = 0; i < length; i++) {
        final t = i / sampleRate;
        final low = math.sin(2.0 * math.pi * 180.0 * t);
        final high = 0.2 * math.sin(2.0 * math.pi * 2200.0 * t);
        samples[i] = low + high + (0.25 * noise[i]);
      }

      final psd = computeWelchPsd(
        samples,
        sampleRate: sampleRate.toInt(),
        segmentLength: 1024,
      );

      final ratios = computeBandEnergyRatios(psd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 100, highHz: 400),
        FrequencyBand(label: 'mid', lowHz: 400, highHz: 1500),
        FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
      ]);

      expect(ratios['low'], isNotNull);
      expect(ratios['high'], isNotNull);
      expect(ratios['low'], greaterThan(0.7));
      expect(ratios['high'], lessThan(0.2));

      final total = ratios.values.fold<double>(0, (acc, v) => acc + v);
      expect(total, closeTo(1.0, 1e-9));
    });

    test('RMS mean and variance are accurate across windows', () {
      final samples = Float32List(256 * 16);
      for (var window = 0; window < 16; window++) {
        final value = window < 8 ? 0.5 : 1.0;
        final start = window * 256;
        for (var i = 0; i < 256; i++) {
          samples[start + i] = value;
        }
      }

      final stats = computeRmsMeanVariance(samples, windowSize: 256);

      expect(stats.values.length, 16);
      expect(stats.mean, closeTo(0.75, 1e-12));
      expect(stats.variance, closeTo(0.0625, 1e-12));
    });

    test('RMS on white noise has stable mean and low variance across windows', () {
      final samples = _whiteNoise(length: 65536, seed: 777);
      final stats = computeRmsMeanVariance(
        samples,
        windowSize: 512,
        hopSize: 512,
      );

      expect(stats.mean, closeTo(math.sqrt(1.0 / 3.0), 0.03));
      expect(stats.variance, lessThan(0.01));
    });

    test('RMS variance increases for AM-modulated signals', () {
      const sampleRate = 8000.0;
      const length = 32000;
      final modulated = Float32List(length);
      final staticSine = Float32List(length);

      for (var i = 0; i < length; i++) {
        final t = i / sampleRate;
        final envelope = 0.5 + 0.4 * math.sin(2.0 * math.pi * 2.0 * t);
        final carrier = math.sin(2.0 * math.pi * 440.0 * t);
        modulated[i] = envelope * carrier;
        staticSine[i] = 0.5 * carrier;
      }

      final modulatedStats = computeRmsMeanVariance(
        modulated,
        windowSize: 400,
        hopSize: 400,
      );
      final staticStats = computeRmsMeanVariance(
        staticSine,
        windowSize: 400,
        hopSize: 400,
      );

      expect(modulatedStats.mean, closeTo(0.35, 0.04));
      expect(modulatedStats.variance, closeTo(0.04, 0.02));
      expect(modulatedStats.variance, greaterThan(staticStats.variance * 20.0));
    });

    test('crest factor behaves as expected for sine and impulse-like signals', () {
      final sine = _sine(
        length: 8192,
        sampleRate: 8000,
        frequencyHz: 440,
      );
      final sineCrest = computeCrestFactor(sine);
      expect(sineCrest, closeTo(math.sqrt(2.0), 0.05));

      final impulse = Float32List(1024);
      impulse[0] = 1.0;
      final impulseCrest = computeCrestFactor(impulse);
      expect(impulseCrest, closeTo(math.sqrt(1024.0), 1e-9));

      final clipped = Float32List.fromList(List<double>.filled(1024, 1));
      expect(computeCrestFactor(clipped), closeTo(1.0, 1e-6));
    });

    test('spectral flatness separates tonal and noise-like content', () {
      const sampleRate = 8000;
      final sine = _sine(
        length: 8192,
        sampleRate: sampleRate.toDouble(),
        frequencyHz: 440,
      );
      final noise = _whiteNoise(length: 8192, seed: 19);
      final filteredNoise = _lowPassOnePole(noise, alpha: 0.03);

      final sinePsd = computeWelchPsd(
        sine,
        sampleRate: sampleRate,
        segmentLength: 1024,
      );
      final noisePsd = computeWelchPsd(
        noise,
        sampleRate: sampleRate,
        segmentLength: 1024,
      );
      final filteredNoisePsd = computeWelchPsd(
        filteredNoise,
        sampleRate: sampleRate,
        segmentLength: 1024,
      );

      final sineFlatness = computeSpectralFlatness(
        sinePsd,
        minFrequencyHz: 20,
        maxFrequencyHz: 3500,
      );
      final noiseFlatness = computeSpectralFlatness(
        noisePsd,
        minFrequencyHz: 20,
        maxFrequencyHz: 3500,
      );
      final filteredNoiseFlatness = computeSpectralFlatness(
        filteredNoisePsd,
        minFrequencyHz: 20,
        maxFrequencyHz: 3500,
      );

      expect(sineFlatness, lessThan(0.15));
      expect(noiseFlatness, greaterThan(0.5));
      expect(filteredNoiseFlatness, lessThan(noiseFlatness));
      expect(filteredNoiseFlatness, greaterThan(sineFlatness));
    });

    test('clipping and DC offset analysis reports expected metrics', () {
      final samples = Float32List.fromList(<double>[
        -1.2,
        -0.8,
        -0.1,
        0.2,
        0.9,
        1,
        1.1,
      ]);

      final result = analyzeClippingAndDcOffset(
        samples,
        clipThreshold: 1,
        dcOffsetThreshold: 0.1,
      );

      expect(result.clippedSampleCount, 3);
      expect(result.clippedRatio, closeTo(3 / 7, 1e-12));
      expect(result.hasClipping, isTrue);
      expect(result.dcOffset, closeTo(1.1 / 7, 1e-7));
      expect(result.hasDcOffset, isTrue);
      expect(result.positivePeak, closeTo(1.1, 1e-6));
      expect(result.negativePeak, closeTo(-1.2, 1e-6));
    });

    test('DC offset detection finds small bias under noise', () {
      final noise = _whiteNoise(length: 65536, seed: 99);
      final biased = Float32List(noise.length);
      for (var i = 0; i < biased.length; i++) {
        biased[i] = 0.5 * noise[i] + 0.02;
      }

      final result = analyzeClippingAndDcOffset(
        biased,
        clipThreshold: 1,
        dcOffsetThreshold: 0.01,
      );

      expect(result.hasClipping, isFalse);
      expect(result.hasDcOffset, isTrue);
      expect(result.dcOffset, closeTo(0.02, 0.005));
    });

    test('temporal stability: stationary noise has stable RMS and centroid over time', () {
      const sampleRate = 8000;
      const frameSize = 2048;
      const frameCount = 16;

      final samples = _whiteNoise(length: frameSize * frameCount, seed: 2026);
      final rmsStats = computeRmsMeanVariance(
        samples,
        windowSize: frameSize,
        hopSize: frameSize,
      );

      final centroids = Float64List(frameCount);
      for (var frame = 0; frame < frameCount; frame++) {
        final start = frame * frameSize;
        final segment = Float32List(frameSize);
        for (var i = 0; i < frameSize; i++) {
          segment[i] = samples[start + i];
        }
        final psd = computeWelchPsd(
          segment,
          sampleRate: sampleRate,
          segmentLength: 1024,
          hopLength: 512,
        );
        centroids[frame] = _spectralCentroidHz(
          psd,
          minFrequencyHz: 20,
          maxFrequencyHz: 3500,
        );
      }

      var centroidMean = 0.0;
      for (final c in centroids) {
        centroidMean += c;
      }
      centroidMean /= centroids.length;

      var centroidVariance = 0.0;
      for (final c in centroids) {
        final d = c - centroidMean;
        centroidVariance += d * d;
      }
      centroidVariance /= centroids.length;
      final centroidStd = math.sqrt(centroidVariance);

      expect(rmsStats.variance, lessThan(0.003));
      expect(centroidStd / centroidMean, lessThan(0.12));
    });

    test('aliasing check: near-Nyquist sine keeps energy in top band', () {
      const sampleRate = 8000;
      const frequencyHz = 3900.0;
      final samples = _sine(
        length: 16384,
        sampleRate: sampleRate.toDouble(),
        frequencyHz: frequencyHz,
      );

      final psd = computeWelchPsd(
        samples,
        sampleRate: sampleRate,
        segmentLength: 2048,
      );
      final ratios = computeBandEnergyRatios(psd, const <FrequencyBand>[
        FrequencyBand(label: 'low', lowHz: 20, highHz: 1500),
        FrequencyBand(label: 'high', lowHz: 3200, highHz: 3990),
      ]);

      expect(ratios['high'], isNotNull);
      expect(ratios['low'], isNotNull);
      expect(ratios['high'], greaterThan(0.9));
      expect(ratios['low'], lessThan(0.02));
    });

    test('autocorrelation catches periodicity while noise stays near-zero at nonzero lags', () {
      const sampleRate = 8000.0;
      final noise = _whiteNoise(length: 32768, seed: 314);

      double maxAbsNoiseCorr = 0;
      for (var lag = 1; lag <= 128; lag++) {
        final value = _normalizedAutocorrelation(noise, lag).abs();
        if (value > maxAbsNoiseCorr) {
          maxAbsNoiseCorr = value;
        }
      }

      final tone = _sine(
        length: 32768,
        sampleRate: sampleRate,
        frequencyHz: 440,
      );
      final toneLag = (sampleRate / 440.0).round();
      final periodicCorr = _normalizedAutocorrelation(tone, toneLag);

      expect(maxAbsNoiseCorr, lessThan(0.08));
      expect(periodicCorr, greaterThan(0.9));
    });
  });
}
