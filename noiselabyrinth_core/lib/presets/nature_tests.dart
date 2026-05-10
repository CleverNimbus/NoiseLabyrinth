import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/dither_config.dart';
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

class NatureConfigTests {
  static final RenderConfig _render = RenderConfig(durationMinutes: 30);

  static MixConfig _mix() {
    return MixConfig(
      mix: 0.9,
      normalization: NormalizationConfig(enabled: true, targetDb: -1.2),
      dither: DitherConfig(enabled: true, type: DitherType.tpdf),
    );
  }

  static LayerConfig _noiseLayer({
    required String id,
    required NoiseColor color,
    required BandConfig band,
    required double gain,
    double pan = 0.0,
    List<ProcessorConfig> processors = const <ProcessorConfig>[],
    List<ModulationConfig> modulations = const <ModulationConfig>[],
  }) {
    return LayerConfig(
      id: id,
      gain: gain,
      pan: pan,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(color: color, band: band),
      ),
      processors: processors,
      modulations: modulations,
    );
  }

  static ProcessorConfig _lowpass(String id, int frequency, {double q = 0.9}) {
    return ProcessorConfig(
      id: id,
      type: ProcessorType.biquad,
      biquad: BiquadConfig(
        frequency: frequency,
        q: q,
      ),
    );
  }

  static ModulationConfig _panMotion({
    required String id,
    required String layerId,
    required double minPan,
    required double maxPan,
    double rateHz = 0.05,
    double smooth = 0.9,
  }) {
    return ModulationConfig(
      id: id,
      type: ModulationType.random,
      amount: 0,
      randomConfig: RandomConfig(
        rateHz: rateHz,
        smooth: smooth,
      ),
      targets: <ModulationTargetConfig>[
        ModulationTargetConfig(
          path: 'layers[$layerId].pan',
          amount: 0,
          mode: ModulationApplyMode.additive,
          minValue: minPan,
          maxValue: maxPan,
        ),
      ],
    );
  }

  static GenerationConfig _preset({
    required String name,
    required String description,
    required List<String> tags,
    required List<LayerConfig> layers,
  }) {
    return GenerationConfig(
      metadata: MetadataConfig(
        name: name,
        description: description,
        tags: tags,
        version: 1,
      ),
      render: _render,
      mix: _mix(),
      layers: layers,
    );
  }

  static final GenerationConfig wind_001 = _preset(
    name: 'T01. Wind',
    description: 'Soft filtered pink noise with a slow stereo drift.',
    tags: <String>['preset', 'nature', 'wind'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'wind_body',
        color: NoiseColor.pink,
        band: BandConfig(low: 120, high: 9000),
        gain: 0.55,
        processors: <ProcessorConfig>[
          _lowpass('wind_soften', 4200),
        ],
        modulations: <ModulationConfig>[
          _panMotion(
            id: 'wind_pan',
            layerId: 'wind_body',
            minPan: -0.35,
            maxPan: 0.35,
          ),
        ],
      ),
    ],
  );

  static final GenerationConfig rain_002 = _preset(
    name: 'T02. Rain',
    description: 'A bright rain layer over a soft low bed.',
    tags: <String>['preset', 'nature', 'rain'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'rain_drops',
        color: NoiseColor.bandlimited,
        band: BandConfig(low: 900, high: 12000),
        gain: 0.45,
        processors: <ProcessorConfig>[
          _lowpass('rain_tone', 7000),
        ],
      ),
      _noiseLayer(
        id: 'rain_body',
        color: NoiseColor.brown,
        band: BandConfig(low: 60, high: 1200),
        gain: 0.18,
      ),
    ],
  );

  static final GenerationConfig sea_003 = _preset(
    name: 'T03. Sea',
    description: 'Low surf with a lighter foam layer on top.',
    tags: <String>['preset', 'nature', 'sea', 'ocean'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'sea_surf',
        color: NoiseColor.brown,
        band: BandConfig(low: 30, high: 1800),
        gain: 0.5,
        processors: <ProcessorConfig>[
          _lowpass('sea_round', 1500),
        ],
      ),
      _noiseLayer(
        id: 'sea_foam',
        color: NoiseColor.pink,
        band: BandConfig(low: 600, high: 9000),
        gain: 0.22,
        modulations: <ModulationConfig>[
          _panMotion(
            id: 'sea_foam_pan',
            layerId: 'sea_foam',
            minPan: -0.2,
            maxPan: 0.2,
            rateHz: 0.04,
          ),
        ],
      ),
    ],
  );

  static final GenerationConfig storm_004 = _preset(
    name: 'T04. Storm',
    description: 'Deep rumble under a broader, more aggressive wind layer.',
    tags: <String>['preset', 'nature', 'storm'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'storm_rumble',
        color: NoiseColor.brown,
        band: BandConfig(low: 20, high: 260),
        gain: 0.42,
      ),
      _noiseLayer(
        id: 'storm_wind',
        color: NoiseColor.bandlimited,
        band: BandConfig(low: 250, high: 10000),
        gain: 0.42,
        processors: <ProcessorConfig>[
          _lowpass('storm_shape', 5200),
        ],
        modulations: <ModulationConfig>[
          _panMotion(
            id: 'storm_pan',
            layerId: 'storm_wind',
            minPan: -0.45,
            maxPan: 0.45,
            rateHz: 0.06,
            smooth: 0.85,
          ),
        ],
      ),
    ],
  );

  static final GenerationConfig seaStorm_005 = _preset(
    name: 'T05. Sea storm',
    description: 'Sea surf blended with storm wind and low thunder-like rumble.',
    tags: <String>['preset', 'nature', 'sea', 'storm', 'ocean'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'sea_storm_surf',
        color: NoiseColor.brown,
        band: BandConfig(low: 30, high: 2000),
        gain: 0.42,
        processors: <ProcessorConfig>[
          _lowpass('sea_storm_round', 1700),
        ],
      ),
      _noiseLayer(
        id: 'sea_storm_rumble',
        color: NoiseColor.brown,
        band: BandConfig(low: 20, high: 220),
        gain: 0.28,
      ),
      _noiseLayer(
        id: 'sea_storm_wind',
        color: NoiseColor.bandlimited,
        band: BandConfig(low: 500, high: 11000),
        gain: 0.32,
        modulations: <ModulationConfig>[
          _panMotion(
            id: 'sea_storm_pan',
            layerId: 'sea_storm_wind',
            minPan: -0.35,
            maxPan: 0.35,
            rateHz: 0.05,
            smooth: 0.88,
          ),
        ],
      ),
    ],
  );

  static final GenerationConfig forest_006 = _preset(
    name: 'T06. Forest',
    description: 'Gentle breeze with light leafy texture.',
    tags: <String>['preset', 'nature', 'forest'],
    layers: <LayerConfig>[
      _noiseLayer(
        id: 'forest_air',
        color: NoiseColor.pink,
        band: BandConfig(low: 150, high: 7000),
        gain: 0.35,
        processors: <ProcessorConfig>[
          _lowpass('forest_soften', 3800),
        ],
      ),
      _noiseLayer(
        id: 'forest_leaves',
        color: NoiseColor.bandlimited,
        band: BandConfig(low: 1400, high: 8500),
        gain: 0.2,
        pan: 0.15,
        modulations: <ModulationConfig>[
          _panMotion(
            id: 'forest_pan',
            layerId: 'forest_leaves',
            minPan: -0.25,
            maxPan: 0.25,
            rateHz: 0.03,
          ),
        ],
      ),
    ],
  );
}
