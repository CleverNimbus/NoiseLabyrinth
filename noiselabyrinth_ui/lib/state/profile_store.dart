import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:noiselabyrinth_core/engine/audio_engine.dart';
import 'package:noiselabyrinth_core/engine/runtime_graph_builder.dart';
import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class ProfileRecord {
  final String id;
  final GenerationConfig config;
  final DateTime updatedAt;
  final bool isPreset;

  const ProfileRecord({
    required this.id,
    required this.config,
    required this.updatedAt,
    required this.isPreset,
  });

  ProfileRecord copyWith({
    String? id,
    GenerationConfig? config,
    DateTime? updatedAt,
    bool? isPreset,
  }) {
    return ProfileRecord(
      id: id ?? this.id,
      config: config ?? this.config,
      updatedAt: updatedAt ?? this.updatedAt,
      isPreset: isPreset ?? this.isPreset,
    );
  }
}

class WizardDraft {
  final String goal;
  final String preference;
  final String complexity;
  final String environment;
  final double lowFrequencyBias;

  const WizardDraft({
    required this.goal,
    required this.preference,
    required this.complexity,
    required this.environment,
    required this.lowFrequencyBias,
  });
}

class ProfileStore extends ChangeNotifier {
  ProfileStore() {
    _presets = _buildPresets();
    final created = createFromScratch();
    _activeProfileId = created.id;
  }

  final List<ProfileRecord> _profiles = <ProfileRecord>[];
  late final List<ProfileRecord> _presets;

  String? _activeProfileId;
  int _selectedTab = 0;

  List<ProfileRecord> get profiles =>
      List<ProfileRecord>.unmodifiable(_profiles);

  List<ProfileRecord> get presets => List<ProfileRecord>.unmodifiable(_presets);

  int get selectedTab => _selectedTab;

  ProfileRecord? get activeProfile {
    final activeId = _activeProfileId;
    if (activeId == null) {
      return _profiles.isEmpty ? null : _profiles.first;
    }
    for (final profile in _profiles) {
      if (profile.id == activeId) {
        return profile;
      }
    }
    return _profiles.isEmpty ? null : _profiles.first;
  }

  void setSelectedTab(int index) {
    if (index == _selectedTab) {
      return;
    }
    _selectedTab = index;
    notifyListeners();
  }

  void setActiveProfile(String profileId) {
    if (_activeProfileId == profileId) {
      return;
    }
    _activeProfileId = profileId;
    notifyListeners();
  }

  ProfileRecord createFromScratch() {
    final config = _defaultConfig(
      name: 'Untitled Profile ${_profiles.length + 1}',
    );
    final profile = _buildUserProfile(config);
    _profiles.insert(0, profile);
    _activeProfileId = profile.id;
    notifyListeners();
    return profile;
  }

  ProfileRecord createFromPreset(ProfileRecord preset) {
    final metadata = MetadataConfig(
      name: '${preset.config.metadata.name} Copy',
      description: preset.config.metadata.description,
      tags: List<String>.from(preset.config.metadata.tags),
      version: 1,
    );
    final created = _buildUserProfile(
      GenerationConfig(
        metadata: metadata,
        render: preset.config.render,
        mix: preset.config.mix,
        layers: preset.config.layers,
      ),
    );
    _profiles.insert(0, created);
    _activeProfileId = created.id;
    notifyListeners();
    return created;
  }

