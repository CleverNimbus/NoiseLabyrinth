import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  AppPersistedState({
    required this.prefs,
    required this.selectedFooter,
    required this.selectedWidget,
    required this.welcomeDismissed,
  });

  static const _footerKey = 'selected_footer';
  static const _widgetKey = 'selected_widget';
  static const _welcomeKey = 'welcome_dismissed';

  final SharedPreferences prefs;
  int selectedFooter;
  int selectedWidget;
  bool welcomeDismissed;

  static AppPersistedState load(SharedPreferences prefs) {
    return AppPersistedState(
      prefs: prefs,
      selectedFooter: prefs.getInt(_footerKey) ?? 0,
      selectedWidget: prefs.getInt(_widgetKey) ?? 0,
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

  Future<void> setWidgetIndex(int index) async {
    selectedWidget = index;
    await prefs.setInt(_widgetKey, selectedWidget);
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

  static const _widgetTitles = <String>['Widget 1', 'Widget 2', 'Widget 3', 'Widget 4'];

  @override
  Widget build(BuildContext context) {
    final section = _footerItems[state.selectedFooter].label;

    return Scaffold(
      endDrawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _Header(section: section),
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
      return _WelcomePanel(onStart: () => state.setFooter(state.selectedFooter));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _widgetTitles.length; i++)
              ChoiceChip(
                label: Text(_widgetTitles[i]),
                selected: state.selectedWidget == i,
                onSelected: (_) => state.setWidgetIndex(i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _MainPanel(sectionTitle: section, widgetTitle: _widgetTitles[state.selectedWidget]),
      ],
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

class _Header extends StatelessWidget {
  const _Header({required this.section});

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

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final horizontalPadding = isWide ? 24.0 : 16.0;
        final titleStyle = isWide
            ? Theme.of(context).textTheme.headlineMedium
            : Theme.of(context).textTheme.headlineSmall;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome', style: titleStyle),
                    const SizedBox(height: 10),
                    Text(
                      'This home widget appears on first launch. Select any footer icon to open the main panels.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open Main Panels'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
