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

class BrownConfigTests {
  static const int highBand = 300;
  static const int lowBand = 30;
  static const double highBandModulationRange = 100;
  static const double generalSmoothingFactor = 0.7;

  static const int cleanBrownHighBand = 12000;
  static const double subtlePanRange = 0.15;
  static const double subtleHighBandModulationRange = 1500;
  static const double subtleSmoothingFactor = 0.9;

  static GenerationConfig brownNoiseProfile_001 = GenerationConfig(
    metadata: MetadataConfig(
      name: 'T01. Brown noise profile',
      description: 'Brown noise emphasizing low-end energy and deep rumble.',
      tags: <String>['preset', 'noise', 'brown', 'spectrum'],
      version: 1,
    ),
    render: RenderConfig(durationMinutes: 30),
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
            band: BandConfig(high: highBand, low: lowBand),
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
        amount: 0,
        randomConfig: RandomConfig(
          rateHz: 0.2,
          smooth: BrownConfigTests.generalSmoothingFactor,
        ),
        targets: [
          ModulationTargetConfig(
            path: 'layers[brown_core].pan',
            amount: 0,
            mode: ModulationApplyMode.additive,
            minValue: -0.8,
            maxValue: 0.8,
          ),
        ],
      ),
      ModulationConfig(
        id: 'random_band_high_sweep',
        type: ModulationType.random,
        amount: 0,
        randomConfig: RandomConfig(
          rateHz: 0.4,
          smooth: BrownConfigTests.generalSmoothingFactor,
        ),
        targets: [
          ModulationTargetConfig(
            path: 'layers[brown_core].source.noise.band.high',
            amount: BrownConfigTests.highBandModulationRange,
            mode: ModulationApplyMode.additive,
            minValue: BrownConfigTests.highBand - BrownConfigTests.highBandModulationRange,
            maxValue: BrownConfigTests.highBand + BrownConfigTests.highBandModulationRange,
          ),
        ],
      ),
    ];
    return brown02;
  }

  static GenerationConfig getBrownNoiseProfile_003() {
    return GenerationConfig(
      metadata: MetadataConfig(
        name: 'T03. Brown noise animated',
        description: 'Clean brown noise baseline with subtle motion for a living ambience.',
        tags: <String>['preset', 'noise', 'brown', 'animated', 'spectrum'],
        version: 1,
      ),
      render: RenderConfig(durationMinutes: 30),
      mix: MixConfig(
        mix: 0.9,
        normalization: NormalizationConfig(enabled: true, targetDb: -1.2),
        dither: DitherConfig(enabled: true, type: DitherType.tpdf),
      ),
      layers: <LayerConfig>[
        LayerConfig(
          id: 'brown_core',
          gain: 0.8,
          source: SourceConfig(
            type: SourceType.noise,
            noiseConfig: NoiseConfig(
              color: NoiseColor.brown,
              band: BandConfig(high: cleanBrownHighBand),
            ),
          ),
          modulations: [
            ModulationConfig(
              id: 'subtle_pan_drift',
              type: ModulationType.random,
              amount: 0,
              randomConfig: RandomConfig(
                rateHz: 0.05,
                smooth: subtleSmoothingFactor,
              ),
              targets: [
                ModulationTargetConfig(
                  path: 'layers[brown_core].pan',
                  amount: 0,
                  mode: ModulationApplyMode.additive,
                  minValue: -subtlePanRange,
                  maxValue: subtlePanRange,
                ),
              ],
            ),
            ModulationConfig(
              id: 'subtle_band_air',
              type: ModulationType.random,
              amount: 0,
              randomConfig: RandomConfig(
                rateHz: 0.03,
                smooth: subtleSmoothingFactor,
              ),
              targets: [
                ModulationTargetConfig(
                  path: 'layers[brown_core].source.noise.band.high',
                  amount: subtleHighBandModulationRange,
                  mode: ModulationApplyMode.additive,
                  minValue: 9000,
                  maxValue: cleanBrownHighBand + subtleHighBandModulationRange,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
