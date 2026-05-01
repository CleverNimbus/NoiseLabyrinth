import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

import 'modulators_test_helpers.dart';

const List<FrequencyBand> kDefaultValidationBands = <FrequencyBand>[
  FrequencyBand(label: 'low', lowHz: 50, highHz: 400),
  FrequencyBand(label: 'mid', lowHz: 400, highHz: 1500),
  FrequencyBand(label: 'high', lowHz: 1500, highHz: 3000),
];

class ValidationRange {
  const ValidationRange(this.min, this.max) : assert(min <= max, 'ValidationRange min must be <= max');

  final double min;
  final double max;

  bool contains(double value) => value >= min && value <= max;

  @override
  String toString() => '[$min, $max]';
}

class TemporalStats {
  const TemporalStats({
    required this.mean,
    required this.variance,
    required this.min,
    required this.max,
  });

  final double mean;
  final double variance;
  final double min;
  final double max;
}

class AudioFeatures {
  const AudioFeatures({
    required this.spectralSlope,
    required this.bandEnergy,
    required this.rmsMean,
    required this.rmsVariance,
    required this.crestFactor,
    required this.flatness,
    required this.dcOffset,
    required this.clippedRatio,
    required this.peakFrequencyHz,
    required this.windowedRms,
    required this.windowedSpectralCentroid,
  });

  final double spectralSlope;
  final Map<String, double> bandEnergy;
  final double rmsMean;
  final double rmsVariance;
  final double crestFactor;
  final double flatness;
  final double dcOffset;
  final double clippedRatio;
  final double peakFrequencyHz;
  final TemporalStats windowedRms;
  final TemporalStats windowedSpectralCentroid;

  double get burstFactor => windowedRms.max / math.max(windowedRms.mean, 1e-12);
}

class ProfileConstraints {
  const ProfileConstraints({
    required this.label,
    this.spectralSlope,
    this.rmsMean,
    this.rmsVariance,
    this.crestFactor,
    this.flatness,
    this.dcOffsetAbs,
    this.clippedRatio,
    this.windowedRmsVariance,
    this.windowedSpectralCentroidVariance,
    this.burstFactor,
    this.bandEnergy = const <String, ValidationRange>{},
    this.allowBursts,
  });

  final String label;
  final ValidationRange? spectralSlope;
  final ValidationRange? rmsMean;
  final ValidationRange? rmsVariance;
  final ValidationRange? crestFactor;
  final ValidationRange? flatness;
  final ValidationRange? dcOffsetAbs;
  final ValidationRange? clippedRatio;
  final ValidationRange? windowedRmsVariance;
  final ValidationRange? windowedSpectralCentroidVariance;
  final ValidationRange? burstFactor;
  final Map<String, ValidationRange> bandEnergy;
  final bool? allowBursts;
}

class ProfileValidationSpec {
  const ProfileValidationSpec({
    required this.constraints,
    this.sampleRate = 8000,
    this.totalSamples = 32768,
    this.blockSize = 256,
  });

  final ProfileConstraints constraints;
  final int sampleRate;
  final int totalSamples;
  final int blockSize;
}

class ValidationResult {
  const ValidationResult({required this.passed, required this.failures});

  final bool passed;
  final List<String> failures;
}

class AudioFeatureExtractor {
  const AudioFeatureExtractor({
    this.bands = kDefaultValidationBands,
    this.psdSegmentLength = 2048,
    this.temporalWindowSize = 4096,
    this.temporalHopSize = 4096,
  });

  final List<FrequencyBand> bands;
  final int psdSegmentLength;
  final int temporalWindowSize;
  final int temporalHopSize;

