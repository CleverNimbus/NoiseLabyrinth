import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/preview/preview_controller.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final editorState = ref.watch(editorNotifierProvider);
    final previewState = ref.watch(previewControllerProvider);
    final hasConfig = editorState.config != null;
    final isActive = previewState.isActive;
    final canPlay = hasConfig && !isActive;
    final canStop = isActive;

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
        ],
      ),
    );
  }
}
