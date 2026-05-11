import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';
import 'package:noiselabyrinth_gui/state/preset_library_state.dart';

class PresetsPanel extends ConsumerWidget {
  const PresetsPanel({this.onOpen, super.key});

  final ValueChanged<StoredGenerationConfig>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(presetLibraryProvider);
    final presets = state.presets;
    final tags = state.tags;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Presets / Library', style: Theme.of(context).textTheme.headlineSmall)),
                OutlinedButton.icon(
                  onPressed: () => ref.read(presetLibraryProvider.notifier).reload(),
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${presets.length} stored configs${state.selectedTag == null ? '' : ' tagged "${state.selectedTag}"'}',
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
                  onSelected: (_) => ref.read(presetLibraryProvider.notifier).selectTag(null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                for (final tag in tags)
                  ChoiceChip(
                    label: Text(tag),
                    selected: state.selectedTag == tag,
                    onSelected: (_) => ref.read(presetLibraryProvider.notifier).selectTag(tag),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No stored configs match this tag yet.', style: Theme.of(context).textTheme.bodyLarge),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Updated')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Version')),
                    DataColumn(label: Text('Tags')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final preset in presets)
                      DataRow(
                        cells: [
                          DataCell(Text('${preset.id ?? '-'}')),
                          DataCell(Text(_formatTimestamp(preset.updatedAtEpochMs))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(preset.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(preset.description, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DataCell(Text('${preset.version}')),
                          DataCell(
                            SizedBox(
                              width: 260,
                              height: 28,
                              child: preset.tags.isEmpty
                                  ? const Align(alignment: Alignment.centerLeft, child: Text('-'))
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: preset.tags.length,
                                      separatorBuilder: (_, _) => const SizedBox(width: 4),
                                      itemBuilder: (context, index) {
                                        final tag = preset.tags[index];
                                        return _CompactTagChip(
                                          label: tag,
                                          onPressed: () => ref.read(presetLibraryProvider.notifier).selectTag(tag),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          DataCell(_PresetRowActions(preset: preset, onOpen: onOpen)),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(int epochMs) {
    final value = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute:$second';
  }
}

class _PresetRowActions extends ConsumerStatefulWidget {
  const _PresetRowActions({required this.preset, required this.onOpen});

  final StoredGenerationConfig preset;
  final ValueChanged<StoredGenerationConfig>? onOpen;

  @override
  ConsumerState<_PresetRowActions> createState() => _PresetRowActionsState();
}

class _PresetRowActionsState extends ConsumerState<_PresetRowActions> {
  bool _confirmDelete = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(presetLibraryProvider.notifier);

    return MouseRegion(
      onExit: (_) {
        if (_confirmDelete && mounted) {
          setState(() => _confirmDelete = false);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Load into Create panel',
            onPressed: widget.onOpen == null ? null : () => widget.onOpen!(widget.preset),
            visualDensity: VisualDensity.compact,
          ),
          if (_confirmDelete) ...[
            IconButton(
              icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.error),
              tooltip: 'Cancel deletion',
              onPressed: () => setState(() => _confirmDelete = false),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.check_rounded, color: Colors.green.shade700),
              tooltip: 'Confirm deletion',
              onPressed: () async {
                final id = widget.preset.id;
                if (id != null) {
                  await notifier.delete(id);
                }
                if (mounted) {
                  setState(() => _confirmDelete = false);
                }
              },
              visualDensity: VisualDensity.compact,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete stored config',
              onPressed: widget.preset.id == null ? null : () => setState(() => _confirmDelete = true),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _CompactTagChip extends StatelessWidget {
  const _CompactTagChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, overflow: TextOverflow.fade, softWrap: false),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: EdgeInsets.zero,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
