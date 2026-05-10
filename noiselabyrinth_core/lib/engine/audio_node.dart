import 'dart:typed_data';

import 'package:noiselabyrinth_core/models/parameter.dart';

/// Base classes for audio nodes in the runtime graph.
abstract class AudioNode {
  /// Constructs an [AudioNode] with the given [id] and [parameters].
  AudioNode({required this.id, required this.parameters});

  /// Unique identifier for this node, used for graph construction and parameter modulation.
  String id;

  /// Map of parameter name to [Parameter] object, defining the modulateable parameters of this node.
  final Map<String, Parameter> parameters;

  /// Sample rate and block size are set by the engine before processing begins, and can be used by nodes to prepare internal state.
  int sampleRate = 0;

  /// Block size is the number of samples processed in each block. Nodes can use this to optimize processing, e.g. by pre-allocating buffers.
  int blockSize = 0;

  /// Retrieves the [Parameter] object for the given parameter name, or null if it doesn't exist.
  Parameter? parameter(String name) => parameters[name];

  void prepare(int sampleRate, int blockSize) {
    this.sampleRate = sampleRate;
    this.blockSize = blockSize;
  }

  void process(Float32List buffer, {Float32List? scratch}) {
    // Stub: concrete DSP is intentionally not implemented in this phase.
  }
}

abstract class SourceNode extends AudioNode {
  SourceNode({required super.id, required super.parameters});
}

abstract class ProcessorNode extends AudioNode {
  ProcessorNode({
    required super.id,
    required super.parameters,
    this.inputNodeId = '',
  });
  String inputNodeId;
}
