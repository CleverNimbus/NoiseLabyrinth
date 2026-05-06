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

const GenerationConfig brownNoiseProfile_001 = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Brown noise profile',
    description: 'Brown noise emphasizing low-end energy and deep rumble.',
    tags: <String>['preset', 'noise', 'brown', 'spectrum'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 5),
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
      modulations: [
        ModulationConfig(
          id: 'slow_drift',
          type: ModulationType.drift,
          amount: 0.6,
          driftConfig: DriftConfig(
            range: 0.45,
          ),
          targets: [
            ModulationTargetConfig(
              path: 'layers[brown_core].pan',
              mode: ModulationApplyMode.additive,
              amount: 0.7,
            ),
          ],
        ),
      ],
    ),
  ],
);
