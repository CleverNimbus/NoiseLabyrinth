import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/features/editor/editor_screen.dart';
import 'package:noiselabyrinth_ui/features/library/library_screen.dart';
import 'package:noiselabyrinth_ui/features/wizard/wizard_screen.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Create',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a creation path. All routes can be refined in the same editor.',
          style: TextStyle(color: Colors.blueGrey.shade200),
        ),
        const SizedBox(height: 16),
        _CreatePathCard(
          icon: Icons.tune,
          title: 'Manual Builder',
          subtitle: 'Start from a simple profile and open layered editing.',
          onTap: () {
            store.createFromScratch();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
            );
          },
        ),
        _CreatePathCard(
          icon: Icons.auto_stories,
          title: 'Preset Selection',
          subtitle: 'Browse curated profiles and clone into your library.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LibraryScreen(startOnPresets: true),
              ),
            );
          },
        ),
        _CreatePathCard(
          icon: Icons.auto_awesome,
          title: 'Wizard Generator',
          subtitle: 'Goal-based flow with finite guided steps.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WizardScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _CreatePathCard extends StatelessWidget {
  const _CreatePathCard({
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 30,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
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
