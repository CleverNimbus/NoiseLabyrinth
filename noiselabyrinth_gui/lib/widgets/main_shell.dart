import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/app_header.dart';
import 'package:noiselabyrinth_gui/widgets/create_panel.dart';
import 'package:noiselabyrinth_gui/widgets/footer_item.dart';
import 'package:noiselabyrinth_gui/widgets/presets_panel.dart';
import 'package:noiselabyrinth_gui/widgets/quick_start_panel.dart';
import 'package:noiselabyrinth_gui/widgets/wellcome_panel.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  void _onPresetOpen(WidgetRef ref, StoredGenerationConfig stored) {
    ref.read(editorNotifierProvider.notifier).openStoredConfig(stored);
    ref.read(appPersistedProvider.notifier).setFooter(2);
  }

  static const _footerItems = <FooterItem>[
    FooterItem(label: 'Quick start', icon: Icons.bolt_outlined),
    FooterItem(label: 'Presets / Library', icon: Icons.library_music_outlined),
    FooterItem(label: 'Create / Advanced', icon: Icons.tune_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appPersistedProvider);
    final section = _footerItems[appState.selectedFooter].label;

    return Scaffold(
      endDrawer: _buildDrawer(context, ref),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(section: section),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: _buildMainContent(context, ref, appState),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context, ref, appState),
    );
  }

  Widget _buildMainContent(BuildContext context, WidgetRef ref, AppPersistedState appState) {
    if (!appState.welcomeDismissed) {
      return SingleChildScrollView(
        child: WelcomePanel(onStart: () => ref.read(appPersistedProvider.notifier).setFooter(appState.selectedFooter)),
      );
    }

    // CreatePanel (index 2) needs bounded height for its Expanded internal layout.
    // Other panels are scrollable.
    if (appState.selectedFooter == 2) {
      return const CreatePanel();
    }

    final scrollablePanels = <Widget>[
      const QuickStartPanel(),
      PresetsPanel(onOpen: (config) => _onPresetOpen(ref, config)),
    ];

    return SingleChildScrollView(child: scrollablePanels[appState.selectedFooter]);
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, AppPersistedState appState) {
    return BottomAppBar(
      height: 72,
      child: Row(
        children: [
          for (var i = 0; i < _footerItems.length; i++)
            Expanded(
              child: IconButton(
                tooltip: _footerItems[i].label,
                onPressed: () => ref.read(appPersistedProvider.notifier).setFooter(i),
                icon: Icon(
                  _footerItems[i].icon,
                  color: appState.selectedFooter == i
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                return IconButton(
                  tooltip: 'App menu',
                  icon: const Icon(Icons.menu),
                  onPressed: Scaffold.of(context).openEndDrawer,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const ListTile(title: Text('App Options'), subtitle: Text('Placeholders for upcoming actions')),
            const Divider(),
            const ListTile(leading: Icon(Icons.settings_outlined), title: Text('Placeholder Option 1')),
            const ListTile(leading: Icon(Icons.info_outline), title: Text('Placeholder Option 2')),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Show Welcome Again'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(appPersistedProvider.notifier).resetWelcome();
              },
            ),
          ],
        ),
      ),
    );
  }
}
