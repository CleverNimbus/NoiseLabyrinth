import 'package:noiselabyrinth_core/models/enums.dart';

class ModulationConfig {
  final String id;
  final ModulationType type;
  final double amount;
  final LfoConfig? lfoConfig;
  final RandomConfig? randomConfig;
  final DriftConfig? driftConfig;
  final EnvelopeConfig? envelopeConfig;
  final BurstConfig? burstConfig;
  final List<ModulationTargetConfig> targets;

  const ModulationConfig({
    required this.id,
    required this.type,
    this.amount = 0.0,
    this.lfoConfig,
    this.randomConfig,
    this.driftConfig,
    this.envelopeConfig,
    this.burstConfig,
    this.targets = const <ModulationTargetConfig>[],
  });

  factory ModulationConfig.fromJson(Map<String, dynamic> json) {
    final parsedType = _parseModulationType(json['type'] as String?);

    return ModulationConfig(
      id: json['id'] as String? ?? '',
      type: parsedType,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      lfoConfig: json['lfoConfig'] != null
          ? LfoConfig.fromJson(json['lfoConfig'] as Map<String, dynamic>)
          : null,
      randomConfig: json['randomConfig'] != null
          ? RandomConfig.fromJson(json['randomConfig'] as Map<String, dynamic>)
          : null,
      driftConfig: json['driftConfig'] != null
          ? DriftConfig.fromJson(json['driftConfig'] as Map<String, dynamic>)
          : null,
      envelopeConfig: json['envelopeConfig'] != null
          ? EnvelopeConfig.fromJson(
              json['envelopeConfig'] as Map<String, dynamic>,
            )
          : null,
      burstConfig: json['burstConfig'] != null
          ? BurstConfig.fromJson(json['burstConfig'] as Map<String, dynamic>)
          : null,
      targets:
          (json['targets'] as List<dynamic>?)
              ?.map(
                (target) => ModulationTargetConfig.fromJson(
                  target as Map<String, dynamic>,
                ),
              )
              .toList(growable: false) ??
          const <ModulationTargetConfig>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      if (lfoConfig != null) 'lfoConfig': lfoConfig!.toJson(),
      if (randomConfig != null) 'randomConfig': randomConfig!.toJson(),
      if (driftConfig != null) 'driftConfig': driftConfig!.toJson(),
      if (envelopeConfig != null) 'envelopeConfig': envelopeConfig!.toJson(),
      if (burstConfig != null) 'burstConfig': burstConfig!.toJson(),
      'targets': targets.map((target) => target.toJson()).toList(),
    };
  }

  static ModulationType _parseModulationType(String? rawType) {
    switch (rawType) {
      case 'random':
        return ModulationType.random;
      case 'drift':
        return ModulationType.drift;
      case 'envelope':
        return ModulationType.envelope;
      case 'burst':
        return ModulationType.burst;
      case 'lfo':
      default:
        return ModulationType.lfo;
    }
  }
}

class ModulationTargetConfig {
  final String path;
  final double amount;
  final ModulationApplyMode mode;
  final double? minValue;
  final double? maxValue;

  const ModulationTargetConfig({
    required this.path,
    this.amount = 1.0,
    this.mode = ModulationApplyMode.additive,
    this.minValue,
    this.maxValue,
  });

  factory ModulationTargetConfig.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String?;
    final mode = ModulationApplyMode.values.firstWhere(
      (value) => value.name == rawMode,
      orElse: () => ModulationApplyMode.additive,
    );

    return ModulationTargetConfig(
      path: json['path'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      mode: mode,
      minValue: (json['minValue'] as num?)?.toDouble(),
      maxValue: (json['maxValue'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'amount': amount,
      'mode': mode.name,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
    };
  }
}

class LfoConfig {
  final LFOType type;
  final double frequency;
  final double depth;

  const LfoConfig({
    this.type = LFOType.sine,
    this.frequency = 1.0,
    this.depth = 1.0,
  });

  factory LfoConfig.fromJson(Map<String, dynamic> json) {
    return LfoConfig(
      type: LFOType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => LFOType.sine,
      ),
      frequency: (json['frequency'] as num?)?.toDouble() ?? 1.0,
      depth: (json['depth'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'frequency': frequency, 'depth': depth};
  }
}

class RandomConfig {
  final double rateHz;
  final double smooth;

  const RandomConfig({this.rateHz = 0.05, this.smooth = 0.9});

  factory RandomConfig.fromJson(Map<String, dynamic> json) {
    return RandomConfig(
      rateHz: (json['rateHz'] as num?)?.toDouble() ?? 0.05,
      smooth: (json['smooth'] as num?)?.toDouble() ?? 0.9,
    );
  }

  Map<String, dynamic> toJson() {
    return {'rateHz': rateHz, 'smooth': smooth};
  }
}

class DriftConfig {
  final double speed;
  final double range;

  const DriftConfig({this.speed = 0.01, this.range = 1.0});

  factory DriftConfig.fromJson(Map<String, dynamic> json) {
    return DriftConfig(
      speed: (json['speed'] as num?)?.toDouble() ?? 0.01,
      range: (json['range'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'speed': speed, 'range': range};
  }
}

class EnvelopeConfig {
  final int attackMs;
  final int decayMs;
  final double sustain;
  final int releaseMs;

  const EnvelopeConfig({
    this.attackMs = 50,
    this.decayMs = 200,
    this.sustain = 0.0,
    this.releaseMs = 300,
  });

  factory EnvelopeConfig.fromJson(Map<String, dynamic> json) {
    return EnvelopeConfig(
      attackMs: json['attackMs'] as int? ?? 50,
      decayMs: json['decayMs'] as int? ?? 200,
      sustain: (json['sustain'] as num?)?.toDouble() ?? 0.0,
      releaseMs: json['releaseMs'] as int? ?? 300,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attackMs': attackMs,
      'decayMs': decayMs,
      'sustain': sustain,
      'releaseMs': releaseMs,
    };
  }
}

class BurstConfig {
  final int durationMs;
  final double intensity;
  final double randomness;
  final int attackMs;
  final int releaseMs;
  final int clusterMin;
  final int clusterMax;
  final int clusterSpreadMs;

  const BurstConfig({
    this.durationMs = 120,
    this.intensity = 1.0,
    this.randomness = 0.5,
    this.attackMs = 8,
    this.releaseMs = 80,
    this.clusterMin = 1,
    this.clusterMax = 1,
    this.clusterSpreadMs = 0,
  });

  factory BurstConfig.fromJson(Map<String, dynamic> json) {
    return BurstConfig(
      durationMs: json['durationMs'] as int? ?? 120,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
      randomness: (json['randomness'] as num?)?.toDouble() ?? 0.5,
      attackMs: json['attackMs'] as int? ?? 8,
      releaseMs: json['releaseMs'] as int? ?? 80,
      clusterMin: json['clusterMin'] as int? ?? 1,
      clusterMax: json['clusterMax'] as int? ?? 1,
      clusterSpreadMs: json['clusterSpreadMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'durationMs': durationMs,
      'intensity': intensity,
      'randomness': randomness,
      'attackMs': attackMs,
      'releaseMs': releaseMs,
      'clusterMin': clusterMin,
      'clusterMax': clusterMax,
      'clusterSpreadMs': clusterSpreadMs,
    };
  }
}