  AudioFeatures extract(Float32List samples, {required int sampleRate}) {
    final overallSegmentLength = _fitSegmentLength(
      preferred: psdSegmentLength,
      length: samples.length,
    );
    final overallPsd = computeWelchPsd(
      samples,
      sampleRate: sampleRate,
      segmentLength: overallSegmentLength,
    );
    final rmsStats = computeRmsMeanVariance(
      samples,
      windowSize: math.min(temporalWindowSize, samples.length),
      hopSize: math.min(temporalHopSize, samples.length),
    );
    final clipping = analyzeClippingAndDcOffset(
      samples,
      clipThreshold: 1.0001,
      dcOffsetThreshold: 0.02,
    );

    final frameRmsValues = <double>[];
    final frameCentroidValues = <double>[];
    final actualWindow = math.min(temporalWindowSize, samples.length);
    final actualHop = math.max(1, math.min(temporalHopSize, samples.length));
    for (var start = 0; start + actualWindow <= samples.length; start += actualHop) {
      final frame = Float32List(actualWindow);
      for (var i = 0; i < actualWindow; i++) {
        frame[i] = samples[start + i];
      }

      frameRmsValues.add(_rms(frame));

      final frameSegmentLength = _fitSegmentLength(
        preferred: math.min(1024, actualWindow),
        length: actualWindow,
      );
      final framePsd = computeWelchPsd(
        frame,
        sampleRate: sampleRate,
        segmentLength: frameSegmentLength,
      );
      frameCentroidValues.add(
        _spectralCentroidHz(
          framePsd,
          minFrequencyHz: 50,
          maxFrequencyHz: math.min(sampleRate / 2 - 10.0, 3000),
        ),
      );
    }

    return AudioFeatures(
      spectralSlope: computeSpectralSlope(
        overallPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: math.min(sampleRate / 2 - 10.0, 3000),
      ),
      bandEnergy: computeBandEnergyRatios(overallPsd, bands),
      rmsMean: rmsStats.mean,
      rmsVariance: rmsStats.variance,
      crestFactor: computeCrestFactor(samples),
      flatness: computeSpectralFlatness(
        overallPsd,
        minFrequencyHz: 50,
        maxFrequencyHz: math.min(sampleRate / 2 - 10.0, 3000),
      ),
      dcOffset: clipping.dcOffset,
      clippedRatio: clipping.clippedRatio,
      peakFrequencyHz: _peakFrequencyHz(overallPsd),
      windowedRms: _summarize(frameRmsValues),
      windowedSpectralCentroid: _summarize(frameCentroidValues),
    );
  }

  static int _fitSegmentLength({required int preferred, required int length}) {
    var value = math.min(preferred, length);
    while (value > 8 && !_isPowerOfTwo(value)) {
      value--;
    }
    return math.max(8, value);
  }

  static bool _isPowerOfTwo(int value) => value > 0 && (value & (value - 1)) == 0;
}

class ProfileValidator {
  const ProfileValidator();

  ValidationResult validate(
    AudioFeatures features,
    ProfileConstraints constraints,
  ) {
    final failures = <String>[];

    _checkRange(
      failures,
      label: 'spectralSlope',
      value: features.spectralSlope,
      range: constraints.spectralSlope,
    );
    _checkRange(
      failures,
      label: 'rmsMean',
      value: features.rmsMean,
      range: constraints.rmsMean,
    );
    _checkRange(
      failures,
      label: 'rmsVariance',
      value: features.rmsVariance,
      range: constraints.rmsVariance,
    );
    _checkRange(
      failures,
      label: 'crestFactor',
      value: features.crestFactor,
      range: constraints.crestFactor,
    );
    _checkRange(
      failures,
      label: 'flatness',
      value: features.flatness,
      range: constraints.flatness,
    );
    _checkRange(
      failures,
      label: 'dcOffsetAbs',
      value: features.dcOffset.abs(),
      range: constraints.dcOffsetAbs,
    );
    _checkRange(
      failures,
      label: 'clippedRatio',
      value: features.clippedRatio,
      range: constraints.clippedRatio,
    );
    _checkRange(
      failures,
      label: 'windowedRmsVariance',
      value: features.windowedRms.variance,
      range: constraints.windowedRmsVariance,
    );
    _checkRange(
      failures,
      label: 'windowedSpectralCentroidVariance',
      value: features.windowedSpectralCentroid.variance,
      range: constraints.windowedSpectralCentroidVariance,
    );
    _checkRange(
      failures,
      label: 'burstFactor',
      value: features.burstFactor,
      range: constraints.burstFactor,
    );

    for (final entry in constraints.bandEnergy.entries) {
      final value = features.bandEnergy[entry.key];
      if (value == null) {
        failures.add('Missing band energy for ${entry.key}.');
        continue;
      }
      _checkRange(
        failures,
        label: 'bandEnergy.${entry.key}',
        value: value,
        range: entry.value,
      );
    }

    if (constraints.allowBursts == true && features.burstFactor < 1.05) {
      failures.add(
        'Expected burst-capable dynamics, but burstFactor=${features.burstFactor.toStringAsFixed(3)}.',
      );
    }
    if (constraints.allowBursts == false && features.burstFactor > 2.0) {
      failures.add(
        'Unexpected burst-like dynamics, burstFactor=${features.burstFactor.toStringAsFixed(3)}.',
      );
    }

    return ValidationResult(passed: failures.isEmpty, failures: failures);
  }

