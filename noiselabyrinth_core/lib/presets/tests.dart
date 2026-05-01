import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

const GenerationConfig brownNoiseDeepField = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Brown Noise - Deep Field (Pro)',
    description:
        'Layered brown noise with subtle spectral shaping and slow drift modulation for long-term listening comfort.',
    tags: <String>['brown', 'sleep', 'focus', 'low-frequency'],
    version: 1,
  ),
  render: RenderConfig(),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'brown_core',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'dc_cut',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.highpass,
            frequency: 18,
            q: 0.707,
          ),
        ),
        ProcessorConfig(
          id: 'low_focus',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 1800,
            q: 0.9,
          ),
        ),
      ],
      modulations: [
        ModulationConfig(
          id: 'slow_drift',
          type: ModulationType.drift,
          amount: 0.2,
          driftConfig: DriftConfig(
            speed: 0.003,
            range: 0.15,
          ),
          targets: [
            ModulationTargetConfig(
              path: 'layers[brown_core].processors[low_focus].biquad.frequency',
              mode: ModulationApplyMode.multiplicative,
              minValue: 1200,
              maxValue: 2500,
            ),
          ],
        ),
      ],
    ),
    LayerConfig(
      id: 'brown_air',
      gain: 0.15,
      pan: 0.2,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(low: 200, high: 8000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'soft_shape',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.bandpass,
            frequency: 2500,
            q: 0.7,
          ),
        ),
        ProcessorConfig(
          id: 'soft_sat',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(
            drive: 0.2,
          ),
        ),
      ],
      modulations: [
        ModulationConfig(
          id: 'random_variation',
          type: ModulationType.random,
          amount: 0.1,
          randomConfig: RandomConfig(
            rateHz: 0.02,
            smooth: 0.95,
          ),
          targets: [
            ModulationTargetConfig(
              path: 'layers[brown_air].gain',
              mode: ModulationApplyMode.multiplicative,
              minValue: 0.1,
              maxValue: 0.2,
            ),
          ],
        ),
      ],
    ),
  ],
);

const GenerationConfig whiteFullband = GenerationConfig(
  metadata: MetadataConfig(
    name: 'white_fullband',
    description: 'flat hiss',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'white_fullband',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(),
        ),
      ),
    ),
  ],
);

const GenerationConfig brownLow = GenerationConfig(
  metadata: MetadataConfig(
    name: 'brown_low',
    description: 'heavy rumble, almost sub-like',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'brown_low',
      gain: 0.7,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(high: 500),
        ),
      ),
    ),
  ],
);

const GenerationConfig bandpassMid = GenerationConfig(
  metadata: MetadataConfig(
    name: 'bandpass_mid',
    description: 'radio-like narrow noise',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'bandpass_mid',
      gain: 0.6,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 500, high: 2000),
        ),
      ),
    ),
  ],
);

const GenerationConfig sineReference = GenerationConfig(
  metadata: MetadataConfig(
    name: 'sine_reference',
    description: 'clean 440Hz tone (detect clipping instantly)',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'sine_reference',
      gain: 0.4,
      source: SourceConfig(
        type: SourceType.sine,
        sineConfig: SineConfig(frequencyHz: 440),
      ),
    ),
  ],
);

const GenerationConfig biquadLowpassTest = GenerationConfig(
  metadata: MetadataConfig(
    name: 'biquad_lowpass_test',
    description: 'muffled white noise (cut highs clearly)',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'biquad_lowpass_test',
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
          id: 'lp1',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 800,
            q: 0.7,
          ),
        ),
      ],
    ),
  ],
);

const GenerationConfig delayImpulseTest = GenerationConfig(
  metadata: MetadataConfig(
    name: 'delay_impulse_test',
    description: 'distinct echoes → spacing must match 250ms',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'delay_impulse_test',
      gain: 0.6,
      source: SourceConfig(
        type: SourceType.impulse,
        impulseConfig: ImpulseConfig(density: 0.1, randomness: 0),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'delay1',
          type: ProcessorType.delay,
          delay: DelayConfig(
            delayTimeMs: 250,
            feedback: 0.4,
            mix: 0.5,
          ),
        ),
      ],
    ),
  ],
);

