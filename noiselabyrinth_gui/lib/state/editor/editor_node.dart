import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

/// Represents a selected item in the editor structure tree.
sealed class EditorNode {
  const EditorNode();
}

final class MetadataNode extends EditorNode {
  const MetadataNode();
}

final class RenderNode extends EditorNode {
  const RenderNode();
}

final class MixNode extends EditorNode {
  const MixNode();
}

final class LayerNode extends EditorNode {
  const LayerNode(this.layer);
  final LayerConfig layer;
}

final class SourceNode extends EditorNode {
  const SourceNode(this.layer);
  final LayerConfig layer;
}

final class ProcessorNode extends EditorNode {
  const ProcessorNode(this.layer, this.processor);
  final LayerConfig layer;
  final ProcessorConfig processor;
}

final class ModulationNode extends EditorNode {
  const ModulationNode(this.layer, this.modulation);
  final LayerConfig layer;
  final ModulationConfig modulation;
}

final class EventNode extends EditorNode {
  const EventNode(this.layer, this.event);
  final LayerConfig layer;
  final EventConfig event;
}