  void _checkRange(
    List<String> failures, {
    required String label,
    required double value,
    required ValidationRange? range,
  }) {
    if (range == null) {
      return;
    }
    if (!range.contains(value)) {
      failures.add('$label expected $range, got ${value.toStringAsFixed(6)}.');
    }
  }
}

class ProfileConstraintFactory {
  const ProfileConstraintFactory();

  static const Map<String, ProfileValidationSpec> explicitSpecs = <String, ProfileValidationSpec>{
    'White noise profile': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit broadband white noise',
        spectralSlope: ValidationRange(-0.8, 0.5),
        rmsVariance: ValidationRange(0, 0.02),
        crestFactor: ValidationRange(1.4, 6),
        flatness: ValidationRange(0.35, 1),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.02),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.1, 0.5),
          'mid': ValidationRange(0.1, 0.6),
          'high': ValidationRange(0.1, 0.6),
        },
        allowBursts: false,
      ),
    ),
    'Brown Noise - Deep Field (Pro)': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit sleep-like brown ambience',
        spectralSlope: ValidationRange(-3.2, -0.6),
        rmsVariance: ValidationRange(0, 0.02),
        crestFactor: ValidationRange(1.1, 6),
        flatness: ValidationRange(0.02, 0.8),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.02),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.30, 1),
          'mid': ValidationRange(0, 0.5),
          'high': ValidationRange(0, 0.25),
        },
        allowBursts: false,
      ),
    ),
    'Bandlimited noise profile': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit bandlimited mid-focus',
        spectralSlope: ValidationRange(-2.2, 0.4),
        rmsVariance: ValidationRange(0, 0.03),
        crestFactor: ValidationRange(1.4, 6),
        flatness: ValidationRange(0.12, 0.98),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.03),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0, 0.25),
          'mid': ValidationRange(0.25, 0.95),
          'high': ValidationRange(0, 0.55),
        },
        allowBursts: false,
      ),
    ),
    'lfo_gain_test': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit gain-modulated noise',
        spectralSlope: ValidationRange(-2.2, -0.2),
        rmsVariance: ValidationRange(0, 0.06),
        crestFactor: ValidationRange(1.5, 6),
        flatness: ValidationRange(0.15, 0.9),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0.0003, 0.08),
        burstFactor: ValidationRange(1.1, 1.9),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.15, 0.6),
          'mid': ValidationRange(0.15, 0.6),
          'high': ValidationRange(0.05, 0.45),
        },
        allowBursts: false,
      ),
      totalSamples: 65536,
    ),
    'random_filter_test': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit wandering mid-focused noise',
        spectralSlope: ValidationRange(-2.2, 0.6),
        rmsVariance: ValidationRange(0, 0.04),
        crestFactor: ValidationRange(1.3, 6),
        flatness: ValidationRange(0.08, 0.7),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.04),
        windowedSpectralCentroidVariance: ValidationRange(150, 500000),
        burstFactor: ValidationRange(1, 1.9),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0, 0.25),
          'mid': ValidationRange(0.20, 0.95),
          'high': ValidationRange(0, 0.35),
        },
        allowBursts: false,
      ),
      totalSamples: 65536,
    ),
    'Storm Forest - Vivid': ProfileValidationSpec(
      constraints: ProfileConstraints(
        label: 'explicit burst-dynamic ambience',
        spectralSlope: ValidationRange(-3, 0.5),
        rmsVariance: ValidationRange(0, 0.2),
        crestFactor: ValidationRange(1.4, 10),
        flatness: ValidationRange(0.08, 0.95),
        dcOffsetAbs: ValidationRange(0, 0.1),
        clippedRatio: ValidationRange(0, 0.35),
        windowedRmsVariance: ValidationRange(0.001, 0.2),
        burstFactor: ValidationRange(1.05, 8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.15, 0.8),
          'mid': ValidationRange(0.05, 0.7),
          'high': ValidationRange(0, 0.55),
        },
        allowBursts: true,
      ),
      totalSamples: 65536,
    ),
  };

  ProfileValidationSpec resolve(GenerationConfig config) {
    return explicitSpecs[config.metadata.name] ?? ProfileValidationSpec(constraints: infer(config));
  }

  ProfileConstraints infer(GenerationConfig config) {
    final tags = config.metadata.tags.map((tag) => tag.toLowerCase()).toSet();
    final layers = config.layers;

    final noiseColors = <NoiseColor>[];
    var hasBandpass = false;
    var hasLowpass = false;
    var hasDynamicGain = false;
    var hasBurstLikeDynamics = false;
    var hasRandomOrDrift = false;
    var minBandLow = double.infinity;
    var maxBandHigh = 0.0;

    for (final layer in layers) {
      final noiseConfig = layer.source.noiseConfig;
      if (noiseConfig != null) {
        noiseColors.add(noiseConfig.color);
        minBandLow = math.min(minBandLow, noiseConfig.band.low.toDouble());
        maxBandHigh = math.max(maxBandHigh, noiseConfig.band.high.toDouble());
      }

      for (final processor in layer.processors) {
        final biquad = processor.biquad;
        if (biquad == null) {
          continue;
        }
        if (biquad.biquadMode == BiquadMode.bandpass) {
          hasBandpass = true;
        }
        if (biquad.biquadMode == BiquadMode.lowpass) {
          hasLowpass = true;
        }
      }

      for (final modulation in layer.modulations) {
        if (modulation.type == ModulationType.burst || modulation.type == ModulationType.envelope) {
          hasBurstLikeDynamics = true;
        }
        if (modulation.type == ModulationType.random || modulation.type == ModulationType.drift) {
          hasRandomOrDrift = true;
        }

        for (final target in modulation.targets) {
          if (target.path.contains('.gain') || target.path.endsWith('].gain') || target.path.endsWith('.gain')) {
            hasDynamicGain = true;
          }
        }
      }

      if (layer.events.isNotEmpty) {
        hasBurstLikeDynamics = true;
      }
    }

    final hasBrown = noiseColors.contains(NoiseColor.brown);
    final hasWhite = noiseColors.contains(NoiseColor.white);
    final hasPink = noiseColors.contains(NoiseColor.pink);
    final isMidFocused = hasBandpass || (minBandLow >= 300.0 && maxBandHigh <= 4500.0);

    if (tags.contains('sleep') ||
        tags.contains('low-frequency') ||
        hasBrown && !hasBurstLikeDynamics && !hasDynamicGain) {
      return const ProfileConstraints(
        label: 'sleep-like',
        spectralSlope: ValidationRange(-3.2, -0.6),
        rmsVariance: ValidationRange(0, 0.02),
        crestFactor: ValidationRange(1.1, 6),
        flatness: ValidationRange(0.02, 0.8),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.02),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.30, 1),
          'mid': ValidationRange(0, 0.5),
          'high': ValidationRange(0, 0.25),
        },
        allowBursts: false,
      );
    }

    if (hasBurstLikeDynamics || tags.contains('dynamic') || tags.contains('storm') || tags.contains('vivid')) {
      return const ProfileConstraints(
        label: 'burst-dynamic',
        spectralSlope: ValidationRange(-2.5, 0.5),
        rmsVariance: ValidationRange(0, 0.2),
        crestFactor: ValidationRange(1.5, 10),
        flatness: ValidationRange(0.1, 0.9),
        dcOffsetAbs: ValidationRange(0, 0.1),
        clippedRatio: ValidationRange(0, 0.05),
        windowedRmsVariance: ValidationRange(0.002, 0.2),
        burstFactor: ValidationRange(1.3, 8),
        allowBursts: true,
      );
    }

    if (hasDynamicGain) {
      return const ProfileConstraints(
        label: 'gain-modulated noise',
        spectralSlope: ValidationRange(-2.2, -0.2),
        rmsVariance: ValidationRange(0, 0.06),
        crestFactor: ValidationRange(1.5, 6),
        flatness: ValidationRange(0.15, 0.9),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0.0003, 0.08),
        burstFactor: ValidationRange(1.1, 1.9),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.15, 0.6),
          'mid': ValidationRange(0.15, 0.6),
          'high': ValidationRange(0.05, 0.45),
        },
        allowBursts: false,
      );
    }

    if (isMidFocused) {
      return const ProfileConstraints(
        label: 'mid-focused noise',
        spectralSlope: ValidationRange(-2, 0.4),
        rmsVariance: ValidationRange(0, 0.03),
        crestFactor: ValidationRange(1.5, 6),
        flatness: ValidationRange(0.15, 0.85),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.03),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0, 0.35),
          'mid': ValidationRange(0.25, 0.9),
          'high': ValidationRange(0, 0.45),
        },
        allowBursts: false,
      );
    }

    if (hasWhite && !hasBrown && !hasPink && !hasLowpass && !hasRandomOrDrift) {
      return const ProfileConstraints(
        label: 'broadband white noise',
        spectralSlope: ValidationRange(-0.8, 0.5),
        rmsVariance: ValidationRange(0, 0.02),
        crestFactor: ValidationRange(1.4, 6),
        flatness: ValidationRange(0.35, 1),
        dcOffsetAbs: ValidationRange(0, 0.08),
        clippedRatio: ValidationRange(0, 0.001),
        windowedRmsVariance: ValidationRange(0, 0.02),
        burstFactor: ValidationRange(1, 1.8),
        bandEnergy: <String, ValidationRange>{
          'low': ValidationRange(0.1, 0.5),
          'mid': ValidationRange(0.1, 0.6),
          'high': ValidationRange(0.1, 0.6),
        },
        allowBursts: false,
      );
    }

    return const ProfileConstraints(
      label: 'generic ambience',
      spectralSlope: ValidationRange(-3.5, 0.8),
      rmsVariance: ValidationRange(0, 0.1),
      crestFactor: ValidationRange(1, 10),
      flatness: ValidationRange(0.05, 1),
      dcOffsetAbs: ValidationRange(0, 0.1),
      clippedRatio: ValidationRange(0, 0.05),
      windowedRmsVariance: ValidationRange(0, 0.1),
      burstFactor: ValidationRange(1, 4),
    );
  }
}

