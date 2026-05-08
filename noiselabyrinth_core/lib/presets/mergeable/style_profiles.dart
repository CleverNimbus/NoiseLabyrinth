import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/normalization_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

GenerationConfig deepStyleProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Style: Deep',
    description: 'Low-heavy profile with weight and slow breathing space.',
    tags: <String>['preset', 'style', 'deep', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 9, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.56),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'style-deep-foundation',
      gain: 0.52,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(high: 2200),
        ),
      ),
    ),
  ],
);

GenerationConfig lowStyleProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Style: Low',
    description: 'Subdued low-mid focus with restrained high-frequency content.',
    tags: <String>['preset', 'style', 'low', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 8, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.54),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'style-low-floor',
      gain: 0.49,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 90, high: 3600),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'low-floor-soft-cut',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(frequency: 3000, q: 0.95),
        ),
      ],
    ),
  ],
);

GenerationConfig vibrantStyleProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Style: Vibrant',
    description: 'More animated top-end profile for an energetic texture.',
    tags: <String>['preset', 'style', 'vibrant', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 5, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.76),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'style-vibrant-spark',
      gain: 0.57,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 1200, high: 18500),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'vibrant-spark-drive',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.28),
        ),
      ],
    ),
  ],
);

GenerationConfig mutedStyleProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Style: Muted',
    description: 'Soft-edged profile with reduced harshness and smooth masking.',
    tags: <String>['preset', 'style', 'muted', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 7, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.5),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'style-muted-veil',
      gain: 0.43,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 70, high: 6000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'muted-veil-softener',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(frequency: 2800, q: 0.8),
        ),
      ],
    ),
  ],
);

List<GenerationConfig> styleProfiles = <GenerationConfig>[
  deepStyleProfile,
  lowStyleProfile,
  vibrantStyleProfile,
  mutedStyleProfile,
];
