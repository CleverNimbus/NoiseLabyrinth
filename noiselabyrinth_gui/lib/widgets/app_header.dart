import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
          IconButton(onPressed: null, tooltip: 'Play', icon: const Icon(Icons.play_arrow)),
        ],
      ),
    );
  }
}
