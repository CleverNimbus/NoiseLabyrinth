import 'package:noiselabyrinth_core/models/enums.dart';

/// Modulation source definition for a layer.
class ModulationConfig {
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
      lfoConfig: json['lfoConfig'] != null ? LfoConfig.fromJson(json['lfoConfig'] as Map<String, dynamic>) : null,
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

  /// Unique identifier of the modulation source within a layer.
  final String id;

  /// Selected modulation source type.
  final ModulationType type;

  /// Global scaling amount applied by this modulation source.
  final double amount;

  /// LFO settings, required when type is lfo.
  final LfoConfig? lfoConfig;

  /// Random modulation settings, required when type is random.
  final RandomConfig? randomConfig;

  /// Drift modulation settings, required when type is drift.
  final DriftConfig? driftConfig;

  /// Envelope modulation settings, required when type is envelope.
  final EnvelopeConfig? envelopeConfig;

  /// Burst modulation settings, required when type is burst.
  final BurstConfig? burstConfig;

  /// List of parameter targets affected by this modulation source.
  final List<ModulationTargetConfig> targets;

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

/// Target parameter configuration for a modulation source.
class ModulationTargetConfig {
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

  /// Target parameter path to modulate.
  final String path;

  /// Per-target scaling amount applied in addition to modulation amount.
  final double amount;

  /// How modulation is applied to the target parameter value.
  final ModulationApplyMode mode;

  /// Optional lower clamp for the modulated target value.
  final double? minValue;

  /// Optional upper clamp for the modulated target value.
  final double? maxValue;

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

/// LFO modulation settings.
class LfoConfig {
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

  /// LFO waveform shape.
  final LFOType type;

  /// LFO frequency in Hz.
  final double frequency;

  /// LFO depth amount applied to modulation output.
  final double depth;

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'frequency': frequency, 'depth': depth};
  }
}

/// Random modulation settings.
class RandomConfig {
  const RandomConfig({this.rateHz = 0.05, this.smooth = 0.9});

  factory RandomConfig.fromJson(Map<String, dynamic> json) {
    return RandomConfig(
      rateHz: (json['rateHz'] as num?)?.toDouble() ?? 0.05,
      smooth: (json['smooth'] as num?)?.toDouble() ?? 0.9,
    );
  }

  /// Update rate in Hz for random modulation changes.
  final double rateHz;

  /// Smoothing factor for random transitions, from 0 to 1.
  final double smooth;

  Map<String, dynamic> toJson() {
    return {'rateHz': rateHz, 'smooth': smooth};
  }
}

/// Drift modulation settings.
class DriftConfig {
  const DriftConfig({this.speed = 0.01, this.range = 1.0});

  factory DriftConfig.fromJson(Map<String, dynamic> json) {
    return DriftConfig(
      speed: (json['speed'] as num?)?.toDouble() ?? 0.01,
      range: (json['range'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Rate at which drift evolves over time.
  final double speed;

  /// Maximum drift excursion range.
  final double range;

  Map<String, dynamic> toJson() {
    return {'speed': speed, 'range': range};
  }
}

/// Envelope modulation settings.
class EnvelopeConfig {
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

  /// Attack stage duration in milliseconds.
  final int attackMs;

  /// Decay stage duration in milliseconds.
  final int decayMs;

  /// Sustain level from 0 to 1.
  final double sustain;

  /// Release stage duration in milliseconds.
  final int releaseMs;

  Map<String, dynamic> toJson() {
    return {
      'attackMs': attackMs,
      'decayMs': decayMs,
      'sustain': sustain,
      'releaseMs': releaseMs,
    };
  }
}

/// Burst modulation settings.
class BurstConfig {
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

  /// Total burst duration in milliseconds.
  final int durationMs;

  /// Burst intensity from 0 to 1.
  final double intensity;

  /// Random variation amount within bursts, from 0 to 1.
  final double randomness;

  /// Burst attack duration in milliseconds.
  final int attackMs;

  /// Burst release duration in milliseconds.
  final int releaseMs;

  /// Minimum number of events per burst cluster.
  final int clusterMin;

  /// Maximum number of events per burst cluster.
  final int clusterMax;

  /// Temporal spread in milliseconds between clustered events.
  final int clusterSpreadMs;

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
