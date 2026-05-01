import 'dart:typed_data';

import 'package:noiselabyrinth_core/models/parameter.dart';

abstract class AudioNode {
  String id;
  final Map<String, Parameter> parameters;

  int sampleRate = 0;
  int blockSize = 0;

  AudioNode({required this.id, required this.parameters});

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
  String inputNodeId;

  ProcessorNode({
    required super.id,
    required super.parameters,
    this.inputNodeId = '',
  });
}
