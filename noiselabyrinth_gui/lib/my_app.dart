import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/widgets/main_shell.dart';

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appPersistedProvider);
    final appNotifier = ref.read(appPersistedProvider.notifier);

    return MaterialApp(
      title: 'NoiseLabyrinth',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      builder: (context, child) {
        final zoom = appState.zoomFactor;
        final shortcuts = <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.minus, control: true): const _ZoomOutIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): const _ZoomOutIntent(),
          const SingleActivator(LogicalKeyboardKey.equal, control: true): const _ZoomInIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): const _ZoomInIntent(),
          const SingleActivator(LogicalKeyboardKey.digit0, control: true): const _ZoomResetIntent(),
          const SingleActivator(LogicalKeyboardKey.numpad0, control: true): const _ZoomResetIntent(),
        };

        return Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: <Type, Action<Intent>>{
              _ZoomInIntent: CallbackAction<_ZoomInIntent>(onInvoke: (_) => appNotifier.zoomIn()),
              _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(onInvoke: (_) => appNotifier.zoomOut()),
              _ZoomResetIntent: CallbackAction<_ZoomResetIntent>(onInvoke: (_) => appNotifier.resetZoom()),
            },
            child: Focus(
              autofocus: true,
              child: Builder(
                builder: (context) {
                  final mediaQuery = MediaQuery.of(context);
                  final windowSize = mediaQuery.size;
                  final logicalSize = Size(windowSize.width / zoom, windowSize.height / zoom);

                  return SizedBox.expand(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: logicalSize.width,
                        maxWidth: logicalSize.width,
                        minHeight: logicalSize.height,
                        maxHeight: logicalSize.height,
                        child: Transform(
                          alignment: Alignment.topLeft,
                          transform: Matrix4.identity()..scaleByDouble(zoom, zoom, 1, 1),
                          child: SizedBox(
                            width: logicalSize.width,
                            height: logicalSize.height,
                            child: MediaQuery(
                              data: mediaQuery.copyWith(size: logicalSize),
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      home: const MainShell(),
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
