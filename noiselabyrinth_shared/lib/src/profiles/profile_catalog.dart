import 'dart:collection';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_core/presets/brown_tests.dart';
import 'package:noiselabyrinth_core/presets/nature_tests.dart';

class SharedProfileCatalog {
  const SharedProfileCatalog._();

  static final List<GenerationConfig> defaultProfiles = UnmodifiableListView<GenerationConfig>(<GenerationConfig>[
    BrownConfigTests.brownNoiseProfile_001,
    BrownConfigTests.getBrownNoiseProfile_002(),
    BrownConfigTests.getBrownNoiseProfile_003(),
    NatureConfigTests.wind_001,
    NatureConfigTests.rain_002,
    NatureConfigTests.sea_003,
    NatureConfigTests.storm_004,
    NatureConfigTests.seaStorm_005,
    NatureConfigTests.forest_006,
    pinkNoiseBed,
    stereoBandlimitedHiss,
    sineDroneWithDelay,
    whiteNoiseProfile,
    pinkNoiseProfile,
    brownNoiseProfile,
    bandlimitedNoiseProfile,
  ]);
}
