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

GenerationConfig calmPersonalityProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Personality: Calm',
    description: 'Rounded pink texture designed to stay stable and unobtrusive.',
    tags: <String>['preset', 'personality', 'calm', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 8, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.52),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'personality-calm-core',
      gain: 0.46,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 70, high: 7600),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'calm-softening',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(frequency: 3600, q: 0.9),
        ),
      ],
    ),
  ],
);

GenerationConfig focusPersonalityProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Personality: Focus',
    description: 'Mid-focused bandlimited layer to support concentration.',
    tags: <String>['preset', 'personality', 'focus', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 6, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.66),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'personality-focus-mid',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 650, high: 6200),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'focus-band-shape',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.bandpass,
            frequency: 2200,
            q: 1.2,
          ),
        ),
      ],
    ),
  ],
);

GenerationConfig immersionPersonalityProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Personality: Immersion',
    description: 'Dual-layer field with low depth and airy top texture.',
    tags: <String>['preset', 'personality', 'immersion', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 12, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.62),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'personality-immersion-low',
      gain: 0.44,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(low: 30, high: 2600),
        ),
      ),
    ),
    LayerConfig(
      id: 'personality-immersion-air',
      gain: 0.33,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 2100, high: 14000),
        ),
      ),
    ),
  ],
);

GenerationConfig clarityPersonalityProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Personality: Clarity',
    description: 'High-shelf leaning texture that keeps details articulated.',
    tags: <String>['preset', 'personality', 'clarity', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 5, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.64),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'personality-clarity-edge',
      gain: 0.47,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 1000, high: 18000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'clarity-tight-highpass',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.highpass,
            frequency: 1500,
            q: 0.86,
          ),
        ),
      ],
    ),
  ],
);

List<GenerationConfig> personalityProfiles = <GenerationConfig>[
  calmPersonalityProfile,
  focusPersonalityProfile,
  immersionPersonalityProfile,
  clarityPersonalityProfile,
];
