import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulators/modulator.dart';

const double _epsilon = 1e-12;

class WelchPsdResult {
  const WelchPsdResult({
    required this.frequenciesHz,
    required this.power,
    required this.segmentCount,
    required this.segmentLength,
  });

  final Float64List frequenciesHz;
  final Float64List power;
  final int segmentCount;
  final int segmentLength;
}

class FrequencyBand {
  const FrequencyBand({
    required this.label,
    required this.lowHz,
    required this.highHz,
  });

  final String label;
  final double lowHz;
  final double highHz;
}

class RmsStats {
  const RmsStats({
    required this.mean,
    required this.variance,
    required this.values,
  });

  final double mean;
  final double variance;
  final Float64List values;
}

class ClippingDcAnalysis {
  const ClippingDcAnalysis({
    required this.clippedSampleCount,
    required this.clippedRatio,
    required this.hasClipping,
    required this.dcOffset,
    required this.hasDcOffset,
    required this.positivePeak,
    required this.negativePeak,
  });

  final int clippedSampleCount;
  final double clippedRatio;
  final bool hasClipping;
  final double dcOffset;
  final bool hasDcOffset;
  final double positivePeak;
  final double negativePeak;
}

WelchPsdResult computeWelchPsd(
  Float32List samples, {
  required int sampleRate,
  int segmentLength = 1024,
  int? hopLength,
  bool removeDc = true,
}) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples.length, 'samples.length', 'Must be > 0');
  }
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be > 0');
  }
  if (segmentLength < 8) {
    throw ArgumentError.value(
      segmentLength,
      'segmentLength',
      'Must be >= 8 for stable PSD estimation',
    );
  }
  if (segmentLength > samples.length) {
    throw ArgumentError.value(
      segmentLength,
      'segmentLength',
      'Cannot exceed samples.length',
    );
  }

  final hop = hopLength ?? (segmentLength ~/ 2);
  if (hop <= 0) {
    throw ArgumentError.value(hop, 'hopLength', 'Must be > 0');
  }

  final segmentCount = 1 + ((samples.length - segmentLength) ~/ hop);
  if (segmentCount <= 0) {
    throw StateError('No analyzable segments were produced.');
  }

  final halfBins = (segmentLength ~/ 2) + 1;
  final power = Float64List(halfBins);
  final frequenciesHz = Float64List(halfBins);
  final window = Float64List(segmentLength);

  var windowPower = 0.0;
  for (var n = 0; n < segmentLength; n++) {
    final w = 0.5 - 0.5 * math.cos((2.0 * math.pi * n) / (segmentLength - 1));
    window[n] = w;
    windowPower += w * w;
  }

  final segmentBuffer = Float64List(segmentLength);
  final normalization = 1.0 / (sampleRate * windowPower * segmentCount);

  for (var segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
    final start = segmentIndex * hop;

    var mean = 0.0;
    if (removeDc) {
      for (var i = 0; i < segmentLength; i++) {
        mean += samples[start + i];
      }
      mean /= segmentLength;
    }

    for (var i = 0; i < segmentLength; i++) {
      final centered = samples[start + i] - mean;
      segmentBuffer[i] = centered * window[i];
    }

    for (var k = 0; k < halfBins; k++) {
      var real = 0.0;
      var imag = 0.0;
      final phaseScale = 2.0 * math.pi * k / segmentLength;
      for (var n = 0; n < segmentLength; n++) {
        final phase = phaseScale * n;
        final value = segmentBuffer[n];
        real += value * math.cos(phase);
        imag -= value * math.sin(phase);
      }

      var p = (real * real + imag * imag) * normalization;
      if (k != 0 && k != halfBins - 1) {
        p *= 2.0;
      }
      power[k] += p;
    }
  }

  for (var k = 0; k < halfBins; k++) {
    frequenciesHz[k] = (k * sampleRate) / segmentLength;
  }

  return WelchPsdResult(
    frequenciesHz: frequenciesHz,
    power: power,
    segmentCount: segmentCount,
    segmentLength: segmentLength,
  );
}

