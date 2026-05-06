import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/normalization_config.dart';

/// Global mix controls for combining generated layers.
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

  /// Global wet mix amount applied to the generated output, from 0 to 1.
  final double mix;

  /// Optional master-stage dithering applied after layer mix and master gain.
  final DitherConfig dither;

  /// Optional master peak normalization applied to rendered output.
  final NormalizationConfig normalization;

  Map<String, dynamic> toJson() {
    return {
      'mix': mix,
      'dither': dither.toJson(),
      'normalization': normalization.toJson(),
    };
  }
}
