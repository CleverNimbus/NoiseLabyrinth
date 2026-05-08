import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/normalization_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

GenerationConfig steadyFeatureProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Feature: Steady',
    description: 'Static, predictable layer with no time-varying modulation.',
    tags: <String>['preset', 'feature', 'steady', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 8, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.58),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'feature-steady-core',
      gain: 0.48,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 120, high: 12000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'steady-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 0.92),
        ),
      ],
    ),
  ],
);

GenerationConfig psychoacousticFeatureProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Feature: Psychoacoustic',
    description: 'Event-driven movement profile with controlled pulsing accents.',
    tags: <String>['preset', 'feature', 'psychoacoustic', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 6, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.64),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'feature-psychoacoustic-pulse',
      gain: 0.46,
      source: const SourceConfig(
        type: SourceType.impulse,
        impulseConfig: ImpulseConfig(density: 0.15, randomness: 0.55),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'pulse-delay',
          type: ProcessorType.delay,
          delay: DelayConfig(delayTimeMs: 180, feedback: 0.42, mix: 0.28),
        ),
      ],
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'pulse-burst',
          type: ModulationType.burst,
          amount: 1,
          burstConfig: BurstConfig(
            durationMs: 130,
            intensity: 0.8,
            randomness: 0.3,
            attackMs: 6,
            releaseMs: 90,
            clusterMax: 2,
            clusterSpreadMs: 45,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[feature-psychoacoustic-pulse].processors[pulse-delay].delay.mix',
              amount: 0.2,
              minValue: 0.1,
              maxValue: 0.65,
            ),
          ],
        ),
        ModulationConfig(
          id: 'pulse-pan-lfo',
          type: ModulationType.lfo,
          amount: 1,
          lfoConfig: LfoConfig(
            frequency: 0.18,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[feature-psychoacoustic-pulse].pan',
              amount: 0.35,
              minValue: -0.7,
              maxValue: 0.7,
            ),
          ],
        ),
      ],
      events: <EventConfig>[
        EventConfig(
          id: 'pulse-driver',
          trigger: TriggerConfig(rate: 0.25),
          actions: <ActionConfig>[
            ActionConfig(modulatorId: 'pulse-burst'),
          ],
        ),
      ],
    ),
  ],
);

GenerationConfig coloredFeatureProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Feature: Colored',
    description: 'Multi-color blend combining pink body and bright white air.',
    tags: <String>['preset', 'feature', 'colored', 'noise'],
    version: 1,
  ),
  render: const RenderConfig(durationMinutes: 7, format: RenderFormat.mp3),
  mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig(), mix: 0.62),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'feature-colored-body',
      gain: 0.4,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 80, high: 9000),
        ),
      ),
    ),
    LayerConfig(
      id: 'feature-colored-air',
      gain: 0.34,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 2200, high: 17500),
        ),
      ),
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'colored-air-random-band',
          type: ModulationType.random,
          amount: 1,
          randomConfig: RandomConfig(rateHz: 0.04, smooth: 0.88),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[feature-colored-air].source.noise.band.high',
              amount: 900,
              minValue: 12000,
              maxValue: 19500,
            ),
          ],
        ),
      ],
    ),
  ],
);

List<GenerationConfig> featureProfiles = <GenerationConfig>[
  steadyFeatureProfile,
  psychoacousticFeatureProfile,
  coloredFeatureProfile,
];
