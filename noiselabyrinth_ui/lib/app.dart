import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/core/theme/app_theme.dart';
import 'package:noiselabyrinth_ui/features/shell/app_shell.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';
import 'package:noiselabyrinth_ui/state/profile_store.dart';

class NoiseLabyrinthApp extends StatefulWidget {
  const NoiseLabyrinthApp({super.key});

  @override
  State<NoiseLabyrinthApp> createState() => _NoiseLabyrinthAppState();
}

class _NoiseLabyrinthAppState extends State<NoiseLabyrinthApp> {
  late final ProfileStore _store;

  @override
  void initState() {
    super.initState();
    _store = ProfileStore();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      child: MaterialApp(
        title: 'Noise Labyrinth',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppShell(),
      ),
    );
  }
}