TemporalStats _summarize(List<double> values) {
  if (values.isEmpty) {
    return const TemporalStats(mean: 0, variance: 0, min: 0, max: 0);
  }

  var sum = 0.0;
  var minValue = double.infinity;
  var maxValue = -double.infinity;
  for (final value in values) {
    sum += value;
    minValue = math.min(minValue, value);
    maxValue = math.max(maxValue, value);
  }
  final mean = sum / values.length;

  var variance = 0.0;
  for (final value in values) {
    final delta = value - mean;
    variance += delta * delta;
  }
  variance /= values.length;

  return TemporalStats(
    mean: mean,
    variance: variance,
    min: minValue,
    max: maxValue,
  );
}

double _rms(Float32List samples) {
  var sumSquares = 0.0;
  for (final sample in samples) {
    sumSquares += sample * sample;
  }
  return math.sqrt(sumSquares / samples.length);
}

double _spectralCentroidHz(
  WelchPsdResult psd, {
  required double minFrequencyHz,
  required double maxFrequencyHz,
}) {
  var weighted = 0.0;
  var total = 0.0;
  for (var i = 0; i < psd.frequenciesHz.length; i++) {
    final frequency = psd.frequenciesHz[i];
    if (frequency < minFrequencyHz || frequency > maxFrequencyHz) {
      continue;
    }
    final power = psd.power[i];
    weighted += frequency * power;
    total += power;
  }

  if (total <= 0.0) {
    return 0;
  }
  return weighted / total;
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
