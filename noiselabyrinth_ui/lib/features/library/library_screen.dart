import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/features/editor/editor_screen.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';
import 'package:noiselabyrinth_ui/state/profile_store.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.startOnPresets = false});

  final bool startOnPresets;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final initialIndex = startOnPresets ? 1 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Library',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: store.createFromScratch,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              enabled: false,
              decoration: const InputDecoration(
                hintText: 'Search and filters coming next',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const TabBar(
            tabs: <Tab>[
              Tab(text: 'My Profiles'),
              Tab(text: 'Presets'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ProfilesList(
                  items: store.profiles,
                  onPlay: (item) {
                    store.setActiveProfile(item.id);
                    store.setSelectedTab(3);
                  },
                  onEdit: (item) {
                    store.setActiveProfile(item.id);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditorScreen(),
                      ),
                    );
                  },
                  onDuplicate: (item) => store.duplicateProfile(item.id),
                  onDelete: (item) => store.deleteProfile(item.id),
                ),
                _ProfilesList(
                  items: store.presets,
                  onPlay: (item) {
                    final created = store.createFromPreset(item);
                    store.setActiveProfile(created.id);
                    store.setSelectedTab(3);
                  },
                  onEdit: (item) {
                    final created = store.createFromPreset(item);
                    store.setActiveProfile(created.id);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditorScreen(),
                      ),
                    );
                  },
                  onDuplicate: (item) => store.createFromPreset(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilesList extends StatelessWidget {
  const _ProfilesList({
    required this.items,
    required this.onPlay,
    required this.onEdit,
    required this.onDuplicate,
    this.onDelete,
  });

  final List<ProfileRecord> items;
  final ValueChanged<ProfileRecord> onPlay;
  final ValueChanged<ProfileRecord> onEdit;
  final ValueChanged<ProfileRecord> onDuplicate;
  final ValueChanged<ProfileRecord>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No profiles yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.config.metadata.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.config.layers.length} layers • ${item.config.render.durationMinutes} min',
                  style: TextStyle(color: Colors.blueGrey.shade100),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.config.metadata.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => onPlay(item),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    TextButton.icon(
                      onPressed: () => onEdit(item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => onDuplicate(item),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Duplicate'),
                    ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: () => onDelete!(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