double computeSpectralSlope(
  WelchPsdResult psd, {
  double minFrequencyHz = 20.0,
  double? maxFrequencyHz,
}) {
  if (psd.frequenciesHz.isEmpty || psd.power.isEmpty) {
    throw ArgumentError('PSD arrays must be non-empty.');
  }
  if (psd.frequenciesHz.length != psd.power.length) {
    throw ArgumentError('PSD frequency and power arrays must have equal length.');
  }
  if (minFrequencyHz <= 0.0) {
    throw ArgumentError.value(minFrequencyHz, 'minFrequencyHz', 'Must be > 0');
  }

  final upperBound = maxFrequencyHz ?? psd.frequenciesHz[psd.frequenciesHz.length - 1];
  if (upperBound <= minFrequencyHz) {
    throw ArgumentError('maxFrequencyHz must be greater than minFrequencyHz.');
  }

  var count = 0;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumXY = 0.0;

  for (var i = 0; i < psd.frequenciesHz.length; i++) {
    final f = psd.frequenciesHz[i];
    if (f < minFrequencyHz || f > upperBound) {
      continue;
    }
    final p = psd.power[i];
    if (p <= 0.0) {
      continue;
    }

    final x = math.log(f) / math.ln10;
    final y = math.log(p) / math.ln10;
    count++;
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumXY += x * y;
  }

  if (count < 2) {
    throw StateError('Not enough valid bins in the selected frequency range.');
  }

  final denominator = count * sumXX - (sumX * sumX);
  if (denominator.abs() < _epsilon) {
    throw StateError('Ill-conditioned regression while computing spectral slope.');
  }

  return (count * sumXY - sumX * sumY) / denominator;
}

Map<String, double> computeBandEnergyRatios(
  WelchPsdResult psd,
  List<FrequencyBand> bands,
) {
  if (bands.isEmpty) {
    throw ArgumentError.value(bands.length, 'bands.length', 'Must be > 0');
  }

  final energies = <String, double>{};
  var totalEnergy = 0.0;

  for (final band in bands) {
    if (band.lowHz < 0.0 || band.highHz <= band.lowHz) {
      throw ArgumentError(
        'Invalid band "${band.label}". Expected 0 <= lowHz < highHz.',
      );
    }

    var energy = 0.0;
    for (var i = 0; i < psd.frequenciesHz.length; i++) {
      final f = psd.frequenciesHz[i];
      if (f >= band.lowHz && f < band.highHz) {
        energy += psd.power[i];
      }
    }

    energies[band.label] = energy;
    totalEnergy += energy;
  }

  if (totalEnergy <= _epsilon) {
    return <String, double>{for (final band in bands) band.label: 0.0};
  }

  return <String, double>{
    for (final entry in energies.entries) entry.key: entry.value / totalEnergy,
  };
}

RmsStats computeRmsMeanVariance(
  Float32List samples, {
  int windowSize = 1024,
  int? hopSize,
}) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples.length, 'samples.length', 'Must be > 0');
  }
  if (windowSize <= 0 || windowSize > samples.length) {
    throw ArgumentError.value(
      windowSize,
      'windowSize',
      'Must be > 0 and <= samples.length',
    );
  }

  final hop = hopSize ?? windowSize;
  if (hop <= 0) {
    throw ArgumentError.value(hop, 'hopSize', 'Must be > 0');
  }

  final count = 1 + ((samples.length - windowSize) ~/ hop);
  if (count <= 0) {
    throw StateError('No analyzable windows were produced.');
  }

  final values = Float64List(count);
  var valueIndex = 0;

  for (var start = 0; start + windowSize <= samples.length; start += hop) {
    var sumSquares = 0.0;
    for (var i = 0; i < windowSize; i++) {
      final s = samples[start + i];
      sumSquares += s * s;
    }
    values[valueIndex++] = math.sqrt(sumSquares / windowSize);
  }

  var mean = 0.0;
  for (final value in values) {
    mean += value;
  }
  mean /= values.length;

  var variance = 0.0;
  for (final value in values) {
    final delta = value - mean;
    variance += delta * delta;
  }
  variance /= values.length;

  return RmsStats(mean: mean, variance: variance, values: values);
}

