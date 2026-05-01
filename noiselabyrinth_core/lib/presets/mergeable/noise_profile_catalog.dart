import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/presets/mergeable/energy_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/feature_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/personality_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/style_profiles.dart';

const Map<String, List<GenerationConfig>> noiseProfileGroups = <String, List<GenerationConfig>>{
  'energy': energyProfiles,
  'personality': personalityProfiles,
  'style': styleProfiles,
  'features': featureProfiles,
};

const List<GenerationConfig> curatedNoiseProfiles = <GenerationConfig>[
  ...energyProfiles,
  ...personalityProfiles,
  ...styleProfiles,
  ...featureProfiles,
];
