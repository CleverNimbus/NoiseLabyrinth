import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart' hide SourceNode, ProcessorNode;
import 'package:noiselabyrinth_gui/state/editor/editor_node.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/event_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/layer_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/metadata_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/mix_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/modulation_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/processor_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/render_inspector.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspectors/source_inspector.dart';

abstract final class ConfigEditorFactory {
  static Widget buildInspector(BuildContext context, WidgetRef ref, EditorNode node, GenerationConfig config) {
    return switch (node) {
      MetadataNode() => MetadataInspector(metadata: config.metadata),
      RenderNode() => RenderInspector(render: config.render),
      MixNode() => MixInspector(mix: config.mix),
      LayerNode(:final layer) => LayerInspector(layer: layer),
      SourceNode(:final layer) => SourceInspector(layer: layer),
      ProcessorNode(:final layer, :final processor) => ProcessorInspector(layer: layer, processor: processor),
      ModulationNode(:final layer, :final modulation) => ModulationInspector(
        layer: layer,
        modulation: modulation,
        config: config,
      ),
      EventNode(:final layer, :final event) => EventInspector(layer: layer, event: event),
    };
  }
}
