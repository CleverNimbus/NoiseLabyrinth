import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/export/render_export_destination.dart';
import 'package:noiselabyrinth_shared/noiselabyrinth_shared.dart';

final exportControllerProvider = StateNotifierProvider<ExportController, bool>((_) => ExportController());

class ExportController extends StateNotifier<bool> {
  ExportController() : super(false);

  static const Mp3Renderer _mp3Renderer = Mp3Renderer();
  static const RenderConfigPolicy _renderConfigPolicy = RenderConfigPolicy();

  Future<String?> export(GenerationConfig config) async {
    if (state) {
      return null;
    }

    state = true;
    try {
      final normalized = _renderConfigPolicy.forceMp3(config);
      final bytes = await _mp3Renderer.render(normalized);
      final outputName = _suggestedFilename(config);
      final saved = await saveRenderBytes(suggestedFileName: outputName, bytes: bytes);

      if (!saved.saved) {
        return null;
      }
      if (saved.downloaded) {
        return 'Download started: $outputName';
      }
      if (saved.path != null && saved.path!.trim().isNotEmpty) {
        return 'Exported render to ${saved.path}';
      }
      return 'Exported render.';
    } finally {
      state = false;
    }
  }

  String _suggestedFilename(GenerationConfig config) {
    final rawName = config.metadata.name.trim();
    final safeBase = rawName.isEmpty ? 'noise_profile' : _sanitizeForFilename(rawName);
    final stamp = _timestampForFilename(DateTime.now());
    return '${safeBase}_$stamp.mp3';
  }

  String _sanitizeForFilename(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'noise_profile' : cleaned;
  }

  String _timestampForFilename(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}${two(local.month)}${two(local.day)}_${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }
}
