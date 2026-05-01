import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/features/create/create_screen.dart';
import 'package:noiselabyrinth_ui/features/editor/editor_screen.dart';
import 'package:noiselabyrinth_ui/features/home/home_screen.dart';
import 'package:noiselabyrinth_ui/features/library/library_screen.dart';
import 'package:noiselabyrinth_ui/features/player/player_screen.dart';
import 'package:noiselabyrinth_ui/features/settings/settings_screen.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    final tabs = <Widget>[
      const HomeScreen(),
      const LibraryScreen(),
      const CreateScreen(),
      const PlayerScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0A0E15),
              Color(0xFF101726),
              Color(0xFF131E2D),
            ],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(index: store.selectedTab, children: tabs),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: store.selectedTab,
        onTap: store.setSelectedTab,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.graphic_eq),
            label: 'Player',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: store.selectedTab == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                store.createFromScratch();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Profile'),
            )
          : null,
    );
  }
}
