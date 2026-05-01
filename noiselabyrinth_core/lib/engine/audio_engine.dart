import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/event_engine.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/runtime_graph_builder.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class LayerBuffers {
  final Float32List main;
  final Float32List left;
  final Float32List right;
  final Float32List? scratch;

  const LayerBuffers({
    required this.main,
    required this.left,
    required this.right,
    required this.scratch,
  });
}

class StereoSamples {
  final Float32List left;
  final Float32List right;

  const StereoSamples({required this.left, required this.right});
}

class AudioEngine {
  final RuntimeGraph graph;
  final int sampleRate;
  final int blockSize;
  final bool enableScratchBuffers;

  final Map<String, LayerBuffers> _layerBuffers = <String, LayerBuffers>{};
  final Map<String, SmoothedParameter> _layerGainSmoothing =
      <String, SmoothedParameter>{};
  final Map<String, SmoothedParameter> _layerPanSmoothing =
      <String, SmoothedParameter>{};
  final Float32List _masterBuffer;
  final Float32List _masterLeftBuffer;
  final Float32List _masterRightBuffer;
  final ModulationEngine _modulationEngine;
  final EventScheduler _eventScheduler;

  int processedBlocks = 0;

  AudioEngine({
    required this.graph,
    required this.sampleRate,
    required this.blockSize,
    this.enableScratchBuffers = false,
  }) : _masterBuffer = Float32List(blockSize),
       _masterLeftBuffer = Float32List(blockSize),
       _masterRightBuffer = Float32List(blockSize),
       _modulationEngine = ModulationEngine(
         bindings: graph.layers
             .expand((layer) => layer.modulationBindings)
             .toList(growable: false),
       ),
       _eventScheduler = EventScheduler(
         events: graph.layers
             .expand((layer) => layer.eventBindings)
             .toList(growable: false),
         sampleRate: sampleRate,
         blockSize: blockSize,
       ) {
    _allocateBuffers();
    _prepareNodes();
  }

  LayerBuffers layerBuffers(String layerId) {
    final buffers = _layerBuffers[layerId];
    if (buffers == null) {
      throw StateError('No buffers allocated for layer $layerId.');
    }
    return buffers;
  }

  Float32List get masterBuffer => _masterBuffer;
  Float32List get masterLeftBuffer => _masterLeftBuffer;
  Float32List get masterRightBuffer => _masterRightBuffer;

  void processBlocks(int totalBlocks) {
    if (totalBlocks <= 0) {
      return;
    }

    var blockIndex = 0;
    while (blockIndex < totalBlocks) {
      _processSingleBlock();
      processedBlocks++;
      blockIndex++;
    }
  }

  Float32List renderSamples({required int totalSamples}) {
    if (totalSamples <= 0) {
      return Float32List(0);
    }

    final totalBlocks = (totalSamples / blockSize).ceil();
    final output = Float32List(totalSamples);

    var writeIndex = 0;
    for (var block = 0; block < totalBlocks; block++) {
      _processSingleBlock();

      final remaining = totalSamples - writeIndex;
      final copyCount = math.min(blockSize, remaining);
      output.setRange(writeIndex, writeIndex + copyCount, _masterBuffer);
      writeIndex += copyCount;
      processedBlocks++;
    }

    return output;
  }

  StereoSamples renderStereoSamples({required int totalSamples}) {
    if (totalSamples <= 0) {
      return StereoSamples(left: Float32List(0), right: Float32List(0));
    }

    final totalBlocks = (totalSamples / blockSize).ceil();
    final left = Float32List(totalSamples);
    final right = Float32List(totalSamples);

    var writeIndex = 0;
    for (var block = 0; block < totalBlocks; block++) {
      _processSingleBlock();

      final remaining = totalSamples - writeIndex;
      final copyCount = math.min(blockSize, remaining);
      left.setRange(writeIndex, writeIndex + copyCount, _masterLeftBuffer);
      right.setRange(writeIndex, writeIndex + copyCount, _masterRightBuffer);
      writeIndex += copyCount;
      processedBlocks++;
    }

    return StereoSamples(left: left, right: right);
  }

  Uint8List renderWavBytes({required int durationSeconds}) {
    if (durationSeconds <= 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'durationSeconds must be > 0.',
      );
    }

