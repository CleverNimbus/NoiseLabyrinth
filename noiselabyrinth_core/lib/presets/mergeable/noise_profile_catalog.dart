import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/presets/mergeable/energy_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/feature_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/personality_profiles.dart';
import 'package:noiselabyrinth_core/presets/mergeable/style_profiles.dart';

Map<String, List<GenerationConfig>> noiseProfileGroups = <String, List<GenerationConfig>>{
  'energy': energyProfiles,
  'personality': personalityProfiles,
  'style': styleProfiles,
  'features': featureProfiles,
};

List<GenerationConfig> curatedNoiseProfiles = <GenerationConfig>[
  ...energyProfiles,
  ...personalityProfiles,
  ...styleProfiles,
  ...featureProfiles,
];
