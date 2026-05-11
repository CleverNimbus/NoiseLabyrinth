import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/export/export_controller.dart';
import 'package:noiselabyrinth_gui/state/preview/preview_controller.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final editorState = ref.watch(editorNotifierProvider);
    final previewState = ref.watch(previewControllerProvider);
    final isExporting = ref.watch(exportControllerProvider);
    final hasConfig = editorState.config != null;
    final isActive = previewState.isActive;
    final canPlay = hasConfig && !isActive;
    final canStop = isActive;
    final canExport = (canPlay || canStop) && !isExporting;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.surface, colors.surfaceContainerHighest.withValues(alpha: 0.35)]),
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      const LinearGradient(colors: [Color(0xFF6AA8FF), Color(0xFF8CD7CF)]).createShader(bounds),
                  child: const Text(
                    'NoiseLabyrinth',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 7, offset: Offset(0, 1))],
                    ),
                  ),
                ),
                Text(
                  section,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: (canPlay || canStop)
                ? () {
                    final notifier = ref.read(previewControllerProvider.notifier);
                    if (canStop) {
                      notifier.stop();
                      return;
                    }
                    final config = editorState.config;
                    if (config != null) {
                      notifier.start(config, editorState.configRevision);
                    }
                  }
                : null,
            tooltip: canStop ? 'Stop preview' : 'Play preview',
            icon: Icon(canStop ? Icons.stop : Icons.play_arrow),
          ),
          IconButton(
            onPressed: canExport
                ? () async {
                    final config = editorState.config;
                    if (config == null) {
                      return;
                    }

                    try {
                      final message = await ref.read(exportControllerProvider.notifier).export(config);
                      if (!context.mounted || message == null) {
                        return;
                      }
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $error'), duration: const Duration(seconds: 4)),
                      );
                    }
                  }
                : null,
            tooltip: 'Export render',
            icon: isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
    );
  }
}
