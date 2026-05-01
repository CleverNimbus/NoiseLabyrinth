import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/event_engine.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/runtime_graph_builder.dart';
import 'package:noiselabyrinth_core/engine/wav_encoder.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

/// Container for audio buffers associated with a layer.
///
/// Holds main mono buffer and separate left/right channels for processing,
/// with an optional scratch buffer for intermediate computations.
class LayerBuffers {
  /// Creates a new LayerBuffers instance with the provided buffers.
  const LayerBuffers({
    required this.main,
    required this.left,
    required this.right,
    required this.scratch,
  });

  /// Main mono audio buffer.
  final Float32List main;

  /// Left channel audio buffer.
  final Float32List left;

  /// Right channel audio buffer.
  final Float32List right;

  /// Optional scratch buffer for intermediate computations.
  final Float32List? scratch;
}

/// Container for stereo audio samples.
///
/// Holds separate left and right channel sample data.
class StereoSamples {
  /// Creates a new StereoSamples instance with the provided channels.
  const StereoSamples({required this.left, required this.right});

  /// Left channel audio samples.
  final Float32List left;

  /// Right channel audio samples.
  final Float32List right;
}

/// The main audio processing engine that handles DSP graph execution.
///
/// Manages audio layer processing, modulation, events scheduling, and buffer
/// allocation. Processes audio in fixed-size blocks and provides various
/// rendering methods for different output formats.
class AudioEngine {
  /// Creates a new AudioEngine with the specified configuration.
  AudioEngine({
    required this.graph,
    required this.sampleRate,
    required this.blockSize,
    this.enableScratchBuffers = false,
  }) : _masterBuffer = Float32List(blockSize),
       _masterLeftBuffer = Float32List(blockSize),
       _masterRightBuffer = Float32List(blockSize),
       _modulationEngine = ModulationEngine(
         bindings: graph.layers.expand((layer) => layer.modulationBindings).toList(growable: false),
       ),
       _eventScheduler = EventScheduler(
         events: graph.layers.expand((layer) => layer.eventBindings).toList(growable: false),
         sampleRate: sampleRate,
         blockSize: blockSize,
       ) {
    _allocateBuffers();
    _prepareNodes();
  }

  /// The runtime audio graph containing all layers and connections.
  final RuntimeGraph graph;

  /// Sample rate in Hz.
  final int sampleRate;

  /// Audio block size for processing.
  final int blockSize;

  /// Whether to allocate scratch buffers for layer processing.
  final bool enableScratchBuffers;

  final Map<String, LayerBuffers> _layerBuffers = <String, LayerBuffers>{};
  final Map<String, SmoothedParameter> _layerGainSmoothing = <String, SmoothedParameter>{};
  final Map<String, SmoothedParameter> _layerPanSmoothing = <String, SmoothedParameter>{};
  final Float32List _masterBuffer;
  final Float32List _masterLeftBuffer;
  final Float32List _masterRightBuffer;
  final ModulationEngine _modulationEngine;
  final EventScheduler _eventScheduler;
  int _ditherState = 0x6d2b79f5;

  /// Total number of audio blocks processed so far.
  int processedBlocks = 0;

  /// Gets the audio buffers for a specific layer.
  ///
  /// Throws [StateError] if no buffers are allocated for the given layer ID.
  LayerBuffers layerBuffers(String layerId) {
    final buffers = _layerBuffers[layerId];
    if (buffers == null) {
      throw StateError('No buffers allocated for layer $layerId.');
    }
    return buffers;
  }

  /// Gets the current master output buffer (mono mix).
  Float32List get masterBuffer => _masterBuffer;

  /// Gets the current master left channel buffer.
  Float32List get masterLeftBuffer => _masterLeftBuffer;

  /// Gets the current master right channel buffer.
  Float32List get masterRightBuffer => _masterRightBuffer;

  /// Processes the specified number of audio blocks without rendering.
  ///
  /// Updates internal state but does not capture output.
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

  /// Renders mono audio samples.
  ///
  /// Returns a [Float32List] containing the rendered mono samples.
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

    _applyNormalizationMono(output);

