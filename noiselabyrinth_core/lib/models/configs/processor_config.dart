import 'package:noiselabyrinth_core/models/enums.dart';

/// Processor node definition for a layer signal chain.
class ProcessorConfig {
  const ProcessorConfig({
    required this.id,
    required this.type,
    this.biquad,
    this.gain,
    this.saturator,
    this.delay,
  });

  factory ProcessorConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? ProcessorType.biquad.name;
    final parsedType = ProcessorType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => ProcessorType.biquad,
    );

    return ProcessorConfig(
      id: json['id'] as String? ?? '',
      type: parsedType,
      biquad: json['biquad'] != null ? BiquadConfig.fromJson(json['biquad'] as Map<String, dynamic>) : null,
      gain: json['gain'] != null ? GainConfig.fromJson(json['gain'] as Map<String, dynamic>) : null,
      saturator: json['saturator'] != null ? SaturatorConfig.fromJson(json['saturator'] as Map<String, dynamic>) : null,
      delay: json['delay'] != null ? DelayConfig.fromJson(json['delay'] as Map<String, dynamic>) : null,
    );
  }

  /// Unique identifier of the processor within a layer.
  final String id;

  /// Selected processor type for this processor node.
  final ProcessorType type;

  /// Biquad filter settings, required when type is biquad.
  final BiquadConfig? biquad;

  /// Gain processor settings, required when type is gain.
  final GainConfig? gain;

  /// Saturator processor settings, required when type is saturator.
  final SaturatorConfig? saturator;

  /// Delay processor settings, required when type is delay.
  final DelayConfig? delay;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      if (biquad != null) 'biquad': biquad!.toJson(),
      if (gain != null) 'gain': gain!.toJson(),
      if (saturator != null) 'saturator': saturator!.toJson(),
      if (delay != null) 'delay': delay!.toJson(),
    };
  }
}

/// Biquad filter settings.
class BiquadConfig {
  const BiquadConfig({
    this.biquadMode = BiquadMode.lowpass,
    this.frequency = 500,
    this.q = 1.7,
    this.gainDb = 0.0,
    this.resonant = false,
  });

  factory BiquadConfig.fromJson(Map<String, dynamic> json) {
    final modeName = json['biquadMode'] as String? ?? BiquadMode.lowpass.name;
    final parsedMode = BiquadMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => BiquadMode.lowpass,
    );

    return BiquadConfig(
      biquadMode: parsedMode,
      frequency: json['frequency'] as int? ?? 500,
      q: (json['q'] as num?)?.toDouble() ?? 1.7,
      gainDb: (json['gainDb'] as num?)?.toDouble() ?? 0.0,
      resonant: json['resonant'] as bool? ?? false,
    );
  }

  /// Biquad filter mode.
  final BiquadMode biquadMode;

  /// Biquad center or cutoff frequency in Hz.
  final int frequency;

  /// Biquad Q factor controlling resonance width.
  final double q;

  /// Biquad gain in dB for filter modes that use gain.
  final double gainDb;

  /// Whether resonance behavior is explicitly enabled for the filter.
  final bool resonant;

  Map<String, dynamic> toJson() {
    return {
      'biquadMode': biquadMode.name,
      'frequency': frequency,
      'q': q,
      'gainDb': gainDb,
      'resonant': resonant,
    };
  }
}

/// Gain processor settings.
class GainConfig {
  const GainConfig({this.gain = 1.0});

  factory GainConfig.fromJson(Map<String, dynamic> json) {
    return GainConfig(gain: (json['gain'] as num?)?.toDouble() ?? 1.0);
  }

  /// Linear gain multiplier for the gain processor.
  final double gain;

  Map<String, dynamic> toJson() {
    return {'gain': gain};
  }
}

/// Saturator processor settings.
class SaturatorConfig {
  const SaturatorConfig({this.drive = 0.0, this.curve = SaturatorCurve.tanh});

  factory SaturatorConfig.fromJson(Map<String, dynamic> json) {
    final curveName = json['curve'] as String? ?? SaturatorCurve.tanh.name;
    final parsedCurve = SaturatorCurve.values.firstWhere(
      (value) => value.name == curveName,
      orElse: () => SaturatorCurve.tanh,
    );

    return SaturatorConfig(
      drive: (json['drive'] as num?)?.toDouble() ?? 0.0,
      curve: parsedCurve,
    );
  }

  /// Input drive amount applied before saturation.
  final double drive;

  /// Saturation transfer curve model.
  final SaturatorCurve curve;

  Map<String, dynamic> toJson() {
    return {'drive': drive, 'curve': curve.name};
  }
}

/// Delay processor settings.
class DelayConfig {
  const DelayConfig({
    this.delayTimeMs = 120,
    this.feedback = 0.3,
    this.mix = 0.2,
  });

  factory DelayConfig.fromJson(Map<String, dynamic> json) {
    return DelayConfig(
      delayTimeMs: json['delayTimeMs'] as int? ?? 120,
      feedback: (json['feedback'] as num?)?.toDouble() ?? 0.3,
      mix: (json['mix'] as num?)?.toDouble() ?? 0.2,
    );
  }

  /// Delay time in milliseconds.
  final int delayTimeMs;

  /// Feedback amount routed from delay output back to input, from 0 to 1.
  final double feedback;

  /// Wet mix of delayed signal in the processor output, from 0 to 1.
  final double mix;

  Map<String, dynamic> toJson() {
    return {'delayTimeMs': delayTimeMs, 'feedback': feedback, 'mix': mix};
  }
}
