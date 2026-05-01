import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class SourceConfig {
  const SourceConfig({
    required this.type,
    this.noiseConfig,
    this.impulseConfig,
    this.sineConfig,
  });

  factory SourceConfig.fromJson(Map<String, dynamic> json) {
    return SourceConfig(
      type: SourceType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => SourceType.noise,
      ),
      noiseConfig: json['noiseConfig'] != null
          ? NoiseConfig.fromJson(json['noiseConfig'] as Map<String, dynamic>)
          : null,
      impulseConfig: json['impulseConfig'] != null
          ? ImpulseConfig.fromJson(
              json['impulseConfig'] as Map<String, dynamic>,
            )
          : null,
      sineConfig: json['sineConfig'] != null ? SineConfig.fromJson(json['sineConfig'] as Map<String, dynamic>) : null,
    );
  }
  final SourceType type;
  final NoiseConfig? noiseConfig;
  final ImpulseConfig? impulseConfig;
  final SineConfig? sineConfig;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (noiseConfig != null) 'noiseConfig': noiseConfig!.toJson(),
      if (impulseConfig != null) 'impulseConfig': impulseConfig!.toJson(),
      if (sineConfig != null) 'sineConfig': sineConfig!.toJson(),
    };
  }
}

class NoiseConfig {
  const NoiseConfig({required this.color, required this.band});

  factory NoiseConfig.fromJson(Map<String, dynamic> json) {
    return NoiseConfig(
      color: NoiseColor.values.firstWhere(
        (value) => value.name == json['color'],
        orElse: () => NoiseColor.white,
      ),
      band: BandConfig.fromJson(
        json['band'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
  final NoiseColor color;
  final BandConfig band;

  Map<String, dynamic> toJson() {
    return {'color': color.name, 'band': band.toJson()};
  }
}

class SineConfig {
  const SineConfig({this.frequencyHz = 100, this.phase = 0.0});

  factory SineConfig.fromJson(Map<String, dynamic> json) {
    return SineConfig(
      frequencyHz: json['frequencyHz'] as int? ?? 100,
      phase: (json['phase'] as num?)?.toDouble() ?? 0.0,
    );
  }
  final int frequencyHz;
  final double phase;

  Map<String, dynamic> toJson() {
    return {'frequencyHz': frequencyHz, 'phase': phase};
  }
}

class ImpulseConfig {
  const ImpulseConfig({this.density = 0.2, this.randomness = 0.5});

  factory ImpulseConfig.fromJson(Map<String, dynamic> json) {
    return ImpulseConfig(
      density: (json['density'] as num?)?.toDouble() ?? 0.2,
      randomness: (json['randomness'] as num?)?.toDouble() ?? 0.5,
    );
  }
  final double density;
  final double randomness;

  Map<String, dynamic> toJson() {
    return {'density': density, 'randomness': randomness};
  }
}
