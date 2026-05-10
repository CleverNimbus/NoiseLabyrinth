import 'package:flutter/material.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/preset_library_state.dart';

class PresetsPanel extends StatelessWidget {
  const PresetsPanel({required this.state, this.onOpen, super.key});

  final PresetLibraryState state;
  final ValueChanged<GenerationConfig>? onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final presets = state.presets;
        final tags = state.tags;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Presets / Library', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '${presets.length} presets${state.selectedTag == null ? '' : ' tagged "${state.selectedTag}"'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: state.selectedTag == null,
                      onSelected: (_) => state.selectTag(null),
                    ),
                    for (final tag in tags)
                      ChoiceChip(
                        label: Text(tag),
                        selected: state.selectedTag == tag,
                        onSelected: (_) => state.selectTag(tag),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (presets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No presets match this tag yet.', style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: presets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(preset.metadata.name, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                if (onOpen != null)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Open in editor',
                                    onPressed: () => onOpen!(preset),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (preset.metadata.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(preset.metadata.description, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in preset.metadata.tags)
                                  ActionChip(label: Text(tag), onPressed: () => state.selectTag(tag)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
