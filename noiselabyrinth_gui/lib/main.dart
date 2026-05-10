import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/my_app.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/persistence/objectbox_store.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final objectBox = await ObjectBoxStore.create();
  final repo = ObjectBoxGenerationConfigRepository(objectBox.store);
  await repo.seedIfEmpty(<GenerationConfig>[
    ...basicNoiseSpectrumProfiles,
    pinkNoiseBed,
    stereoBandlimitedHiss,
    sineDroneWithDelay,
  ]);
  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo), sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}
