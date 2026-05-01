import 'package:noiselabyrinth_core/models/enums.dart';

class RenderConfig {
  final int durationMinutes;
  final int sampleRate;
  final int bitRate;
  final RenderFormat format;

  const RenderConfig({
    this.durationMinutes = 120,
    this.sampleRate = 44100,
    this.bitRate = 192,
    this.format = RenderFormat.wav,
  });

  factory RenderConfig.fromJson(Map<String, dynamic> json) {
    final formatStr = json['format'] as String? ?? 'wav';
    final format = RenderFormat.values.firstWhere(
      (e) => e.name == formatStr,
      orElse: () => RenderFormat.wav,
    );
    return RenderConfig(
      durationMinutes: json['durationMinutes'] as int? ?? 120,
      sampleRate: json['sampleRate'] as int? ?? 44100,
      bitRate: json['bitRate'] as int? ?? 192,
      format: format,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'durationMinutes': durationMinutes,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'format': format.name,
    };
  }
}
