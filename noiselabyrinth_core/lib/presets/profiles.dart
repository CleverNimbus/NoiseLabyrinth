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

GenerationConfig pinkNoiseBed = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Pink noise bed',
    description: 'Single pink-noise layer through a gentle low-pass.',
    tags: <String>['debug', 'noise', 'pink'],
    version: 1,
  ),
  render: RenderConfig(format: RenderFormat.mp3, durationMinutes: 5),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.75),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'pink-bed',
      gain: 0.55,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 40, high: 14000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'soft-lowpass',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 5200,
            q: 0.9,
          ),
        ),
      ],
    ),
  ],
);

GenerationConfig stereoBandlimitedHiss = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Stereo bandlimited hiss',
    description: 'Two filtered noise layers panned apart.',
    tags: <String>['debug', 'stereo', 'bandlimited'],
    version: 1,
  ),
  render: RenderConfig(format: RenderFormat.mp3, durationMinutes: 5),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.65),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'left-air',
      gain: 0.45,
      pan: -0.55,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 1200, high: 9000),
        ),
      ),
    ),
    LayerConfig(
      id: 'right-air',
      gain: 0.4,
      pan: 0.55,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 2600, high: 15000),
        ),
      ),
    ),
  ],
);

GenerationConfig sineDroneWithDelay = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Sine drone with delay',
    description: 'Low sine tone processed by saturation and delay.',
    tags: <String>['debug', 'sine', 'delay'],
    version: 1,
  ),
  render: RenderConfig(format: RenderFormat.mp3, durationMinutes: 5),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.5),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'sine-drone',
      gain: 0.45,
      source: SourceConfig(
        type: SourceType.sine,
        sineConfig: SineConfig(frequencyHz: 110),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'warmth',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.35),
        ),
        ProcessorConfig(
          id: 'short-delay',
          type: ProcessorType.delay,
          delay: DelayConfig(delayTimeMs: 240, feedback: 0.35, mix: 0.3),
        ),
      ],
    ),
  ],
);
