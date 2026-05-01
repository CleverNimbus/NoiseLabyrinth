import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/normalization_config.dart';

class MixConfig {
  const MixConfig({
    this.mix = 1.0,
    this.dither = const DitherConfig(),
    this.normalization = const NormalizationConfig(),
  });

  factory MixConfig.fromJson(Map<String, dynamic> json) {
    return MixConfig(
      mix: (json['mix'] as num?)?.toDouble() ?? 1.0,
      dither: DitherConfig.fromJson(
        json['dither'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      normalization: NormalizationConfig.fromJson(
        json['normalization'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
  final double mix;
  final DitherConfig dither;
  final NormalizationConfig normalization;

  Map<String, dynamic> toJson() {
    return {
      'mix': mix,
      'dither': dither.toJson(),
      'normalization': normalization.toJson(),
    };
  }
}
