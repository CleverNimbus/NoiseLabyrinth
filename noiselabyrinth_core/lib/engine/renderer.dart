import 'dart:math';
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_engine.dart';
import 'package:noiselabyrinth_core/engine/runtime_graph_builder.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';

/// Render context assembled from a [GenerationConfig] before rendering starts.
class _RenderContext {
  _RenderContext({
    required this.engine,
    required this.totalSamples,
  });
  final AudioEngine engine;
  final int totalSamples;
}

/// Top-level PCM renderer.
///
/// Core renders stereo floating-point PCM only. Container and codec
/// responsibilities (WAV, MP3, etc.) belong to consumer packages.
class Renderer {
  const Renderer._();

  /// Renders the full output described by [config] as stereo float PCM.
  ///
  /// Normalization and DC blocking from [config] are applied before returning.
  static StereoSamples renderPcm(GenerationConfig config) {
    final ctx = _buildContext(config);
    final stereo = ctx.engine.renderStereoSamples(
      totalSamples: ctx.totalSamples,
    );
    _applyFinalDcBlocker(stereo, enabled: config.render.dcBlockerEnabled);
    return stereo;
  }

  /// Renders stereo float PCM as an async chunk stream.
  ///
  /// Each yielded [StereoSamples] covers one engine block worth of samples.
  /// Normalization and DC blocking are applied incrementally per chunk.
  static Stream<StereoSamples> renderPcmChunks(GenerationConfig config) async* {
    final normalizationGain = _resolveNormalizationGain(config);
    final ctx = _buildContext(config);
    final blockSize = ctx.engine.blockSize;
    var renderedSamples = 0;
    var previousLeftInput = 0.0;
    var previousLeftOutput = 0.0;
    var previousRightInput = 0.0;
    var previousRightOutput = 0.0;

    while (renderedSamples < ctx.totalSamples) {
      ctx.engine.processBlocks(1);

      final remaining = ctx.totalSamples - renderedSamples;
      final copyCount = (remaining < blockSize) ? remaining : blockSize;
      final left = Float32List(copyCount);
      final right = Float32List(copyCount);

      for (var i = 0; i < copyCount; i++) {
        var l = ctx.engine.masterLeftBuffer[i] * normalizationGain;
        var r = ctx.engine.masterRightBuffer[i] * normalizationGain;

        if (config.render.dcBlockerEnabled) {
          final nextLeft = l - previousLeftInput + 0.995 * previousLeftOutput;
          previousLeftInput = l;
          previousLeftOutput = nextLeft;
          l = nextLeft;

          final nextRight = r - previousRightInput + 0.995 * previousRightOutput;
          previousRightInput = r;
          previousRightOutput = nextRight;
          r = nextRight;
        }

        left[i] = l;
        right[i] = r;
      }

      renderedSamples += copyCount;
      yield StereoSamples(left: left, right: right);
    }
  }

  static _RenderContext _buildContext(GenerationConfig config) {
    final graph = RuntimeGraphBuilder(
      sampleRate: config.render.sampleRate,
    ).build(config);
    final engine = AudioEngine(
      graph: graph,
      sampleRate: config.render.sampleRate,
      blockSize: 512,
    );
    final totalSamples = config.render.sampleRate * config.render.durationMinutes * 60;
    return _RenderContext(engine: engine, totalSamples: totalSamples);
  }

  static double _resolveNormalizationGain(GenerationConfig config) {
    final normalization = config.mix.normalization;
    if (!normalization.enabled) {
      return 1;
    }

    final probe = _buildContext(config);
    final blockSize = probe.engine.blockSize;
    var renderedSamples = 0;
    var peak = 0.0;

    while (renderedSamples < probe.totalSamples) {
      probe.engine.processBlocks(1);

      final remaining = probe.totalSamples - renderedSamples;
      final copyCount = (remaining < blockSize) ? remaining : blockSize;
      for (var i = 0; i < copyCount; i++) {
        final leftAbs = probe.engine.masterLeftBuffer[i].abs();
        final rightAbs = probe.engine.masterRightBuffer[i].abs();
        final blockPeak = leftAbs > rightAbs ? leftAbs : rightAbs;
        if (blockPeak > peak) {
          peak = blockPeak;
        }
      }

      renderedSamples += copyCount;
    }

    if (peak <= 0.0) {
      return 1;
    }

    final targetLinear = _dbToLinear(normalization.targetDb);
    return targetLinear / peak;
  }

  static double _dbToLinear(double db) {
    return pow(10.0, db / 20.0).toDouble();
  }

  static void _applyFinalDcBlocker(StereoSamples stereo, {required bool enabled}) {
    if (!enabled) {
      return;
    }
    _applyDcBlockerInPlace(stereo.left);
    _applyDcBlockerInPlace(stereo.right);
  }

  static void _applyDcBlockerInPlace(Float32List buffer) {
    const feedback = 0.995;
    var previousInput = 0.0;
    var previousOutput = 0.0;
    for (var i = 0; i < buffer.length; i++) {
      final input = buffer[i];
      final output = input - previousInput + feedback * previousOutput;
      buffer[i] = output;
      previousInput = input;
      previousOutput = output;
    }
  }
}
