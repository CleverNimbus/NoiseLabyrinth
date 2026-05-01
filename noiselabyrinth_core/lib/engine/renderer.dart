import 'dart:typed_data';

import 'package:dart_lame/dart_lame.dart';
import 'package:noiselabyrinth_core/engine/audio_engine.dart';
import 'package:noiselabyrinth_core/engine/runtime_graph_builder.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

/// Render context assembled from a [GenerationConfig] before rendering starts.
class _RenderContext {
  final AudioEngine engine;
  final int totalSamples;
  final int bitRate;

  _RenderContext({
    required this.engine,
    required this.totalSamples,
    required this.bitRate,
  });
}

/// Top-level output renderer.
///
/// Use [render] to dispatch to WAV or MP3 according to [GenerationConfig.render.format].
/// Use [renderWav] or [renderMp3] to target a specific format directly.
class Renderer {
  const Renderer._();

  /// Renders the full output described by [config] and returns the encoded bytes.
  ///
  /// The format is determined by [RenderConfig.format]:
  /// - [RenderFormat.wav] → PCM-16 stereo WAV
  /// - [RenderFormat.mp3] → MP3 encoded via LAME (async)
  static Future<Uint8List> render(GenerationConfig config) {
    return switch (config.render.format) {
      RenderFormat.wav => Future.value(renderWav(config)),
      RenderFormat.mp3 => renderMp3(config),
    };
  }

  /// Renders to PCM-16 stereo WAV bytes.
  static Uint8List renderWav(GenerationConfig config) {
    final ctx = _buildContext(config);
    final stereo = ctx.engine.renderStereoSamples(
      totalSamples: ctx.totalSamples,
    );
    return WavEncoder.encodePcm16Stereo(
      left: stereo.left,
      right: stereo.right,
      sampleRate: config.render.sampleRate,
    );
  }

  /// Renders to MP3 bytes using the LAME encoder.
  ///
  /// Encoding is async because LAME runs in a separate isolate.
  static Future<Uint8List> renderMp3(GenerationConfig config) async {
    final ctx = _buildContext(config);
    final stereo = ctx.engine.renderStereoSamples(
      totalSamples: ctx.totalSamples,
    );

    final encoder = LameMp3Encoder(
      sampleRate: config.render.sampleRate,
      numChannels: 2,
      bitRate: ctx.bitRate,
    );

    // Chunk size aligned to sampleRate to keep LAME happy with frame boundaries.
    final chunkSize = config.render.sampleRate;
    final leftPcm = Int16List(chunkSize);
    final rightPcm = Int16List(chunkSize);
    final builder = BytesBuilder(copy: false);

    try {
      var offset = 0;
      while (offset < ctx.totalSamples) {
        final end = (offset + chunkSize).clamp(0, ctx.totalSamples);
        final length = end - offset;
        _fillInt16(stereo.left, offset, end, leftPcm);
        _fillInt16(stereo.right, offset, end, rightPcm);
        final leftChunk = Int16List.sublistView(leftPcm, 0, length);
        final rightChunk = Int16List.sublistView(rightPcm, 0, length);
        builder.add(
          await encoder.encode(
            leftChannel: leftChunk,
            rightChannel: rightChunk,
          ),
        );
        offset = end;
      }
      builder.add(await encoder.flush());
    } finally {
      await encoder.close();
    }

    return builder.takeBytes();
  }

  // ---------------------------------------------------------------------------

  static _RenderContext _buildContext(GenerationConfig config) {
    final graph = RuntimeGraphBuilder(
      sampleRate: config.render.sampleRate,
    ).build(config);
    final engine = AudioEngine(
      graph: graph,
      sampleRate: config.render.sampleRate,
      blockSize: 512,
    );
    final totalSamples =
        config.render.sampleRate * config.render.durationMinutes * 60;
    return _RenderContext(
      engine: engine,
      totalSamples: totalSamples,
      bitRate: config.render.bitRate,
    );
  }

  /// Fills [out] with PCM-16 values from [src] in [start, end).
  static void _fillInt16(Float32List src, int start, int end, Int16List out) {
    for (var i = start; i < end; i++) {
      final sample = src[i];
      final clamped = sample < -1.0
          ? -1.0
          : (sample > 1.0 ? 1.0 : sample.toDouble());
      out[i - start] = (clamped * 32767.0).round();
    }
  }
}
