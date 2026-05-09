import 'package:noiselabyrinth_core/models/enums.dart';

/// Rendering output settings.
class RenderConfig {
  const RenderConfig({
    this.durationMinutes = 120,
    this.sampleRate = 44100,
    this.bitRate = 192,
    this.format = RenderFormat.mp3,
    this.dcBlockerEnabled = true,
  });

  factory RenderConfig.fromJson(Map<String, dynamic> json) {
    final formatStr = json['format'] as String? ?? 'mp3';
    final format = RenderFormat.values.firstWhere(
      (e) => e.name == formatStr,
      orElse: () => RenderFormat.mp3,
    );
    return RenderConfig(
      durationMinutes: json['durationMinutes'] as int? ?? 120,
      sampleRate: json['sampleRate'] as int? ?? 44100,
      bitRate: json['bitRate'] as int? ?? 192,
      format: format,
      dcBlockerEnabled: json['dcBlockerEnabled'] as bool? ?? true,
    );
  }

  /// Total render duration in minutes.
  final int durationMinutes;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Target encoded bitrate in kbps.
  final int bitRate;

  /// Output file format for rendered audio.
  final RenderFormat format;

  /// Enables final-stage DC offset removal on the rendered stereo output.
  final bool dcBlockerEnabled;

  Map<String, dynamic> toJson() {
    return {
      'durationMinutes': durationMinutes,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'format': format.name,
      'dcBlockerEnabled': dcBlockerEnabled,
    };
  }
}
