import 'dart:convert';

import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class ConfigValidationIssue {
  ConfigValidationIssue({required this.path, required this.message});
  String path;
  String message;

  @override
  String toString() => '$path: $message';
}

class ConfigValidationException implements Exception {
  ConfigValidationException(this.issues);
  List<ConfigValidationIssue> issues;

  @override
  String toString() {
    final details = issues.map((issue) => '- $issue').join('\n');
    return 'Configuration validation failed with ${issues.length} issue(s):\n$details';
  }
}

class GenerationConfigParser {
  GenerationConfigParser();

  GenerationConfig parseJsonString(String jsonSource) {
    final decoded = jsonDecode(jsonSource);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON value must be an object.');
    }

    return parseJsonMap(decoded);
  }

  GenerationConfig parseJsonMap(Map<String, dynamic> json) {
    final config = GenerationConfig.fromJson(json);
    final issues = validate(config);
    if (issues.isNotEmpty) {
      throw ConfigValidationException(issues);
    }
    return config;
  }

  List<ConfigValidationIssue> validate(GenerationConfig config) {
    final issues = <ConfigValidationIssue>[];

    _validateRoot(config, issues);

    final validTargetPaths = <String>{};
    for (var i = 0; i < config.layers.length; i++) {
      final layer = config.layers[i];
      _validateLayer(layer, i, issues);
      validTargetPaths.addAll(_buildLayerTargetPaths(layer));
    }

    for (var i = 0; i < config.layers.length; i++) {
      final layer = config.layers[i];
      _validateLayerCrossReferences(layer, i, validTargetPaths, issues);
    }

    return issues;
  }

  void _validateRoot(
    GenerationConfig config,
    List<ConfigValidationIssue> issues,
  ) {
    if (config.metadata.name.trim().isEmpty) {
      issues.add(
        ConfigValidationIssue(
          path: 'metadata.name',
          message: 'name is required.',
        ),
      );
    }

    if (config.render.durationMinutes <= 0) {
      issues.add(
        ConfigValidationIssue(
          path: 'render.durationMinutes',
          message: 'durationMinutes must be > 0.',
        ),
      );
    }

    if (config.render.sampleRate <= 0) {
      issues.add(
        ConfigValidationIssue(
          path: 'render.sampleRate',
          message: 'sampleRate must be > 0.',
        ),
      );
    }

    if (config.render.bitRate <= 0) {
      issues.add(
        ConfigValidationIssue(
          path: 'render.bitRate',
          message: 'bitRate must be > 0.',
        ),
      );
    }

    if (config.mix.mix < 0.0 || config.mix.mix > 1.0) {
      issues.add(
        ConfigValidationIssue(
          path: 'mix.mix',
          message: 'mix must be in [0, 1].',
        ),
      );
    }

    if (config.mix.dither.bitDepth <= 0) {
      issues.add(
        ConfigValidationIssue(
          path: 'mix.dither.bitDepth',
          message: 'bitDepth must be > 0.',
        ),
      );
    }

    if (config.mix.dither.amount < 0.0) {
      issues.add(
        ConfigValidationIssue(
          path: 'mix.dither.amount',
          message: 'amount must be >= 0.',
        ),
      );
    }

    if (config.mix.normalization.targetDb > 0.0) {
      issues.add(
        ConfigValidationIssue(
          path: 'mix.normalization.targetDb',
          message: 'targetDb must be <= 0 dBFS.',
        ),
      );
    }

    if (config.mix.normalization.targetDb < -120.0) {
      issues.add(
        ConfigValidationIssue(
          path: 'mix.normalization.targetDb',
          message: 'targetDb must be >= -120 dBFS.',
        ),
      );
    }

    if (config.layers.isEmpty) {
      issues.add(
        ConfigValidationIssue(
          path: 'layers',
          message: 'at least one layer is required.',
        ),
      );
    }

    final seenLayerIds = <String>{};
    for (var i = 0; i < config.layers.length; i++) {
      final layerId = config.layers[i].id;
      if (layerId.isNotEmpty && !seenLayerIds.add(layerId)) {
        issues.add(
          ConfigValidationIssue(
            path: 'layers[$i].id',
            message: 'layer id "$layerId" must be unique.',
          ),
        );
      }
    }
  }

  void _validateLayer(
    LayerConfig layer,
    int layerIndex,
    List<ConfigValidationIssue> issues,
  ) {
    final layerPath = 'layers[$layerIndex]';

    if (layer.id.trim().isEmpty) {
      issues.add(
        ConfigValidationIssue(
          path: '$layerPath.id',
          message: 'layer id is required.',
        ),
      );
    }

    if (layer.gain < 0.0) {
      issues.add(
        ConfigValidationIssue(
          path: '$layerPath.gain',
          message: 'gain must be >= 0.',
        ),
      );
    }

    if (layer.pan < -1.0 || layer.pan > 1.0) {
      issues.add(
        ConfigValidationIssue(
          path: '$layerPath.pan',
          message: 'pan must be in [-1, 1].',
        ),
      );
    }

    _validateSource(layer.source, '$layerPath.source', issues);

    final seenProcessorIds = <String>{};
    for (var i = 0; i < layer.processors.length; i++) {
      final processor = layer.processors[i];
      final processorPath = '$layerPath.processors[$i]';

      if (processor.id.trim().isEmpty) {
        issues.add(
          ConfigValidationIssue(
            path: '$processorPath.id',
            message: 'processor id is required.',
          ),
        );
      } else if (!seenProcessorIds.add(processor.id)) {
        issues.add(
          ConfigValidationIssue(
            path: '$processorPath.id',
            message: 'processor id "${processor.id}" must be unique inside a layer.',
          ),
        );
      }

      _validateProcessor(processor, processorPath, issues);
    }

    final seenModulationIds = <String>{};
    for (var i = 0; i < layer.modulations.length; i++) {
      final modulation = layer.modulations[i];
      final modulationPath = '$layerPath.modulations[$i]';

      if (modulation.id.trim().isEmpty) {
        issues.add(
          ConfigValidationIssue(
            path: '$modulationPath.id',
            message: 'modulation id is required.',
          ),
        );
      } else if (!seenModulationIds.add(modulation.id)) {
        issues.add(
          ConfigValidationIssue(
            path: '$modulationPath.id',
            message: 'modulation id "${modulation.id}" must be unique inside a layer.',
          ),
        );
      }

      _validateModulation(modulation, modulationPath, issues);
    }

    for (var i = 0; i < layer.events.length; i++) {
      final event = layer.events[i];
      final eventPath = '$layerPath.events[$i]';

      if (event.id.trim().isEmpty) {
        issues.add(
          ConfigValidationIssue(
            path: '$eventPath.id',
            message: 'event id is required.',
          ),
        );
      }

      if (event.trigger.rate <= 0.0) {
        issues.add(
          ConfigValidationIssue(
            path: '$eventPath.trigger.rate',
            message: 'trigger rate must be > 0.',
          ),
        );
      }

      if (event.actions.isEmpty) {
        issues.add(
          ConfigValidationIssue(
            path: '$eventPath.actions',
            message: 'at least one action is required.',
          ),
        );
      }

      for (var actionIndex = 0; actionIndex < event.actions.length; actionIndex++) {
        final action = event.actions[actionIndex];
        if (action.modulatorId.trim().isEmpty) {
          issues.add(
            ConfigValidationIssue(
              path: '$eventPath.actions[$actionIndex].modulatorId',
              message: 'modulatorId is required.',
            ),
          );
        }
      }
    }
  }

  void _validateSource(
    SourceConfig source,
    String path,
    List<ConfigValidationIssue> issues,
  ) {
    switch (source.type) {
      case SourceType.noise:
        if (source.noiseConfig == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.noiseConfig',
              message: 'noiseConfig is required for source type noise.',
            ),
          );
          return;
        }

        if (source.noiseConfig!.band.low < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.noiseConfig.band.low',
              message: 'band.low must be >= 0.',
            ),
          );
        }

        if (source.noiseConfig!.band.high <= source.noiseConfig!.band.low) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.noiseConfig.band.high',
              message: 'band.high must be > band.low.',
            ),
          );
        }
      case SourceType.impulse:
        if (source.impulseConfig == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.impulseConfig',
              message: 'impulseConfig is required for source type impulse.',
            ),
          );
          return;
        }

        if (source.impulseConfig!.density < 0.0 || source.impulseConfig!.density > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.impulseConfig.density',
              message: 'density must be in [0, 1].',
            ),
          );
        }

        if (source.impulseConfig!.randomness < 0.0 || source.impulseConfig!.randomness > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.impulseConfig.randomness',
              message: 'randomness must be in [0, 1].',
            ),
          );
        }
      case SourceType.sine:
        if (source.sineConfig == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.sineConfig',
              message: 'sineConfig is required for source type sine.',
            ),
          );
          return;
        }

        if (source.sineConfig!.frequencyHz <= 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.sineConfig.frequencyHz',
              message: 'frequencyHz must be > 0.',
            ),
          );
        }
    }
  }

  void _validateProcessor(
    ProcessorConfig processor,
    String path,
    List<ConfigValidationIssue> issues,
  ) {
    switch (processor.type) {
      case ProcessorType.biquad:
        final biquad = processor.biquad;
        if (biquad == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.biquad',
              message: 'biquad config is required for processor type biquad.',
            ),
          );
          return;
        }

        if (biquad.frequency <= 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.biquad.frequency',
              message: 'frequency must be > 0.',
            ),
          );
        }

        if (biquad.q <= 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.biquad.q',
              message: 'q must be > 0.',
            ),
          );
        }
      case ProcessorType.gain:
        final gain = processor.gain;
        if (gain == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.gain',
              message: 'gain config is required for processor type gain.',
            ),
          );
          return;
        }

        if (!gain.gain.isFinite) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.gain.gain',
              message: 'gain must be finite.',
            ),
          );
        }
      case ProcessorType.saturator:
        final saturator = processor.saturator;
        if (saturator == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.saturator',
              message: 'saturator config is required for processor type saturator.',
            ),
          );
          return;
        }

        if (saturator.drive < 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.saturator.drive',
              message: 'drive must be >= 0.',
            ),
          );
        }
      case ProcessorType.delay:
        final delay = processor.delay;
        if (delay == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.delay',
              message: 'delay config is required for processor type delay.',
            ),
          );
          return;
        }

        if (delay.delayTimeMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.delay.delayTimeMs',
              message: 'delayTimeMs must be >= 0.',
            ),
          );
        }

        if (delay.feedback < 0.0 || delay.feedback > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.delay.feedback',
              message: 'feedback must be in [0, 1].',
            ),
          );
        }

        if (delay.mix < 0.0 || delay.mix > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.delay.mix',
              message: 'mix must be in [0, 1].',
            ),
          );
        }
    }
  }

  void _validateModulation(
    ModulationConfig modulation,
    String path,
    List<ConfigValidationIssue> issues,
  ) {
    if (!modulation.amount.isFinite) {
      issues.add(
        ConfigValidationIssue(
          path: '$path.amount',
          message: 'amount must be finite.',
        ),
      );
    }

    if (modulation.targets.isEmpty) {
      issues.add(
        ConfigValidationIssue(
          path: '$path.targets',
          message: 'at least one modulation target is required.',
        ),
      );
    }

    for (var i = 0; i < modulation.targets.length; i++) {
      final target = modulation.targets[i];
      if (target.path.trim().isEmpty) {
        issues.add(
          ConfigValidationIssue(
            path: '$path.targets[$i].path',
            message: 'target path is required.',
          ),
        );
      }

      if (!target.amount.isFinite) {
        issues.add(
          ConfigValidationIssue(
            path: '$path.targets[$i].amount',
            message: 'target amount must be finite.',
          ),
        );
      }

      if (target.minValue != null && !target.minValue!.isFinite) {
        issues.add(
          ConfigValidationIssue(
            path: '$path.targets[$i].minValue',
            message: 'minValue must be finite when provided.',
          ),
        );
      }

      if (target.maxValue != null && !target.maxValue!.isFinite) {
        issues.add(
          ConfigValidationIssue(
            path: '$path.targets[$i].maxValue',
            message: 'maxValue must be finite when provided.',
          ),
        );
      }

      if (target.minValue != null && target.maxValue != null && target.minValue! > target.maxValue!) {
        issues.add(
          ConfigValidationIssue(
            path: '$path.targets[$i]',
            message: 'minValue must be <= maxValue.',
          ),
        );
      }
    }

    switch (modulation.type) {
      case ModulationType.lfo:
        final lfo = modulation.lfoConfig;
        if (lfo == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.lfoConfig',
              message: 'lfoConfig is required for modulation type lfo.',
            ),
          );
          return;
        }
        if (lfo.frequency <= 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.lfoConfig.frequency',
              message: 'frequency must be > 0.',
            ),
          );
        }
        if (lfo.depth < 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.lfoConfig.depth',
              message: 'depth must be >= 0.',
            ),
          );
        }
      case ModulationType.random:
        final random = modulation.randomConfig;
        if (random == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.randomConfig',
              message: 'randomConfig is required for modulation type random.',
            ),
          );
          return;
        }
        if (random.rateHz <= 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.randomConfig.rateHz',
              message: 'rateHz must be > 0.',
            ),
          );
        }
        if (random.smooth < 0.0 || random.smooth > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.randomConfig.smooth',
              message: 'smooth must be in [0, 1].',
            ),
          );
        }
      case ModulationType.drift:
        final drift = modulation.driftConfig;
        if (drift == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.driftConfig',
              message: 'driftConfig is required for modulation type drift.',
            ),
          );
          return;
        }
        if (drift.speed < 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.driftConfig.speed',
              message: 'speed must be >= 0.',
            ),
          );
        }
        if (drift.range < 0.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.driftConfig.range',
              message: 'range must be >= 0.',
            ),
          );
        }
      case ModulationType.envelope:
        final envelope = modulation.envelopeConfig;
        if (envelope == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.envelopeConfig',
              message: 'envelopeConfig is required for modulation type envelope.',
            ),
          );
          return;
        }
        if (envelope.attackMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.envelopeConfig.attackMs',
              message: 'attackMs must be >= 0.',
            ),
          );
        }
        if (envelope.decayMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.envelopeConfig.decayMs',
              message: 'decayMs must be >= 0.',
            ),
          );
        }
        if (envelope.releaseMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.envelopeConfig.releaseMs',
              message: 'releaseMs must be >= 0.',
            ),
          );
        }
        if (envelope.sustain < 0.0 || envelope.sustain > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.envelopeConfig.sustain',
              message: 'sustain must be in [0, 1].',
            ),
          );
        }
      case ModulationType.burst:
        final burst = modulation.burstConfig;
        if (burst == null) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig',
              message: 'burstConfig is required for modulation type burst.',
            ),
          );
          return;
        }
        if (burst.durationMs <= 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.durationMs',
              message: 'durationMs must be > 0.',
            ),
          );
        }
        if (burst.intensity < 0.0 || burst.intensity > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.intensity',
              message: 'intensity must be in [0, 1].',
            ),
          );
        }
        if (burst.randomness < 0.0 || burst.randomness > 1.0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.randomness',
              message: 'randomness must be in [0, 1].',
            ),
          );
        }
        if (burst.attackMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.attackMs',
              message: 'attackMs must be >= 0.',
            ),
          );
        }
        if (burst.releaseMs <= 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.releaseMs',
              message: 'releaseMs must be > 0.',
            ),
          );
        }
        if (burst.clusterMin <= 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.clusterMin',
              message: 'clusterMin must be > 0.',
            ),
          );
        }
        if (burst.clusterMax < burst.clusterMin) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.clusterMax',
              message: 'clusterMax must be >= clusterMin.',
            ),
          );
        }
        if (burst.clusterSpreadMs < 0) {
          issues.add(
            ConfigValidationIssue(
              path: '$path.burstConfig.clusterSpreadMs',
              message: 'clusterSpreadMs must be >= 0.',
            ),
          );
        }
    }
  }

  void _validateLayerCrossReferences(
    LayerConfig layer,
    int layerIndex,
    Set<String> validTargetPaths,
    List<ConfigValidationIssue> issues,
  ) {
    final layerPath = 'layers[$layerIndex]';
    final modulatorIds = layer.modulations.map((modulation) => modulation.id).toSet();

    for (var i = 0; i < layer.events.length; i++) {
      final event = layer.events[i];
      for (var j = 0; j < event.actions.length; j++) {
        final action = event.actions[j];
        if (action.modulatorId.isEmpty) {
          continue;
        }
        if (!modulatorIds.contains(action.modulatorId)) {
          issues.add(
            ConfigValidationIssue(
              path: '$layerPath.events[$i].actions[$j].modulatorId',
              message: 'modulator id "${action.modulatorId}" does not exist in layer modulations.',
            ),
          );
        }
      }
    }

    for (var i = 0; i < layer.modulations.length; i++) {
      final modulation = layer.modulations[i];
      for (var j = 0; j < modulation.targets.length; j++) {
        final target = modulation.targets[j];
        if (target.path.isEmpty) {
          continue;
        }
        if (!validTargetPaths.contains(target.path)) {
          issues.add(
            ConfigValidationIssue(
              path: '$layerPath.modulations[$i].targets[$j].path',
              message: 'unknown modulation target path "${target.path}".',
            ),
          );
        }
      }
    }
  }

  Set<String> _buildLayerTargetPaths(LayerConfig layer) {
    final paths = <String>{
      'layers[${layer.id}].gain',
      'layers[${layer.id}].pan',
      'layers[${layer.id}].source.noise.band.low',
      'layers[${layer.id}].source.noise.band.high',
      'layers[${layer.id}].source.sine.frequencyHz',
      'layers[${layer.id}].source.sine.phase',
      'layers[${layer.id}].source.impulse.density',
      'layers[${layer.id}].source.impulse.randomness',
    };

    for (final processor in layer.processors) {
      paths.addAll({
        'layers[${layer.id}].processors[${processor.id}].biquad.frequency',
        'layers[${layer.id}].processors[${processor.id}].biquad.q',
        'layers[${layer.id}].processors[${processor.id}].biquad.gainDb',
        'layers[${layer.id}].processors[${processor.id}].gain.gain',
        'layers[${layer.id}].processors[${processor.id}].saturator.drive',
        'layers[${layer.id}].processors[${processor.id}].delay.delayTimeMs',
        'layers[${layer.id}].processors[${processor.id}].delay.feedback',
        'layers[${layer.id}].processors[${processor.id}].delay.mix',
      });
    }

    return paths;
  }
}
