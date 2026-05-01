import 'dart:io';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_core/presets/tests.dart';
import 'package:path/path.dart' as p;

List<GenerationConfig> hardcodedProfiles = <GenerationConfig>[
  pinkNoiseBed,
  stereoBandlimitedHiss,
  sineDroneWithDelay,
  whiteNoiseProfile,
  pinkNoiseProfile,
  brownNoiseProfile,
  bandlimitedNoiseProfile,
  const GenerationsMerger().merge(
    vibrantStyleProfile,
    clarityPersonalityProfile,
    <GenerationConfig>[
      psychoacousticFeatureProfile,
      activationEnergyProfile,
      ambianceEnergyProfile,
    ],
  ),
  brownNoiseDeepField,
  whiteFullband,
  brownLow,
  bandpassMid,
  sineReference,
  biquadLowpassTest,
  delayImpulseTest,
  lfoGainTest,
  randomFilterTest,
  stormForestVivid,
];

GenerationConfig forceMp3(GenerationConfig config) {
  return GenerationConfig(
    metadata: config.metadata,
    render: RenderConfig(
      durationMinutes: config.render.durationMinutes,
      sampleRate: config.render.sampleRate,
      bitRate: config.render.bitRate,
    ),
    mix: config.mix,
    layers: config.layers,
  );
}

Directory userMusicDirectory() {
  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return Directory(p.join(home, 'Música'));
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    return Directory(p.join(userProfile, 'Música'));
  }

  return Directory.current;
}

String timestampForFilename(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}'
      '${two(local.month)}'
      '${two(local.day)}_'
      '${two(local.hour)}'
      '${two(local.minute)}'
      '${two(local.second)}';
}

String outputFilename(int menuNumber, DateTime dateTime) {
  return '${menuNumber}_${timestampForFilename(dateTime)}.mp3';
}
