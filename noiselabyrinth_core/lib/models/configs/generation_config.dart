import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';

/// Top-level generation preset configuration.
class GenerationConfig {
  const GenerationConfig({
    required this.metadata,
    required this.render,
    required this.mix,
    required this.layers,
  });

  factory GenerationConfig.fromJson(Map<String, dynamic> json) {
    /// Metadata for the generation preset, including name, tags, and version.
    return GenerationConfig(
      /// Rendering output settings such as duration, sample rate, bitrate, and format.
      metadata: MetadataConfig.fromJson(
        /// Global mix controls for combining generated layers.
        json['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{},

        /// List of audio layers that define sources, processing, modulation, and events.
      ),
      render: RenderConfig.fromJson(
        json['render'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      mix: MixConfig.fromJson(
        json['mix'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      layers: (json['layers'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => LayerConfig.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
  final MetadataConfig metadata;
  final RenderConfig render;
  final MixConfig mix;
  final List<LayerConfig> layers;

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'render': render.toJson(),
      'mix': mix.toJson(),
      'layers': layers.map((e) => e.toJson()).toList(),
    };
  }
}