const GenerationConfig lfoGainTest = GenerationConfig(
  metadata: MetadataConfig(
    name: 'lfo_gain_test',
    description: 'slow “breathing” volume',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'lfo_gain_test',
      gain: 0.5,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(high: 8000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'gain1',
          type: ProcessorType.gain,
          gain: GainConfig(),
        ),
      ],
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'lfo1',
          type: ModulationType.lfo,
          amount: 0.5,
          lfoConfig: LfoConfig(
            frequency: 0.25,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[lfo_gain_test].processors[gain1].gain.gain',
              minValue: 0.2,
              maxValue: 1,
            ),
          ],
        ),
      ],
    ),
  ],
);

const GenerationConfig randomFilterTest = GenerationConfig(
  metadata: MetadataConfig(
    name: 'random_filter_test',
    description: 'wandering tonal noise (not stepping abruptly)',
    tags: <String>['test', 'diagnostic', 'engine'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 5,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.7,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'random_filter_test',
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
          id: 'bp1',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.bandpass,
            frequency: 1000,
            q: 3,
          ),
        ),
      ],
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'rnd1',
          type: ModulationType.random,
          amount: 1,
          randomConfig: RandomConfig(
            rateHz: 0.5,
            smooth: 0.7,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[random_filter_test].processors[bp1].biquad.frequency',
              minValue: 300,
              maxValue: 4000,
            ),
          ],
        ),
      ],
    ),
  ],
);

const GenerationConfig stormForestVivid = GenerationConfig(
  metadata: MetadataConfig(
    name: 'Storm Forest - Vivid',
    description: 'Dynamic forest environment with wind movement, distant thunder, and sporadic organic activity.',
    tags: <String>['nature', 'dynamic', 'storm', 'vivid'],
    version: 1,
  ),
  render: RenderConfig(
    durationMinutes: 20,
  ),
  mix: MixConfig(
    dither: DitherConfig(
      enabled: true,
      amount: 0.8,
    ),
  ),
  layers: <LayerConfig>[
    LayerConfig(
      id: 'wind_base',
      gain: 0.6,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.pink,
          band: BandConfig(low: 50, high: 4000),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'wind_lp',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            frequency: 1200,
            q: 0.8,
          ),
        ),
      ],
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'wind_lfo',
          type: ModulationType.lfo,
          amount: 0.5,
          lfoConfig: LfoConfig(
            frequency: 0.08,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[wind_base].processors[wind_lp].biquad.frequency',
              minValue: 600,
              maxValue: 2000,
            ),
          ],
        ),
      ],
    ),
    LayerConfig(
      id: 'gusts',
      gain: 0.7,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.white,
          band: BandConfig(low: 200, high: 8000),
        ),
      ),
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'gust_burst',
          type: ModulationType.burst,
          amount: 1,
          burstConfig: BurstConfig(
            durationMs: 1200,
            randomness: 0.6,
            clusterMax: 3,
            clusterSpreadMs: 200,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[gusts].gain',
              minValue: 0,
              maxValue: 1.2,
            ),
          ],
        ),
      ],
      events: <EventConfig>[
        EventConfig(
          id: 'gust_trigger',
          trigger: TriggerConfig(
            type: TriggerType.poisson,
            rate: 0.03,
          ),
          actions: <ActionConfig>[
            ActionConfig(
              modulatorId: 'gust_burst',
            ),
          ],
        ),
      ],
    ),
    LayerConfig(
      id: 'distant_thunder',
      gain: 0.8,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: NoiseColor.brown,
          band: BandConfig(high: 200),
        ),
      ),
      processors: <ProcessorConfig>[
        ProcessorConfig(
          id: 'thunder_sat',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(
            drive: 1.5,
          ),
        ),
      ],
      modulations: <ModulationConfig>[
        ModulationConfig(
          id: 'thunder_env',
          type: ModulationType.envelope,
          amount: 1,
          envelopeConfig: EnvelopeConfig(
            attackMs: 500,
            decayMs: 2000,
            releaseMs: 3000,
          ),
          targets: <ModulationTargetConfig>[
            ModulationTargetConfig(
              path: 'layers[distant_thunder].gain',
              minValue: 0,
              maxValue: 1,
            ),
          ],
        ),
      ],
      events: <EventConfig>[
        EventConfig(
          id: 'thunder_event',
          trigger: TriggerConfig(
            type: TriggerType.poisson,
            rate: 0.01,
          ),
          actions: <ActionConfig>[
            ActionConfig(
              modulatorId: 'thunder_env',
            ),
          ],
        ),
      ],
    ),
  ],
);
