import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';

final previewSettingsProvider = StateNotifierProvider<PreviewSettingsNotifier, PreviewSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreviewSettingsNotifier(prefs);
});

class PreviewSettings {
  const PreviewSettings({
    required this.previewMaxSeconds,
    required this.segmentSeconds,
    required this.minAheadSegments,
    required this.maxAheadSegments,
    required this.bufferRemainingFractionToRefill,
  });

  final int previewMaxSeconds;
  final int segmentSeconds;
  final int minAheadSegments;
  final int maxAheadSegments;
  final double bufferRemainingFractionToRefill;

  PreviewSettings copyWith({
    int? previewMaxSeconds,
    int? segmentSeconds,
    int? minAheadSegments,
    int? maxAheadSegments,
    double? bufferRemainingFractionToRefill,
  }) {
    return PreviewSettings(
      previewMaxSeconds: previewMaxSeconds ?? this.previewMaxSeconds,
      segmentSeconds: segmentSeconds ?? this.segmentSeconds,
      minAheadSegments: minAheadSegments ?? this.minAheadSegments,
      maxAheadSegments: maxAheadSegments ?? this.maxAheadSegments,
      bufferRemainingFractionToRefill: bufferRemainingFractionToRefill ?? this.bufferRemainingFractionToRefill,
    );
  }
}

class PreviewSettingsNotifier extends StateNotifier<PreviewSettings> {
  PreviewSettingsNotifier(this._prefs)
    : super(
        PreviewSettings(
          previewMaxSeconds: _prefs.getInt(_previewMaxSecondsKey) ?? 300,
          segmentSeconds: _prefs.getInt(_segmentSecondsKey) ?? 16,
          minAheadSegments: _prefs.getInt(_minAheadSegmentsKey) ?? 4,
          maxAheadSegments: _prefs.getInt(_maxAheadSegmentsKey) ?? 8,
          bufferRemainingFractionToRefill: _prefs.getDouble(_bufferRemainingFractionToRefillKey) ?? 0.2,
        ),
      );

  static const _previewMaxSecondsKey = 'preview_max_seconds';
  static const _segmentSecondsKey = 'segment_seconds';
  static const _minAheadSegmentsKey = 'min_ahead_segments';
  static const _maxAheadSegmentsKey = 'max_ahead_segments';
  static const _bufferRemainingFractionToRefillKey = 'buffer_remaining_fraction_to_refill';

  final SharedPreferences _prefs;

  Future<void> setPreviewMaxSeconds(int seconds) async {
    state = state.copyWith(previewMaxSeconds: seconds);
    await _prefs.setInt(_previewMaxSecondsKey, seconds);
  }

  Future<void> setSegmentSeconds(int seconds) async {
    state = state.copyWith(segmentSeconds: seconds);
    await _prefs.setInt(_segmentSecondsKey, seconds);
  }

  Future<void> setMinAheadSegments(int segments) async {
    state = state.copyWith(minAheadSegments: segments);
    await _prefs.setInt(_minAheadSegmentsKey, segments);
  }

  Future<void> setMaxAheadSegments(int segments) async {
    state = state.copyWith(maxAheadSegments: segments);
    await _prefs.setInt(_maxAheadSegmentsKey, segments);
  }

  Future<void> setBufferRemainingFractionToRefill(double fraction) async {
    state = state.copyWith(bufferRemainingFractionToRefill: fraction);
    await _prefs.setDouble(_bufferRemainingFractionToRefillKey, fraction);
  }

  Future<void> resetToDefaults() async {
    state = const PreviewSettings(
      previewMaxSeconds: 300,
      segmentSeconds: 16,
      minAheadSegments: 4,
      maxAheadSegments: 8,
      bufferRemainingFractionToRefill: 0.2,
    );
    await _prefs.remove(_previewMaxSecondsKey);
    await _prefs.remove(_segmentSecondsKey);
    await _prefs.remove(_minAheadSegmentsKey);
    await _prefs.remove(_maxAheadSegmentsKey);
    await _prefs.remove(_bufferRemainingFractionToRefillKey);
  }
}
