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

    test('cleans up preview-disabled ids when entities are removed', () {
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

      notifier
        ..toggleProcessorPreviewEnabled(layerId, processorId)
        ..toggleModulationPreviewEnabled(layerId, modulationId)
        ..toggleEventPreviewEnabled(layerId, eventId);

      notifier
        ..removeProcessor(layerId, processorId)
        ..removeModulation(layerId, modulationId)
        ..removeEvent(layerId, eventId);

      expect(notifier.state.previewDisabledProcessorsByLayer[layerId], isNull);
      expect(notifier.state.previewDisabledModulationsByLayer[layerId], isNull);
      expect(notifier.state.previewDisabledEventsByLayer[layerId], isNull);
    });
  });

  group('buildPreviewConfigSnapshot', () {
    test('filters disabled processors and removes invalid modulation targets', () {
      final config = _buildConfig();
      final state = EditorState(
        config: config,
        previewDisabledProcessorsByLayer: {
          'layer_1': {'proc_1'},
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
        previewDisabledModulationsByLayer: {
          'layer_1': {'mod_1'},
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
        previewDisabledEventsByLayer: {
          'layer_1': {'event_1'},
        },
      );

      final snapshot = buildPreviewConfigSnapshot(state);

      expect(snapshot.layers.first.events, isEmpty);
      expect(config.layers.first.events, hasLength(1));
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
