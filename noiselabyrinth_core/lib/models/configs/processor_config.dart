import 'package:noiselabyrinth_core/models/enums.dart';

class ProcessorConfig {
  final String id;
  final ProcessorType type;
  final BiquadConfig? biquad;
  final GainConfig? gain;
  final SaturatorConfig? saturator;
  final DelayConfig? delay;

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
      biquad: json['biquad'] != null
          ? BiquadConfig.fromJson(json['biquad'] as Map<String, dynamic>)
          : null,
      gain: json['gain'] != null
          ? GainConfig.fromJson(json['gain'] as Map<String, dynamic>)
          : null,
      saturator: json['saturator'] != null
          ? SaturatorConfig.fromJson(json['saturator'] as Map<String, dynamic>)
          : null,
      delay: json['delay'] != null
          ? DelayConfig.fromJson(json['delay'] as Map<String, dynamic>)
          : null,
    );
  }

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

class BiquadConfig {
  final BiquadMode biquadMode;
  final int frequency;
  final double q;
  final double gainDb;
  final bool resonant;

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

class GainConfig {
  final double gain;

  const GainConfig({this.gain = 1.0});

  factory GainConfig.fromJson(Map<String, dynamic> json) {
    return GainConfig(gain: (json['gain'] as num?)?.toDouble() ?? 1.0);
  }

  Map<String, dynamic> toJson() {
    return {'gain': gain};
  }
}

class SaturatorConfig {
  final double drive;
  final SaturatorCurve curve;

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

  Map<String, dynamic> toJson() {
    return {'drive': drive, 'curve': curve.name};
  }
}

class DelayConfig {
  final int delayTimeMs;
  final double feedback;
  final double mix;

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

  Map<String, dynamic> toJson() {
    return {'delayTimeMs': delayTimeMs, 'feedback': feedback, 'mix': mix};
  }
}
