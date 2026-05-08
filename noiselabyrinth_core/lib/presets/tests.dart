import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/normalization_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class BrownConfigs {
  static GenerationConfig brownNoiseProfile_001 = GenerationConfig(
    metadata: MetadataConfig(
      name: 'T01. Brown noise profile',
      description: 'Brown noise emphasizing low-end energy and deep rumble.',
      tags: <String>['preset', 'noise', 'brown', 'spectrum'],
      version: 1,
    ),
    render: const RenderConfig(durationMinutes: 30),
    mix: MixConfig(
      mix: 0.9,
      normalization: NormalizationConfig(enabled: true, targetDb: -1.2),
      dither: DitherConfig(enabled: true, type: DitherType.tpdf),
    ),
    layers: <LayerConfig>[
      LayerConfig(
        id: 'brown_core',
        gain: 0.85,
        source: SourceConfig(
          type: SourceType.noise,
          noiseConfig: NoiseConfig(
            color: NoiseColor.brown,
            band: BandConfig(high: 1200, low: 35),
          ),
        ),
      ),
    ],
  );

  static GenerationConfig getBrownNoiseProfile_002() {
    final brown02 = brownNoiseProfile_001;
    brown02.metadata.name = 'T02. Brown noise modulated';
    brown02.metadata.description = 'Brown noise with subtle random modulation for movement and interest.';
    brown02.layers[0].modulations = [
      ModulationConfig(
        id: 'random_pan_sweep',
        type: ModulationType.random,
        amount: 1,
        randomConfig: RandomConfig(
          rateHz: 4,
          smooth: 0.08,
        ),
        targets: [
          ModulationTargetConfig(
            path: 'layers[brown_core].pan',
            amount: 1,
            mode: ModulationApplyMode.additive,
            minValue: -1,
            maxValue: 1,
          ),
        ],
      ),
      ModulationConfig(
        id: 'random_band_high_sweep',
        type: ModulationType.random,
        amount: 1,
        randomConfig: RandomConfig(
          rateHz: 2.5,
          smooth: 0.12,
        ),
        targets: [
          ModulationTargetConfig(
            path: 'layers[brown_core].source.noise.band.high',
            amount: 300,
            mode: ModulationApplyMode.additive,
            minValue: 900,
            maxValue: 1500,
          ),
        ],
      ),
    ];
    return brown02;
  }
}
