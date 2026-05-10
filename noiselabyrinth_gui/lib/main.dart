import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noiselabyrinth_gui/header_widget.dart';
import 'package:noiselabyrinth_gui/wellcome_panel_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppPersistedState.load(prefs);
  runApp(MyApp(state: state));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.state, super.key});

  final AppPersistedState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'NoiseLabyrinth',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: MainShell(state: state),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2D5B85), brightness: Brightness.light);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6B7EB8), brightness: Brightness.dark);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF1A2028),
      cardTheme: CardThemeData(
        color: const Color(0xFF252D38),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class AppPersistedState extends ChangeNotifier {
  AppPersistedState({required this.prefs, required this.selectedFooter, required this.welcomeDismissed});

  static const _footerKey = 'selected_footer';
  static const _welcomeKey = 'welcome_dismissed';

  final SharedPreferences prefs;
  int selectedFooter;
  bool welcomeDismissed;

  static AppPersistedState load(SharedPreferences prefs) {
    return AppPersistedState(
      prefs: prefs,
      selectedFooter: prefs.getInt(_footerKey) ?? 0,
      welcomeDismissed: prefs.getBool(_welcomeKey) ?? false,
    );
  }

  Future<void> setFooter(int index) async {
    selectedFooter = index;
    welcomeDismissed = true;
    await prefs.setInt(_footerKey, selectedFooter);
    await prefs.setBool(_welcomeKey, true);
    notifyListeners();
  }

  Future<void> resetWelcome() async {
    welcomeDismissed = false;
    await prefs.setBool(_welcomeKey, false);
    notifyListeners();
  }
}

class MainShell extends StatelessWidget {
  const MainShell({required this.state, super.key});

  final AppPersistedState state;

  static const _footerItems = <_FooterItem>[
    _FooterItem(label: 'Quick start', icon: Icons.bolt_outlined),
    _FooterItem(label: 'Presets / Library', icon: Icons.library_music_outlined),
    _FooterItem(label: 'Create / Advanced', icon: Icons.tune_outlined),
  ];

  static const _panelTitles = <String>['Widget 1', 'Widget 2', 'Widget 3'];

  @override
  Widget build(BuildContext context) {
    final section = _footerItems[state.selectedFooter].label;

    return Scaffold(
      endDrawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(section: section),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                      child: _buildMainContent(context, section),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(context),
    );
  }

  Widget _buildMainContent(BuildContext context, String section) {
    if (!state.welcomeDismissed) {
      return WelcomePanelWidget(onStart: () => state.setFooter(state.selectedFooter));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_MainPanel(sectionTitle: section, widgetTitle: _panelTitles[state.selectedFooter])],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return BottomAppBar(
      height: 72,
      child: Row(
        children: [
          for (var i = 0; i < _footerItems.length; i++)
            Expanded(
              child: IconButton(
                tooltip: _footerItems[i].label,
                onPressed: () => state.setFooter(i),
                icon: Icon(
                  _footerItems[i].icon,
                  color: state.selectedFooter == i
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

  Widget _buildDrawer(BuildContext context) {
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
                state.resetWelcome();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MainPanel extends StatelessWidget {
  const _MainPanel({required this.sectionTitle, required this.widgetTitle});

  final String sectionTitle;
  final String widgetTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 340,
        child: Center(
          child: Text(
            '$sectionTitle - $widgetTitle',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}

class _FooterItem {
  const _FooterItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
