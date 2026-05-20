import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_notifier.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';
import 'package:noiselabyrinth_gui/state/preview/preview_controller.dart';

void main() {
  group('EditorNotifier preview toggles', () {
    test('toggles processor/modulation/event preview state and bumps revision', () {
      final notifier = EditorNotifier()..newConfig();
      final layerId = notifier.state.config!.layers.first.id;

      notifier
        ..addProcessor(layerId)
        ..addModulation(layerId)
        ..addEvent(layerId);

      final layer = notifier.state.config!.layers.first;
      final processorId = layer.processors.first.id;
      final modulationId = layer.modulations.first.id;
      final eventId = layer.events.first.id;
      final initialRevision = notifier.state.configRevision;

      expect(notifier.state.isProcessorPreviewEnabled(layerId, processorId), isTrue);
      expect(notifier.state.isModulationPreviewEnabled(layerId, modulationId), isTrue);
      expect(notifier.state.isEventPreviewEnabled(layerId, eventId), isTrue);

      notifier.toggleProcessorPreviewEnabled(layerId, processorId);
      expect(notifier.state.isProcessorPreviewEnabled(layerId, processorId), isFalse);

      notifier.toggleModulationPreviewEnabled(layerId, modulationId);
      expect(notifier.state.isModulationPreviewEnabled(layerId, modulationId), isFalse);

      notifier.toggleEventPreviewEnabled(layerId, eventId);
      expect(notifier.state.isEventPreviewEnabled(layerId, eventId), isFalse);

      expect(notifier.state.configRevision, initialRevision + 3);
    });

    test('defaults new layers and items to selected preview state', () {
      final notifier = EditorNotifier()..newConfig();
      final layerId = notifier.state.config!.layers.first.id;

      expect(notifier.state.isLayerPreviewEnabled(layerId), isTrue);
      expect(notifier.state.isSourcePreviewEnabled(layerId), isTrue);

      notifier
        ..addProcessor(layerId)
        ..addModulation(layerId)
        ..addEvent(layerId);

      final layer = notifier.state.config!.layers.first;
      final processorId = layer.processors.first.id;
      final modulationId = layer.modulations.first.id;
      final eventId = layer.events.first.id;

      expect(notifier.state.isProcessorPreviewEnabled(layerId, processorId), isTrue);
      expect(notifier.state.isModulationPreviewEnabled(layerId, modulationId), isTrue);
      expect(notifier.state.isEventPreviewEnabled(layerId, eventId), isTrue);
    });

    test('resets the session selection when requested', () {
      final notifier = EditorNotifier()..newConfig();
      final layerId = notifier.state.config!.layers.first.id;

      notifier.toggleLayerPreviewEnabled(layerId);
      expect(notifier.state.isLayerPreviewEnabled(layerId), isFalse);

      notifier.resetLayerPreviewSelection();
      expect(notifier.state.isLayerPreviewEnabled(layerId), isTrue);
      expect(notifier.state.isSourcePreviewEnabled(layerId), isTrue);
    });
  });

  group('buildPreviewConfigSnapshot', () {
    test('filters disabled processors and removes invalid modulation targets', () {
      final config = _buildConfig();
      final state = EditorState(
        config: config,
        previewLayerSelections: {
          'layer_1': const LayerPreviewSelection(disabledProcessorIds: {'proc_1'}),
        },
      );

      final snapshot = buildPreviewConfigSnapshot(state);
      final layer = snapshot.layers.first;

      expect(layer.processors.map((p) => p.id), ['proc_2']);
      expect(layer.modulations.first.targets, isEmpty);
    });

    test('drops events with no valid actions after modulation filtering', () {
      final config = _buildConfig();
      final state = EditorState(
        config: config,
        previewLayerSelections: {
          'layer_1': const LayerPreviewSelection(disabledModulationIds: {'mod_1'}),
        },
      );

      final snapshot = buildPreviewConfigSnapshot(state);
      final layer = snapshot.layers.first;

      expect(layer.modulations.map((m) => m.id), isNot(contains('mod_1')));
      expect(layer.events, isEmpty);
    });

    test('keeps original config unchanged', () {
      final config = _buildConfig();
      final state = EditorState(
        config: config,
        previewLayerSelections: {
          'layer_1': const LayerPreviewSelection(disabledEventIds: {'event_1'}),
        },
      );

      final snapshot = buildPreviewConfigSnapshot(state);

      expect(snapshot.layers.first.events, isEmpty);
      expect(config.layers.first.events, hasLength(1));
    });

    test('drops a layer when its branch is not selected', () {
      final config = _buildConfig();
      final state = EditorState(
        config: config,
        previewLayerSelections: {'layer_1': const LayerPreviewSelection(layerEnabled: false)},
      );

      final snapshot = buildPreviewConfigSnapshot(state);

      expect(snapshot.layers, isEmpty);
    });
  });
}

GenerationConfig _buildConfig() {
  return GenerationConfig(
    metadata: MetadataConfig(name: 'Test'),
    render: RenderConfig(),
    mix: MixConfig(dither: DitherConfig(), normalization: NormalizationConfig()),
    layers: [
      LayerConfig(
        id: 'layer_1',
        source: SourceConfig(
          type: SourceType.noise,
          noiseConfig: NoiseConfig(color: NoiseColor.white, band: BandConfig()),
        ),
        processors: [
          ProcessorConfig(id: 'proc_1', type: ProcessorType.gain, gain: GainConfig(gain: 1.2)),
          ProcessorConfig(id: 'proc_2', type: ProcessorType.biquad, biquad: BiquadConfig()),
        ],
        modulations: [
          ModulationConfig(
            id: 'mod_1',
            type: ModulationType.lfo,
            lfoConfig: LfoConfig(),
            targets: [ModulationTargetConfig(path: ModulationTargetCatalog.gainProcessorGainPath('layer_1', 'proc_1'))],
          ),
        ],
        events: [
          EventConfig(
            id: 'event_1',
            trigger: TriggerConfig(),
            actions: [ActionConfig(modulatorId: 'mod_1')],
          ),
        ],
      ),
    ],
  );
}