double computeCrestFactor(Float32List samples) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples.length, 'samples.length', 'Must be > 0');
  }

  var peak = 0.0;
  var sumSquares = 0.0;
  for (final sample in samples) {
    final absValue = sample.abs();
    if (absValue > peak) {
      peak = absValue;
    }
    sumSquares += sample * sample;
  }

  final rms = math.sqrt(sumSquares / samples.length);
  if (rms <= _epsilon) {
    return peak <= _epsilon ? 1.0 : double.infinity;
  }
  return peak / rms;
}

double computeSpectralFlatness(
  WelchPsdResult psd, {
  double minFrequencyHz = 20.0,
  double? maxFrequencyHz,
}) {
  if (psd.frequenciesHz.length != psd.power.length || psd.power.isEmpty) {
    throw ArgumentError('PSD frequency and power arrays must be non-empty and equal length.');
  }

  final upperBound = maxFrequencyHz ?? psd.frequenciesHz[psd.frequenciesHz.length - 1];
  if (minFrequencyHz < 0.0 || upperBound <= minFrequencyHz) {
    throw ArgumentError('Invalid spectral flatness frequency bounds.');
  }

  var count = 0;
  var sumLog = 0.0;
  var sumLinear = 0.0;

  for (var i = 0; i < psd.frequenciesHz.length; i++) {
    final f = psd.frequenciesHz[i];
    if (f < minFrequencyHz || f > upperBound) {
      continue;
    }

    final p = psd.power[i].clamp(_epsilon, double.infinity);
    count++;
    sumLog += math.log(p);
    sumLinear += p;
  }

  if (count == 0 || sumLinear <= _epsilon) {
    throw StateError('No valid bins available for spectral flatness.');
  }

  final geometricMean = math.exp(sumLog / count);
  final arithmeticMean = sumLinear / count;
  return geometricMean / arithmeticMean;
}

ClippingDcAnalysis analyzeClippingAndDcOffset(
  Float32List samples, {
  double clipThreshold = 1.0,
  double dcOffsetThreshold = 0.01,
}) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples.length, 'samples.length', 'Must be > 0');
  }
  if (clipThreshold <= 0.0) {
    throw ArgumentError.value(
      clipThreshold,
      'clipThreshold',
      'Must be > 0',
    );
  }
  if (dcOffsetThreshold < 0.0) {
    throw ArgumentError.value(
      dcOffsetThreshold,
      'dcOffsetThreshold',
      'Must be >= 0',
    );
  }

  var sum = 0.0;
  var clipped = 0;
  var positivePeak = -double.infinity;
  var negativePeak = double.infinity;

  for (final sample in samples) {
    sum += sample;
    if (sample.abs() >= clipThreshold) {
      clipped++;
    }
    if (sample > positivePeak) {
      positivePeak = sample;
    }
    if (sample < negativePeak) {
      negativePeak = sample;
    }
  }

  final dcOffset = sum / samples.length;
  final clippedRatio = clipped / samples.length;

  return ClippingDcAnalysis(
    clippedSampleCount: clipped,
    clippedRatio: clippedRatio,
    hasClipping: clipped > 0,
    dcOffset: dcOffset,
    hasDcOffset: dcOffset.abs() >= dcOffsetThreshold,
    positivePeak: positivePeak,
    negativePeak: negativePeak,
  );
}

class CounterModulator implements Modulator {
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
