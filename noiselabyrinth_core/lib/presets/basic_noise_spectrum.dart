import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

const GenerationConfig whiteNoiseProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'White noise profile',
    description: 'Flat-spectrum white noise from low rumble to high air.',
    tags: <String>['preset', 'noise', 'white', 'spectrum'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 5),
  mix: MixConfig(mix: 0.9),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'white-noise-layer',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'white-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 0.95),
        ),
      ],
    ),
  ],
);

const GenerationConfig pinkNoiseProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Pink noise profile',
    description: 'Pink noise with naturally softer highs for balanced ambience checks.',
    tags: <String>['preset', 'noise', 'pink', 'spectrum'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 5),
  mix: MixConfig(mix: 0.9),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'pink-noise-layer',
      gain: 0.52,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'pink-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 0.95),
        ),
      ],
    ),
  ],
);

const GenerationConfig brownNoiseProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Brown noise profile',
    description: 'Brown noise emphasizing low-end energy and deep rumble.',
    tags: <String>['preset', 'noise', 'brown', 'spectrum'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 5),
  mix: MixConfig(mix: 0.9),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'brown-noise-layer',
      gain: 0.45,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(high: 12000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'brown-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 0.9),
        ),
      ],
    ),
  ],
);

const GenerationConfig bandlimitedNoiseProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Bandlimited noise profile',
    description: 'Bandlimited noise focused on the midrange for texture and masking.',
    tags: <String>['preset', 'noise', 'bandlimited', 'spectrum'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 5),
  mix: MixConfig(mix: 0.9),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'bandlimited-noise-layer',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 400, high: 4000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'bandlimited-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 0.95),
        ),
      ],
    ),
  ],
);

const List<GenerationConfig> basicNoiseSpectrumProfiles = <GenerationConfig>[
  whiteNoiseProfile,
  pinkNoiseProfile,
  brownNoiseProfile,
  bandlimitedNoiseProfile,
];
