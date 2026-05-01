import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

GenerationConfig _config({
  required String name,
  required String layerId,
  List<String> tags = const <String>[],
  String description = '',
  int durationMinutes = 1,
  int sampleRate = 44100,
  int bitRate = 192,
  RenderFormat format = RenderFormat.wav,
  double mix = 1,
  List<ModulationConfig> modulations = const <ModulationConfig>[],
}) {
  return GenerationConfig(
    metadata: MetadataConfig(
      name: name,
      description: description,
      tags: tags,
      version: 1,
    ),
    render: RenderConfig(
      durationMinutes: durationMinutes,
      sampleRate: sampleRate,
      bitRate: bitRate,
      format: format,
    ),
    mix: MixConfig(mix: mix),
    layers: <LayerConfig>[
      LayerConfig(
        id: layerId,
        gain: 0.5,
        source: const SourceConfig(
          type: SourceType.noise,
          noiseConfig: NoiseConfig(
            color: NoiseColor.white,
            band: BandConfig(high: 18000),
          ),
        ),
        modulations: modulations,
      ),
    ],
  );
}

class _InvalidOutputRule extends GenerationMergeRule {
  const _InvalidOutputRule();

  @override
  String get id => 'invalidOutput';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    draft
      ..metadata = const MetadataConfig(name: 'Invalid merged config')
      ..render = const RenderConfig(durationMinutes: 1)
      ..mix = const MixConfig();
  }
}

void main() {
  group('GenerationsMerger', () {
    test('requires at least two configs', () {
      const merger = GenerationsMerger();

      expect(
        () => merger.mergeAll(<GenerationConfig>[
          _config(name: 'Only', layerId: 'only-layer'),
        ]),
        throwsA(isA<GenerationMergeException>()),
      );
    });

    test('merges metadata, render, mix, and layers with default rules', () {
      const merger = GenerationsMerger();
      final first = _config(
        name: 'Rain bed',
        layerId: 'rain',
        tags: <String>['weather', 'bed'],
        description: 'Soft rain.',
        durationMinutes: 5,
        mix: 0.8,
      );
      final second = _config(
        name: 'Low drone',
        layerId: 'drone',
        tags: <String>['bed', 'drone'],
        description: 'Low harmonic support.',
        durationMinutes: 8,
        sampleRate: 48000,
        bitRate: 256,
        format: RenderFormat.mp3,
        mix: 0.4,
      );

      final merged = merger.merge(first, second);

      expect(merged.metadata.name, 'Rain bed + Low drone');
      expect(merged.metadata.description, 'Soft rain.\n\nLow harmonic support.');
      expect(merged.metadata.tags, <String>[
        'merged',
        'weather',
        'bed',
        'drone',
      ]);
      expect(merged.render.durationMinutes, 8);
      expect(merged.render.sampleRate, 48000);
      expect(merged.render.bitRate, 256);
      expect(merged.render.format, RenderFormat.mp3);
      expect(merged.mix.mix, closeTo(0.6, 0.0001));
      expect(merged.layers.map((layer) => layer.id), <String>['rain', 'drone']);
    });

    test('renames duplicate layer ids and rewrites modulation targets', () {
      const merger = GenerationsMerger();
      final first = _config(name: 'First', layerId: 'shared');
      final second = _config(
        name: 'Second',
        layerId: 'shared',
        modulations: const <ModulationConfig>[
          ModulationConfig(
            id: 'gain-lfo',
            type: ModulationType.lfo,
            lfoConfig: LfoConfig(),
            targets: <ModulationTargetConfig>[
              ModulationTargetConfig(path: 'layers[shared].gain'),
            ],
          ),
        ],
      );

      final merged = merger.merge(first, second);

      expect(
        merged.layers.map((layer) => layer.id),
        <String>['shared', 'shared-2'],
      );
      expect(
        merged.layers.last.modulations.single.targets.single.path,
        'layers[shared-2].gain',
      );
      expect(const GenerationConfigParser().validate(merged), isEmpty);
    });

    test('validates the merged config after rules are applied', () {
      const merger = GenerationsMerger(
        rules: <GenerationMergeRule>[
          _InvalidOutputRule(),
        ],
      );
      final first = _config(name: 'First', layerId: 'first');
      final second = _config(name: 'Second', layerId: 'second');

      expect(
        () => merger.merge(first, second),
        throwsA(isA<ConfigValidationException>()),
      );
    });
  });
}
