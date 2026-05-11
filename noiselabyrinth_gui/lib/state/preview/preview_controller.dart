import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';

const _previewMaxSeconds = 45;
const _segmentSeconds = 4;
const _minAheadSegments = 1;
const _maxAheadSegments = 4;
const _bufferRemainingFractionToRefill = 0.05;

final previewControllerProvider = StateNotifierProvider<PreviewController, PreviewState>((ref) {
  final controller = PreviewController();
  ref.listen<EditorState>(editorNotifierProvider, (_, next) {
    controller.onEditorStateChanged(next);
  });
  return controller;
});

class PreviewState {
  const PreviewState({required this.isPreparing, required this.isPlaying, this.boundRevision, this.error});

  const PreviewState.idle() : isPreparing = false, isPlaying = false, boundRevision = null, error = null;

  final bool isPreparing;
  final bool isPlaying;
  final int? boundRevision;
  final String? error;

  bool get isActive => isPreparing || isPlaying;

  PreviewState copyWith({
    bool? isPreparing,
    bool? isPlaying,
    int? boundRevision,
    bool clearBoundRevision = false,
    String? error,
    bool clearError = false,
  }) {
    return PreviewState(
      isPreparing: isPreparing ?? this.isPreparing,
      isPlaying: isPlaying ?? this.isPlaying,
      boundRevision: clearBoundRevision ? null : (boundRevision ?? this.boundRevision),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PreviewController extends StateNotifier<PreviewState> {
  PreviewController() : super(const PreviewState.idle());

  Player? _player;
  StreamSubscription<bool>? _completedSubscription;
  int _sessionId = 0;
  bool _producerDone = false;
  int _enqueuedSegments = 0;
  bool _opened = false;

  void onEditorStateChanged(EditorState next) {
    if (!state.isActive) {
      return;
    }
    if (next.config == null) {
      unawaited(stop());
      return;
    }
    final config = next.config!;
    if (state.boundRevision != null && next.configRevision != state.boundRevision) {
      unawaited(_restart(config, next.configRevision));
    }
  }

  Future<void> start(GenerationConfig config, int configRevision) async {
    if (state.isActive) {
      return;
    }
    final snapshot = GenerationConfig.fromJson(config.toJson());
    final session = ++_sessionId;
    _producerDone = false;
    _enqueuedSegments = 0;
    _opened = false;
    state = PreviewState(isPreparing: true, isPlaying: false, boundRevision: configRevision);

    _player ??= Player();
    await _completedSubscription?.cancel();
    _completedSubscription = _player!.stream.completed.listen((completed) {
      if (completed && _producerDone && session == _sessionId) {
        state = const PreviewState.idle();
      }
    });

    unawaited(_produceAndQueue(session, snapshot));
  }

  Future<void> stop() async {
    _sessionId++;
    _producerDone = true;
    await _player?.stop();
    state = const PreviewState.idle();
  }

  Future<void> _restart(GenerationConfig config, int configRevision) async {
    await stop();
    await start(config, configRevision);
  }

  @override
  void dispose() {
    _sessionId++;
    _producerDone = true;
    final completedSubscription = _completedSubscription;
    final player = _player;
    if (completedSubscription != null) {
      unawaited(completedSubscription.cancel());
    }
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  Future<void> _produceAndQueue(int session, GenerationConfig config) async {
    try {
      final sampleRate = config.render.sampleRate;
      final totalFromConfig = sampleRate * config.render.durationMinutes * 60;
      final previewMaxSamples = sampleRate * _previewMaxSeconds;
      final totalSamples = math.min(totalFromConfig, previewMaxSamples);
      if (totalSamples <= 0) {
        state = const PreviewState.idle();
        return;
      }

      // Pre-calculate normalization gain in a background isolate to avoid blocking the UI.
      // If normalization is disabled, this returns 1.0 immediately.
      final normalizationGain = await compute(_calculateNormalizationGain, config);

      final segmentSamplesTarget = sampleRate * _segmentSeconds;
      final segmentPcmBytes = BytesBuilder(copy: false);
      var segmentSamples = 0;
      var producedSamples = 0;

      await for (final chunk in Renderer.renderPcmChunks(config, normalizationGain: normalizationGain)) {
        if (session != _sessionId) {
          return;
        }

        final remainingTotal = totalSamples - producedSamples;
        if (remainingTotal <= 0) {
          break;
        }

        final chunkSamples = math.min(chunk.left.length, remainingTotal);
        var chunkOffset = 0;
        while (chunkOffset < chunkSamples) {
          final segmentRemaining = segmentSamplesTarget - segmentSamples;
          final toCopy = math.min(segmentRemaining, chunkSamples - chunkOffset);
          final interleaved = Int16List(toCopy * 2);

          for (var i = 0; i < toCopy; i++) {
            final left = _toPcm16(chunk.left[chunkOffset + i]);
            final right = _toPcm16(chunk.right[chunkOffset + i]);
            final base = i * 2;
            interleaved[base] = left;
            interleaved[base + 1] = right;
          }

          segmentPcmBytes.add(interleaved.buffer.asUint8List());
          segmentSamples += toCopy;
          chunkOffset += toCopy;

          if (segmentSamples >= segmentSamplesTarget) {
            await _waitUntilQueueNeedsMore(session);
            if (session != _sessionId) {
              return;
            }
            await _enqueueSegment(session, segmentPcmBytes.takeBytes(), sampleRate, segmentSamples);
            segmentSamples = 0;
          }
        }

        producedSamples += chunkSamples;
      }

      if (segmentSamples > 0 && session == _sessionId) {
        await _waitUntilQueueNeedsMore(session);
        if (session == _sessionId) {
          await _enqueueSegment(session, segmentPcmBytes.takeBytes(), config.render.sampleRate, segmentSamples);
        }
      }

      _producerDone = true;

      if (!_opened && session == _sessionId) {
        state = const PreviewState.idle();
      }
    } catch (e) {
      if (session == _sessionId) {
        state = PreviewState(isPreparing: false, isPlaying: false, boundRevision: null, error: 'Preview failed: $e');
      }
    }
  }

  Future<void> _waitUntilQueueNeedsMore(int session) async {
    while (session == _sessionId) {
      final player = _player;
      if (player == null) {
        return;
      }
      if (_hasRoomForAnotherSegment(player)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  bool _hasRoomForAnotherSegment(Player player) {
    final currentIndex = player.state.playlist.index;
    final queuedAhead = _enqueuedSegments - (currentIndex + 1);
    if (queuedAhead < _maxAheadSegments) {
      return true;
    }

    final remainingFraction = _currentSegmentRemainingFraction(player);
    final bufferedSegments = queuedAhead + remainingFraction;
    return bufferedSegments <= _maxAheadSegments + _bufferRemainingFractionToRefill;
  }

  double _currentSegmentRemainingFraction(Player player) {
    final currentIndex = player.state.playlist.index;
    if (currentIndex < 0) {
      return 0;
    }

    final duration = player.state.duration;
    if (duration <= Duration.zero) {
      return 1;
    }

    final position = player.state.position;
    final durationMicros = duration.inMicroseconds;
    final remainingMicros = math.max(0, durationMicros - position.inMicroseconds);
    return remainingMicros / durationMicros;
  }

  Future<void> _enqueueSegment(int session, Uint8List pcmBytes, int sampleRate, int samplesPerChannel) async {
    if (session != _sessionId) {
      return;
    }
    final player = _player;
    if (player == null) {
      return;
    }

    final wavBytes = _encodeWavPcm16(
      pcm16InterleavedStereo: pcmBytes,
      sampleRate: sampleRate,
      samplesPerChannel: samplesPerChannel,
    );
    final media = await Media.memory(wavBytes, type: 'audio/wav');

    if (!_opened) {
      await player.open(media, play: true);
      _opened = true;
      state = state.copyWith(isPreparing: false, isPlaying: true, clearError: true);
    } else {
      await player.add(media);
      if (!state.isPlaying) {
        await player.play();
        state = state.copyWith(isPreparing: false, isPlaying: true);
      }
    }

    _enqueuedSegments += 1;

    final currentIndex = player.state.playlist.index;
    final queuedAhead = _enqueuedSegments - (currentIndex + 1);
    if (queuedAhead <= _minAheadSegments && !_producerDone) {
      // Producer loop continues naturally; this branch exists to document low-buffer intent.
    }
  }

  static int _toPcm16(double sample) {
    final clamped = sample.clamp(-1.0, 1.0);
    return (clamped * 32767.0).round();
  }

  static Uint8List _encodeWavPcm16({
    required Uint8List pcm16InterleavedStereo,
    required int sampleRate,
    required int samplesPerChannel,
  }) {
    const channels = 2;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcm16InterleavedStereo.lengthInBytes;
    final fileSize = 36 + dataSize;

    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.view(bytes.buffer);

    bytes.setAll(0, 'RIFF'.codeUnits);
    data.setUint32(4, fileSize, Endian.little);
    bytes.setAll(8, 'WAVE'.codeUnits);
    bytes.setAll(12, 'fmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    bytes.setAll(36, 'data'.codeUnits);
    data.setUint32(40, dataSize, Endian.little);
    bytes.setRange(44, 44 + dataSize, pcm16InterleavedStereo);

    // Intentionally retained as a parameter for sanity checks & future telemetry.
    if (samplesPerChannel <= 0) {
      return Uint8List(0);
    }

    return bytes;
  }
}

/// Top-level function to calculate normalization gain in a background isolate.
/// This avoids blocking the UI thread during normalization analysis.
double _calculateNormalizationGain(GenerationConfig config) {
  return Renderer.resolveNormalizationGain(config);
}
