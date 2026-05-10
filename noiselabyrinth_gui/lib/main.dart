import 'package:flutter/material.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/my_app.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/persistence/objectbox_store.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/state/preset_library_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final objectBox = await ObjectBoxStore.create();
  final presetLibraryState = PresetLibraryState(
    ObjectBoxGenerationConfigRepository(objectBox.store),
  );
  await presetLibraryState.seedDefaults(<GenerationConfig>[
    ...basicNoiseSpectrumProfiles,
    pinkNoiseBed,
    stereoBandlimitedHiss,
    sineDroneWithDelay,
  ]);
  final state = AppPersistedState.load(prefs);
  runApp(
    MyApp(
      state: state,
      presetLibraryState: presetLibraryState,
    ),
  );
}
