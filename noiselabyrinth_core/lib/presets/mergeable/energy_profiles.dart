import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

const GenerationConfig relaxEnergyProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Energy: Relax',
    description: 'Soft pink bed with gentle rolloff for downshifting energy.',
    tags: <String>['preset', 'energy', 'relax', 'noise'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 10, format: RenderFormat.mp3),
  mix: MixConfig(mix: 0.55),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'energy-relax-bed',
      gain: 0.44,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 60, high: 9000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'relax-soft-lowpass',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 4300,
            q: 0.82,
          ),
        ),
      ],
    ),
  ],
);

const GenerationConfig sleepEnergyProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Energy: Sleep',
    description: 'Deep brown foundation tuned for low-distraction sleep support.',
    tags: <String>['preset', 'energy', 'sleep', 'noise'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 20, format: RenderFormat.mp3),
  mix: MixConfig(mix: 0.48),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'energy-sleep-drift',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(high: 2800),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'sleep-rounding-lowpass',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 1800,
            q: 0.75,
          ),
        ),
      ],
    ),
  ],
);

const GenerationConfig activationEnergyProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Energy: Activation',
    description: 'Bright white layer with mild drive to increase alertness.',
    tags: <String>['preset', 'energy', 'activation', 'noise'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 4, format: RenderFormat.mp3),
  mix: MixConfig(mix: 0.72),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'energy-activation-bright',
      gain: 0.52,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 180, high: 18000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'activation-drive',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.18),
        ),
      ],
    ),
  ],
);

const GenerationConfig highEnergyProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Energy: High',
    description: 'Dense upper-band texture with stronger excitement and edge.',
    tags: <String>['preset', 'energy', 'high', 'noise'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 3, format: RenderFormat.mp3),
  mix: MixConfig(mix: 0.82),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'energy-high-rush',
      gain: 0.58,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.bandlimited,
          band: BandConfig(low: 1400, high: 17000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'high-rush-drive',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.35),
        ),
        ProcessorConfig(
          id: 'high-rush-level',
          type: ProcessorType.gain,
          gain: GainConfig(gain: 1.05),
        ),
      ],
    ),
  ],
);

const GenerationConfig ambianceEnergyProfile = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Energy: Ambiance',
    description: 'Wide stereo air with light, non-intrusive movement.',
    tags: <String>['preset', 'energy', 'ambiance', 'noise'],
    version: 1,
  ),
  render: RenderConfig(durationMinutes: 12, format: RenderFormat.mp3),
  mix: MixConfig(mix: 0.6),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'energy-ambiance-left',
      gain: 0.38,
      pan: -0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 600, high: 9500),
        ),
      ),
    ),
    LayerConfig(
      id: 'energy-ambiance-right',
      gain: 0.36,
      pan: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 900, high: 12000),
        ),
      ),
    ),
  ],
);

const List<GenerationConfig> energyProfiles = <GenerationConfig>[
  relaxEnergyProfile,
  sleepEnergyProfile,
  activationEnergyProfile,
  highEnergyProfile,
  ambianceEnergyProfile,
];
