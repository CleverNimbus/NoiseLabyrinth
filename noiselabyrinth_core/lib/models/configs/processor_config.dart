import 'package:noiselabyrinth_core/models/enums.dart';

/// Processor node definition for a layer signal chain.
class ProcessorConfig {
  ProcessorConfig({
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
  String id;

  /// Selected processor type for this processor node.
  ProcessorType type;

  /// Biquad filter settings, required when type is biquad.
  BiquadConfig? biquad;

  /// Gain processor settings, required when type is gain.
  GainConfig? gain;

  /// Saturator processor settings, required when type is saturator.
  SaturatorConfig? saturator;

  /// Delay processor settings, required when type is delay.
  DelayConfig? delay;

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
  BiquadConfig({
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
  BiquadMode biquadMode;

  /// Biquad center or cutoff frequency in Hz.
  int frequency;

  /// Biquad Q factor controlling resonance width.
  double q;

  /// Biquad gain in dB for filter modes that use gain.
  double gainDb;

  /// Whether resonance behavior is explicitly enabled for the filter.
  bool resonant;

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
  GainConfig({this.gain = 1.0});

  factory GainConfig.fromJson(Map<String, dynamic> json) {
    return GainConfig(gain: (json['gain'] as num?)?.toDouble() ?? 1.0);
  }

  /// Linear gain multiplier for the gain processor.
  double gain;

  Map<String, dynamic> toJson() {
    return {'gain': gain};
  }
}

/// Saturator processor settings.
class SaturatorConfig {
  SaturatorConfig({this.drive = 0.0, this.curve = SaturatorCurve.tanh});

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
  double drive;

  /// Saturation transfer curve model.
  SaturatorCurve curve;

  Map<String, dynamic> toJson() {
    return {'drive': drive, 'curve': curve.name};
  }
}

/// Delay processor settings.
class DelayConfig {
  DelayConfig({
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
  int delayTimeMs;

  /// Feedback amount routed from delay output back to input, from 0 to 1.
  double feedback;

  /// Wet mix of delayed signal in the processor output, from 0 to 1.
  double mix;

  Map<String, dynamic> toJson() {
    return {'delayTimeMs': delayTimeMs, 'feedback': feedback, 'mix': mix};
  }
}
