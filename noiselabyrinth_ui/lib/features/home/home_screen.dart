import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/features/editor/editor_screen.dart';
import 'package:noiselabyrinth_ui/features/wizard/wizard_screen.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';
import 'package:noiselabyrinth_ui/state/profile_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final active = store.activeProfile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Noise Labyrinth',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Calm, fast procedural profile creation.',
          style: TextStyle(color: Colors.blueGrey.shade200),
        ),
        const SizedBox(height: 16),
        if (active != null) _CurrentProfileCard(profile: active),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.layers_outlined,
          title: 'Create from Scratch',
          subtitle: 'Start with one noise layer and tune it in the editor.',
          onTap: () {
            store.createFromScratch();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
            );
          },
        ),
        _ActionCard(
          icon: Icons.library_music,
          title: 'Use Preset',
          subtitle: 'Clone a curated preset and adjust it quickly.',
          onTap: () {
            store.setSelectedTab(1);
          },
        ),
        _ActionCard(
          icon: Icons.auto_awesome,
          title: 'Wizard (Mood-Based)',
          subtitle: 'Generate a profile from goal and preference choices.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WizardScreen()),
            );
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Recent Profiles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: store.profiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final profile = store.profiles[index];
              return _RecentProfileTile(
                profile: profile,
                onTap: () {
                  store.setActiveProfile(profile.id);
                  store.setSelectedTab(3);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CurrentProfileCard extends StatelessWidget {
  const _CurrentProfileCard({required this.profile});

  final ProfileRecord profile;

  @override
  Widget build(BuildContext context) {
    final tags = profile.config.metadata.tags;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    profile.config.metadata.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    AppScope.of(context).setSelectedTab(3);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade400.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blue.shade100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.blueGrey.shade100),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentProfileTile extends StatelessWidget {
  const _RecentProfileTile({required this.profile, required this.onTap});

  final ProfileRecord profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.config.metadata.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${profile.config.layers.length} layers • ${profile.config.render.durationMinutes} min',
                  style: TextStyle(color: Colors.blueGrey.shade100),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