  ProfileRecord createFromWizard(WizardDraft draft) {
    final baseColor = switch (draft.goal) {
      'Sleep' => NoiseColor.pink,
      'Focus' => NoiseColor.bandlimited,
      'Relaxation' => NoiseColor.brown,
      _ => NoiseColor.white,
    };

    final preferenceGain = switch (draft.preference) {
      'Soft' => 0.45,
      'Dense' => 0.7,
      'Dynamic' => 0.55,
      _ => 0.5,
    };

    final layerCount = switch (draft.complexity) {
      'Static' => 1,
      'Slight Variation' => 2,
      _ => 3,
    };

    final processor = switch (draft.environment) {
      'Rain' => const ProcessorConfig(
        id: 'delay_rain',
        type: ProcessorType.delay,
        delay: DelayConfig(delayTimeMs: 90, feedback: 0.2, mix: 0.25),
      ),
      'Cave' => const ProcessorConfig(
        id: 'delay_cave',
        type: ProcessorType.delay,
        delay: DelayConfig(delayTimeMs: 220, feedback: 0.35, mix: 0.35),
      ),
      'Wind' => const ProcessorConfig(
        id: 'sat_wind',
        type: ProcessorType.saturator,
        saturator: SaturatorConfig(drive: 0.2, curve: SaturatorCurve.soft),
      ),
      _ => const ProcessorConfig(
        id: 'eq_default',
        type: ProcessorType.biquad,
        biquad: BiquadConfig(
          biquadMode: BiquadMode.lowpass,
          frequency: 8000,
          q: 0.8,
        ),
      ),
    };

    final layers = List<LayerConfig>.generate(layerCount, (index) {
      final pan = layerCount == 1 ? 0.0 : (index / (layerCount - 1)) * 2 - 1;
      final high = (18000 - (draft.lowFrequencyBias * 10000).round()).clamp(
        1500,
        18000,
      );
      return LayerConfig(
        id: 'layer_${DateTime.now().millisecondsSinceEpoch}_$index',
        gain: preferenceGain / layerCount,
        pan: pan,
        source: SourceConfig(
          type: SourceType.noise,
          noiseConfig: NoiseConfig(
            color: index == 0 ? baseColor : NoiseColor.white,
            band: BandConfig(low: 20, high: high),
          ),
        ),
        processors: <ProcessorConfig>[processor],
        modulations: draft.complexity == 'Dynamic Environment'
            ? <ModulationConfig>[
                ModulationConfig(
                  id: 'lfo_$index',
                  type: ModulationType.lfo,
                  amount: 0.2,
                  lfoConfig: const LfoConfig(
                    type: LFOType.sine,
                    frequency: 0.12,
                    depth: 1.0,
                  ),
                  targets: const <ModulationTargetConfig>[
                    ModulationTargetConfig(
                      path: 'source.bandHigh',
                      amount: 1000,
                    ),
                  ],
                ),
              ]
            : const <ModulationConfig>[],
      );
    });

    final config = GenerationConfig(
      metadata: MetadataConfig(
        name: '${draft.goal} Studio',
        description:
            'Generated from wizard: ${draft.goal.toLowerCase()} profile',
        tags: <String>[
          draft.goal.toLowerCase(),
          draft.preference.toLowerCase(),
        ],
        version: 1,
      ),
      render: const RenderConfig(
        durationMinutes: 45,
        sampleRate: 44100,
        bitRate: 192,
      ),
      mix: const MixConfig(mix: 1.0),
      layers: layers,
    );

    final created = _buildUserProfile(config);
    _profiles.insert(0, created);
    _activeProfileId = created.id;
    notifyListeners();
    return created;
  }

  void updateActiveProfile(GenerationConfig config) {
    final activeId = _activeProfileId;
    if (activeId == null) {
      return;
    }
    _replaceProfile(
      activeId,
      (profile) => profile.copyWith(config: config, updatedAt: DateTime.now()),
    );
  }

  void duplicateProfile(String profileId) {
    final existing = _profiles.where((p) => p.id == profileId).firstOrNull;
    if (existing == null) {
      return;
    }

    final duplicate = _buildUserProfile(
      GenerationConfig(
        metadata: MetadataConfig(
          name: '${existing.config.metadata.name} Copy',
          description: existing.config.metadata.description,
          tags: existing.config.metadata.tags,
          version: existing.config.metadata.version,
        ),
        render: existing.config.render,
        mix: existing.config.mix,
        layers: existing.config.layers,
      ),
    );

    _profiles.insert(0, duplicate);
    _activeProfileId = duplicate.id;
    notifyListeners();
  }

  void deleteProfile(String profileId) {
    final beforeCount = _profiles.length;
    _profiles.removeWhere((profile) => profile.id == profileId);
    if (_profiles.length == beforeCount) {
      return;
    }

    if (_activeProfileId == profileId) {
      _activeProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }

    if (_profiles.isEmpty) {
      final profile = createFromScratch();
      _activeProfileId = profile.id;
      return;
    }

    notifyListeners();
  }