    return output;
  }

  /// Renders stereo audio samples.
  ///
  /// Returns a [StereoSamples] containing the rendered left and right channels.
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

    _applyNormalizationStereo(left, right);

    return StereoSamples(left: left, right: right);
  }

  /// Renders audio to WAV format bytes.
  ///
  /// Returns a [Uint8List] containing PCM16 stereo WAV data.
  /// Throws [ArgumentError] if [durationSeconds] is not positive.
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

  /// Allocates audio buffers for all layers and initializes gain/pan smoothing.
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

  /// Prepares all audio nodes by calling their prepare methods.
  void _prepareNodes() {
    for (final layer in graph.layers) {
      layer.source.prepare(sampleRate, blockSize);
      for (final processor in layer.processors) {
        processor.prepare(sampleRate, blockSize);
      }
    }

    // Seed the dither PRNG deterministically from render topology.
    _ditherState = _seedDitherState();
  }

  /// Processes modulation for the current block.
  void _processModulationStub() {
    _modulationEngine.processBlock(blockSize);
  }

  /// Processes a single audio block through the entire DSP graph.
  void _processSingleBlock() {
    _eventScheduler.processBlock();
    _processModulationStub();
    _updateGraphParameters();
    _masterBuffer.fillRange(0, _masterBuffer.length, 0);
    _masterLeftBuffer.fillRange(0, _masterLeftBuffer.length, 0);
    _masterRightBuffer.fillRange(0, _masterRightBuffer.length, 0);

    for (final layer in graph.layers) {
      final buffers = layerBuffers(layer.id);
      final main = buffers.main;
      final left = buffers.left;
      final right = buffers.right;
      final scratch = buffers.scratch;

      main.fillRange(0, main.length, 0);
      left.fillRange(0, left.length, 0);
      right.fillRange(0, right.length, 0);
      scratch?.fillRange(0, scratch.length, 0);

      _updateLayerParameters(layer);

      layer.source.process(main, scratch: scratch);
      for (final processor in layer.processors) {
        processor.process(main, scratch: scratch);
      }

      final layerGainSmoothing = _layerGainSmoothing[layer.id]!
        ..target = layer.gain.finalValue
        ..update();
      final layerGain = layerGainSmoothing.current;

      final layerPanSmoothing = _layerPanSmoothing[layer.id]!
        ..target = layer.pan.finalValue.clamp(-1.0, 1.0)
        ..update();
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
    final dither = graph.config.mix.dither;
    final ditherEnabled = dither.enabled && dither.amount > 0.0;
    final ditherAmplitude = ditherEnabled ? _ditherAmplitude(dither.bitDepth, dither.amount) : 0.0;

    for (var i = 0; i < _masterLeftBuffer.length; i++) {
      _masterLeftBuffer[i] *= mix;
      _masterRightBuffer[i] *= mix;

      if (ditherEnabled) {
        _masterLeftBuffer[i] += _nextTpdfDither() * ditherAmplitude;
        _masterRightBuffer[i] += _nextTpdfDither() * ditherAmplitude;
      }

      // Keep a mono compatibility bus as L/R fold-down.
      _masterBuffer[i] = (_masterLeftBuffer[i] + _masterRightBuffer[i]) * 0.5;
    }
  }

  int _seedDitherState() {
    var state = 0x6d2b79f5;
    state ^= sampleRate;
    state ^= blockSize << 7;
    state ^= graph.layers.length << 13;
    state ^= graph.config.mix.dither.bitDepth << 19;
    if (state == 0) {
      return 1;
    }
    return state;
  }

  double _ditherAmplitude(int bitDepth, double amount) {
    final safeBitDepth = bitDepth < 1 ? 1 : bitDepth;
    final levels = (1 << (safeBitDepth - 1)) - 1;
    final lsb = levels <= 0 ? 1.0 : 1.0 / levels;
    return lsb * amount;
  }

  double _nextTpdfDither() {
    // TPDF in [-1, 1] from two independent uniforms in [0, 1).
    return _nextUnitDouble() - _nextUnitDouble();
  }

  double _nextUnitDouble() {
    var x = _ditherState;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    _ditherState = x & 0xffffffff;
    return (_ditherState & 0xffffffff) / 4294967296.0;
  }

  void _applyNormalizationMono(Float32List buffer) {
    final normalization = graph.config.mix.normalization;
    if (!normalization.enabled) {
      return;
    }

    final peak = _peakAbs(buffer);
    if (peak <= 0.0) {
      return;
    }

    final targetLinear = _dbToLinear(normalization.targetDb);
    final gain = targetLinear / peak;
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] *= gain;
    }
  }

  void _applyNormalizationStereo(Float32List left, Float32List right) {
    final normalization = graph.config.mix.normalization;
    if (!normalization.enabled) {
      return;
    }

    final leftPeak = _peakAbs(left);
    final rightPeak = _peakAbs(right);
    final peak = leftPeak > rightPeak ? leftPeak : rightPeak;
    if (peak <= 0.0) {
      return;
    }

    final targetLinear = _dbToLinear(normalization.targetDb);
    final gain = targetLinear / peak;
    for (var i = 0; i < left.length; i++) {
      left[i] *= gain;
      right[i] *= gain;
    }
  }

  double _peakAbs(Float32List buffer) {
    var peak = 0.0;
    for (var i = 0; i < buffer.length; i++) {
      final value = buffer[i].abs();
      if (value > peak) {
        peak = value;
      }
    }
    return peak;
  }

  double _dbToLinear(double db) {
    return math.pow(10.0, db / 20.0).toDouble();
  }

  /// Updates all graph-level parameters.
  void _updateGraphParameters() {
    graph.masterMix.update();
  }

  /// Updates all parameters for a specific layer and its processors.
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
