import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

/// Primary source definition for a layer.
class SourceConfig {
  SourceConfig({
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

  /// Selected source generator type for this layer.
  SourceType type;

  /// Configuration for noise source generation, required when type is noise.
  NoiseConfig? noiseConfig;

  /// Configuration for impulse source generation, required when type is impulse.
  ImpulseConfig? impulseConfig;

  /// Configuration for sine source generation, required when type is sine.
  SineConfig? sineConfig;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (noiseConfig != null) 'noiseConfig': noiseConfig!.toJson(),
      if (impulseConfig != null) 'impulseConfig': impulseConfig!.toJson(),
      if (sineConfig != null) 'sineConfig': sineConfig!.toJson(),
    };
  }
}

/// Noise source generation settings.
class NoiseConfig {
  NoiseConfig({required this.color, required this.band});

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

  /// Noise color algorithm used to shape spectral distribution.
  NoiseColor color;

  /// Frequency band limits applied to band-limited noise generation.
  /// Ignored for other noise colors.
  BandConfig band;

  Map<String, dynamic> toJson() {
    return {'color': color.name, 'band': band.toJson()};
  }
}

/// Sine source generation settings.
class SineConfig {
  SineConfig({this.frequencyHz = 100, this.phase = 0.0});

  factory SineConfig.fromJson(Map<String, dynamic> json) {
    return SineConfig(
      frequencyHz: json['frequencyHz'] as int? ?? 100,
      phase: (json['phase'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Sine oscillator frequency in Hz.
  int frequencyHz;

  /// Initial sine oscillator phase offset in normalized phase units.
  double phase;

  Map<String, dynamic> toJson() {
    return {'frequencyHz': frequencyHz, 'phase': phase};
  }
}

/// Impulse source generation settings.
class ImpulseConfig {
  ImpulseConfig({this.density = 0.2, this.randomness = 0.5});

  factory ImpulseConfig.fromJson(Map<String, dynamic> json) {
    return ImpulseConfig(
      density: (json['density'] as num?)?.toDouble() ?? 0.2,
      randomness: (json['randomness'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Average impulse density, from 0 to 1.
  double density;

  /// Randomness applied to impulse timing or distribution, from 0 to 1.
  double randomness;

  Map<String, dynamic> toJson() {
    return {'density': density, 'randomness': randomness};
  }
}