    final totalSamples = sampleRate * durationSeconds;
    final stereo = renderStereoSamples(totalSamples: totalSamples);
    return WavEncoder.encodePcm16Stereo(
      left: stereo.left,
      right: stereo.right,
      sampleRate: sampleRate,
    );
  }

  void _allocateBuffers() {
    for (final layer in graph.layers) {
      _layerBuffers[layer.id] = LayerBuffers(
        main: Float32List(blockSize),
        left: Float32List(blockSize),
        right: Float32List(blockSize),
        scratch: enableScratchBuffers ? Float32List(blockSize) : null,
      );
      _layerGainSmoothing[layer.id] = SmoothedParameter(
        layer.gain.baseValue,
        0.2,
      );
      _layerPanSmoothing[layer.id] = SmoothedParameter(
        layer.pan.baseValue,
        0.2,
      );
    }
  }

  void _prepareNodes() {
    for (final layer in graph.layers) {
      layer.source.prepare(sampleRate, blockSize);
      for (final processor in layer.processors) {
        processor.prepare(sampleRate, blockSize);
      }
    }
  }

  void _processModulationStub() {
    _modulationEngine.processBlock(blockSize);
  }

  void _processSingleBlock() {
    _eventScheduler.processBlock();
    _processModulationStub();
    _updateGraphParameters();
    _masterBuffer.fillRange(0, _masterBuffer.length, 0.0);
    _masterLeftBuffer.fillRange(0, _masterLeftBuffer.length, 0.0);
    _masterRightBuffer.fillRange(0, _masterRightBuffer.length, 0.0);

    for (final layer in graph.layers) {
      final buffers = layerBuffers(layer.id);
      final main = buffers.main;
      final left = buffers.left;
      final right = buffers.right;
      final scratch = buffers.scratch;

      main.fillRange(0, main.length, 0.0);
      left.fillRange(0, left.length, 0.0);
      right.fillRange(0, right.length, 0.0);
      scratch?.fillRange(0, scratch.length, 0.0);

      _updateLayerParameters(layer);

      layer.source.process(main, scratch: scratch);
      for (final processor in layer.processors) {
        processor.process(main, scratch: scratch);
      }

      final layerGainSmoothing = _layerGainSmoothing[layer.id]!;
      layerGainSmoothing.target = layer.gain.finalValue;
      layerGainSmoothing.update();
      final layerGain = layerGainSmoothing.current;

      final layerPanSmoothing = _layerPanSmoothing[layer.id]!;
      layerPanSmoothing.target = layer.pan.finalValue.clamp(-1.0, 1.0);
      layerPanSmoothing.update();
      final pan = layerPanSmoothing.current.clamp(-1.0, 1.0);
      // Linear pan with center-preserving mono fold-down compatibility.
      final leftGain = pan <= 0.0 ? 1.0 : 1.0 - pan;
      final rightGain = pan >= 0.0 ? 1.0 : 1.0 + pan;

      for (var i = 0; i < main.length; i++) {
        final scaled = main[i] * layerGain;
        final leftSample = scaled * leftGain;
        final rightSample = scaled * rightGain;

        left[i] = leftSample;
        right[i] = rightSample;

        _masterLeftBuffer[i] += leftSample;
        _masterRightBuffer[i] += rightSample;
      }
    }

    final mix = graph.masterMix.finalValue;
    for (var i = 0; i < _masterLeftBuffer.length; i++) {
      _masterLeftBuffer[i] *= mix;
      _masterRightBuffer[i] *= mix;
      // Keep a mono compatibility bus as L/R fold-down.
      _masterBuffer[i] = (_masterLeftBuffer[i] + _masterRightBuffer[i]) * 0.5;
    }
  }

  void _updateGraphParameters() {
    graph.masterMix.update();
  }

  void _updateLayerParameters(LayerRuntime layer) {
    layer.gain.update();
    layer.pan.update();

    for (final parameter in layer.source.parameters.values) {
      parameter.update();
    }

    for (final processor in layer.processors) {
      for (final parameter in processor.parameters.values) {
        parameter.update();
      }
    }
  }
}

class WavEncoder {
  static Uint8List encodePcm16Stereo({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
  }) {
    if (left.length != right.length) {
      throw ArgumentError('left and right channels must have equal length.');
    }

    final dataSize = left.length * 4;
    final buffer = ByteData(44 + dataSize);

    _writeAscii(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _writeAscii(buffer, 8, 'WAVE');
    _writeAscii(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, 2, Endian.little); // Stereo
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 4, Endian.little); // Byte rate
    buffer.setUint16(32, 4, Endian.little); // Block align
    buffer.setUint16(34, 16, Endian.little); // Bits per sample
    _writeAscii(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < left.length; i++) {
      final leftScaled = (left[i].clamp(-1.0, 1.0).toDouble() * 32767.0)
          .round();
      final rightScaled = (right[i].clamp(-1.0, 1.0).toDouble() * 32767.0)
          .round();
      buffer.setInt16(offset, leftScaled, Endian.little);
      buffer.setInt16(offset + 2, rightScaled, Endian.little);
      offset += 4;
    }

    return buffer.buffer.asUint8List();
  }

  static void _writeAscii(ByteData buffer, int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