  Future<List<double>> buildWaveformPreview(
    ProfileRecord profile, {
    int seconds = 6,
    int points = 180,
  }) async {
    final graph = RuntimeGraphBuilder(
      sampleRate: profile.config.render.sampleRate,
    ).build(profile.config);
    final engine = AudioEngine(
      graph: graph,
      sampleRate: profile.config.render.sampleRate,
      blockSize: 512,
    );

    final durationSamples = profile.config.render.sampleRate * seconds;
    final stereo = engine.renderStereoSamples(totalSamples: durationSamples);

    final left = stereo.left;
    final bucketSize = math.max(1, left.length ~/ points);
    final preview = <double>[];

    for (var start = 0; start < left.length; start += bucketSize) {
      var maxValue = 0.0;
      final end = math.min(left.length, start + bucketSize);
      for (var i = start; i < end; i++) {
        final value = left[i].abs();
        if (value > maxValue) {
          maxValue = value;
        }
      }
      preview.add(maxValue.clamp(0.0, 1.0));
    }

    return preview;
  }

  void _replaceProfile(
    String profileId,
    ProfileRecord Function(ProfileRecord) mapFn,
  ) {
    for (var index = 0; index < _profiles.length; index++) {
      if (_profiles[index].id == profileId) {
        _profiles[index] = mapFn(_profiles[index]);
        notifyListeners();
        return;
      }
    }
  }

  ProfileRecord _buildUserProfile(GenerationConfig config) {
    final timestamp = DateTime.now();
    return ProfileRecord(
      id: 'profile_${timestamp.microsecondsSinceEpoch}',
      config: config,
      updatedAt: timestamp,
      isPreset: false,
    );
  }

  List<ProfileRecord> _buildPresets() {
    return <ProfileRecord>[
      ProfileRecord(
        id: 'preset_calm',
        config: _defaultConfig(
          name: 'Calm Drift',
          description: 'Warm pink noise with subtle motion for long sessions.',
          tags: const <String>['sleep', 'calm'],
          layers: <LayerConfig>[
            _defaultLayer(
              id: 'calm_layer_1',
              color: NoiseColor.pink,
              gain: 0.62,
              low: 20,
              high: 8200,
            ),
          ],
        ),
        updatedAt: DateTime.now(),
        isPreset: true,
      ),
      ProfileRecord(
        id: 'preset_focus',
        config: _defaultConfig(
          name: 'Focus Canopy',
          description:
              'Band-limited texture with gentle width for concentration.',
          tags: const <String>['focus', 'steady'],
          layers: <LayerConfig>[
            _defaultLayer(
              id: 'focus_layer_1',
              color: NoiseColor.bandlimited,
              gain: 0.45,
              low: 120,
              high: 6200,
              pan: -0.2,
            ),
            _defaultLayer(
              id: 'focus_layer_2',
              color: NoiseColor.white,
              gain: 0.24,
              low: 200,
              high: 4200,
              pan: 0.2,
            ),
          ],
        ),
        updatedAt: DateTime.now(),
        isPreset: true,
      ),
    ];
  }

  GenerationConfig _defaultConfig({
    required String name,
    String description = 'Created in Noise Labyrinth',
    List<String> tags = const <String>['manual'],
    List<LayerConfig>? layers,
  }) {
    return GenerationConfig(
      metadata: MetadataConfig(
        name: name,
        description: description,
        tags: tags,
        version: 1,
      ),
      render: const RenderConfig(
        durationMinutes: 20,
        sampleRate: 44100,
        bitRate: 192,
      ),
      mix: const MixConfig(mix: 1.0),
      layers: layers ?? <LayerConfig>[_defaultLayer(id: 'layer_1')],
    );
  }

  LayerConfig _defaultLayer({
    required String id,
    NoiseColor color = NoiseColor.white,
    double gain = 0.5,
    double pan = 0.0,
    int low = 20,
    int high = 18000,
  }) {
    return LayerConfig(
      id: id,
      gain: gain,
      pan: pan,
      source: SourceConfig(
        type: SourceType.noise,
        noiseConfig: NoiseConfig(
          color: color,
          band: BandConfig(low: low, high: high),
        ),
      ),
      processors: const <ProcessorConfig>[
        ProcessorConfig(
          id: 'main_filter',
          type: ProcessorType.biquad,
          biquad: BiquadConfig(
            biquadMode: BiquadMode.lowpass,
            frequency: 12000,
            q: 0.8,
          ),
        ),
      ],
      modulations: const <ModulationConfig>[],
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
