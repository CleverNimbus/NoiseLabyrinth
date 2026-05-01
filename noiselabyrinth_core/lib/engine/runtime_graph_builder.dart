import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/engine/event_engine.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/biquad_processor_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/delay_processor_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/gain_processor_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/impulse_source_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/noise_source_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/saturator_processor_node.dart';
import 'package:noiselabyrinth_core/engine/graph_nodes/sine_source_node.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

class LayerRuntime {
  const LayerRuntime({
    required this.id,
    required this.gain,
    required this.pan,
    required this.source,
    required this.processors,
    required this.outputNodeId,
    required this.resolvedModulationTargets,
    required this.modulationBindings,
    required this.eventBindings,
  });
  final String id;
  final Parameter gain;
  final Parameter pan;
  final SourceNode source;
  final List<ProcessorNode> processors;
  final String outputNodeId;
  final List<ResolvedModulationTarget> resolvedModulationTargets;
  final List<RuntimeModulationBinding> modulationBindings;
  final List<RuntimeEventBinding> eventBindings;
}

class ResolvedParameterReference {
  const ResolvedParameterReference({
    required this.nodeId,
    required this.parameterName,
    required this.parameter,
  });
  final String nodeId;
  final String parameterName;
  final Parameter parameter;
}

class ResolvedModulationTarget {
  const ResolvedModulationTarget({
    required this.modulationId,
    required this.targetPath,
    required this.amount,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.reference,
  });
  final String modulationId;
  final String targetPath;
  final double amount;
  final ModulationApplyMode mode;
  final double? minValue;
  final double? maxValue;
  final ResolvedParameterReference reference;
}

class ParameterRegistry {
  final Map<String, ResolvedParameterReference> _byNodeAndParameter = <String, ResolvedParameterReference>{};
  final Map<String, ResolvedParameterReference> _byPath = <String, ResolvedParameterReference>{};

  void register(
    String nodeId,
    String parameterName,
    Parameter parameter, {
    List<String> pathAliases = const <String>[],
  }) {
    final reference = ResolvedParameterReference(
      nodeId: nodeId,
      parameterName: parameterName,
      parameter: parameter,
    );

    _byNodeAndParameter[_key(nodeId, parameterName)] = reference;

    for (final alias in pathAliases) {
      _byPath[alias] = reference;
    }
  }

  ResolvedParameterReference? resolveNodeParameter(
    String nodeId,
    String parameterName,
  ) {
    return _byNodeAndParameter[_key(nodeId, parameterName)];
  }

  ResolvedParameterReference? resolvePath(String path) => _byPath[path];

  static String _key(String nodeId, String parameterName) => '$nodeId::$parameterName';
}

class RuntimeGraph {
  const RuntimeGraph({
    required this.config,
    required this.masterMix,
    required this.layers,
    required this.nodesById,
    required this.parameters,
  });
  final GenerationConfig config;
  final Parameter masterMix;
  final List<LayerRuntime> layers;
  final Map<String, AudioNode> nodesById;
  final ParameterRegistry parameters;

  ResolvedParameterReference? resolveNodeParameter(
    String nodeId,
    String parameterName,
  ) {
    return parameters.resolveNodeParameter(nodeId, parameterName);
  }

  ResolvedParameterReference? resolvePath(String path) {
    return parameters.resolvePath(path);
  }
}

class NodeFactory {
  static SourceNode createSource(SourceConfig config) {
    switch (config.type) {
      case SourceType.noise:
        final noise = config.noiseConfig;
        if (noise == null) {
          throw StateError('noiseConfig is required for noise source.');
        }

        return NoiseSourceNode(
          id: 'source',
          color: noise.color,
          low: noise.band.low,
          high: noise.band.high,
        );
      case SourceType.impulse:
        final impulse = config.impulseConfig;
        if (impulse == null) {
          throw StateError('impulseConfig is required for impulse source.');
        }

        return ImpulseSourceNode(
          id: 'source',
          density: impulse.density,
          randomness: impulse.randomness,
        );
      case SourceType.sine:
        final sine = config.sineConfig;
        if (sine == null) {
          throw StateError('sineConfig is required for sine source.');
        }

        return SineSourceNode(
          id: 'source',
          frequencyHz: sine.frequencyHz,
          phase: sine.phase,
        );
    }
  }

  static ProcessorNode createProcessor(ProcessorConfig config) {
    switch (config.type) {
      case ProcessorType.biquad:
        final biquad = config.biquad;
        if (biquad == null) {
          throw StateError('biquad config is required for biquad processor.');
        }

        return BiquadProcessorNode(
          id: config.id,
          mode: biquad.biquadMode,
          frequency: biquad.frequency,
          q: biquad.q,
          gainDb: biquad.gainDb,
          resonant: biquad.resonant,
        );
      case ProcessorType.gain:
        final gain = config.gain;
        if (gain == null) {
          throw StateError('gain config is required for gain processor.');
        }

        return GainProcessorNode(id: config.id, gain: gain.gain);
      case ProcessorType.saturator:
        final saturator = config.saturator;
        if (saturator == null) {
          throw StateError(
            'saturator config is required for saturator processor.',
          );
        }

        return SaturatorProcessorNode(
          id: config.id,
          curve: saturator.curve,
          drive: saturator.drive,
        );
      case ProcessorType.delay:
        final delay = config.delay;
        if (delay == null) {
          throw StateError('delay config is required for delay processor.');
        }

        return DelayProcessorNode(
          id: config.id,
          delayTimeMs: delay.delayTimeMs,
          feedback: delay.feedback,
          mix: delay.mix,
        );
    }
  }
}

class RuntimeGraphBuilder {
  const RuntimeGraphBuilder({this.sampleRate = 44100});
  final int sampleRate;

  int get _sampleRate => sampleRate <= 0 ? 44100 : sampleRate;

  RuntimeGraph build(GenerationConfig config) {
    final masterMix = Parameter(config.mix.mix);
    final layers = <LayerRuntime>[];
    final nodesById = <String, AudioNode>{};
    final registry = ParameterRegistry();

    for (final layerConfig in config.layers) {
      final layer = _buildLayer(layerConfig, nodesById, registry);
      layers.add(layer);
    }

    return RuntimeGraph(
      config: config,
      masterMix: masterMix,
      layers: List<LayerRuntime>.unmodifiable(layers),
      nodesById: Map<String, AudioNode>.unmodifiable(nodesById),
      parameters: registry,
    );
  }

  LayerRuntime _buildLayer(
    LayerConfig config,
    Map<String, AudioNode> nodesById,
    ParameterRegistry registry,
  ) {
    final layerGain = Parameter(config.gain);
    final layerPan = Parameter(config.pan);
    registry
      ..register(
        config.id,
        'gain',
        layerGain,
        pathAliases: <String>['layers[${config.id}].gain'],
      )
      ..register(
        config.id,
        'pan',
        layerPan,
        pathAliases: <String>['layers[${config.id}].pan'],
      );

    final source = NodeFactory.createSource(config.source)..id = '${config.id}.source';
    _registerSourceParameters(config.id, source, registry);
    nodesById[source.id] = source;

    final processors = <ProcessorNode>[];
    var previousNodeId = source.id;
    for (final processorConfig in config.processors) {
      final processor = NodeFactory.createProcessor(processorConfig)
        ..id = '${config.id}.${processorConfig.id}'
        ..inputNodeId = previousNodeId;
      previousNodeId = processor.id;
      _registerProcessorParameters(
        config.id,
        processorConfig.id,
        processor,
        registry,
      );
      nodesById[processor.id] = processor;
      processors.add(processor);
    }

    final resolvedTargets = _resolveModulationTargets(
      config.modulations,
      registry,
    );
    final modulationBindings = _buildModulationBindings(
      config.modulations,
      resolvedTargets,
    );
    final eventBindings = _buildEventBindings(
      config.events,
      modulationBindings,
    );

    return LayerRuntime(
      id: config.id,
      gain: layerGain,
      pan: layerPan,
      source: source,
      processors: List<ProcessorNode>.unmodifiable(processors),
      outputNodeId: previousNodeId,
      resolvedModulationTargets: List<ResolvedModulationTarget>.unmodifiable(
        resolvedTargets,
      ),
      modulationBindings: List<RuntimeModulationBinding>.unmodifiable(
        modulationBindings,
      ),
      eventBindings: List<RuntimeEventBinding>.unmodifiable(eventBindings),
    );
  }

  List<RuntimeEventBinding> _buildEventBindings(
    List<EventConfig> events,
    List<RuntimeModulationBinding> modulationBindings,
  ) {
    if (events.isEmpty) {
      return const <RuntimeEventBinding>[];
    }

    final modulationById = <String, RuntimeModulationBinding>{
      for (final modulation in modulationBindings) modulation.id: modulation,
    };

    final bindings = <RuntimeEventBinding>[];
    for (final event in events) {
      final actions = <RuntimeEventAction>[];
      for (final action in event.actions) {
        final modulation = modulationById[action.modulatorId];
        if (modulation == null) {
          throw StateError(
            'Unable to resolve event action modulator ${action.modulatorId}.',
          );
        }

        actions.add(
          RuntimeEventAction(mode: action.mode, modulation: modulation),
        );
      }

      bindings.add(
        RuntimeEventBinding(
          id: event.id,
          type: event.trigger.type,
          rate: event.trigger.rate,
          actions: List<RuntimeEventAction>.unmodifiable(actions),
        ),
      );
    }

    return bindings;
  }

  List<RuntimeModulationBinding> _buildModulationBindings(
    List<ModulationConfig> modulations,
    List<ResolvedModulationTarget> resolvedTargets,
  ) {
    final byId = <String, List<ResolvedModulationTarget>>{};
    for (final target in resolvedTargets) {
      byId.putIfAbsent(target.modulationId, () => <ResolvedModulationTarget>[]).add(target);
    }

    final bindings = <RuntimeModulationBinding>[];
    for (final modulation in modulations) {
      final targetsForMod = byId[modulation.id] ?? const <ResolvedModulationTarget>[];
      if (targetsForMod.isEmpty) {
        continue;
      }

      final modulator = ModulatorFactory.create(modulation, _sampleRate);
      final targetBindings = targetsForMod
          .map(
            (target) => ModulationTargetBinding(
              parameter: target.reference.parameter,
              amount: target.amount,
              mode: target.mode,
              minValue: target.minValue,
              maxValue: target.maxValue,
            ),
          )
          .toList(growable: false);

      bindings.add(
        RuntimeModulationBinding(
          id: modulation.id,
          modulator: modulator,
          amount: modulation.amount,
          targets: targetBindings,
        ),
      );
    }

    return bindings;
  }

  List<ResolvedModulationTarget> _resolveModulationTargets(
    List<ModulationConfig> modulations,
    ParameterRegistry registry,
  ) {
    final targets = <ResolvedModulationTarget>[];

    for (final modulation in modulations) {
      for (final target in modulation.targets) {
        final reference = registry.resolvePath(target.path);
        if (reference == null) {
          throw StateError(
            'Unable to resolve modulation target path ${target.path}.',
          );
        }

        targets.add(
          ResolvedModulationTarget(
            modulationId: modulation.id,
            targetPath: target.path,
            amount: target.amount,
            mode: target.mode,
            minValue: target.minValue,
            maxValue: target.maxValue,
            reference: reference,
          ),
        );
      }
    }

    return targets;
  }

  void _registerSourceParameters(
    String layerId,
    SourceNode source,
    ParameterRegistry registry,
  ) {
    final nodeId = source.id;

    if (source is NoiseSourceNode) {
      registry
        ..register(
          nodeId,
          'bandLow',
          source.parameters['bandLow']!,
          pathAliases: <String>['layers[$layerId].source.noise.band.low'],
        )
        ..register(
          nodeId,
          'bandHigh',
          source.parameters['bandHigh']!,
          pathAliases: <String>['layers[$layerId].source.noise.band.high'],
        );
      return;
    }

    if (source is SineSourceNode) {
      registry
        ..register(
          nodeId,
          'frequencyHz',
          source.parameters['frequencyHz']!,
          pathAliases: <String>['layers[$layerId].source.sine.frequencyHz'],
        )
        ..register(
          nodeId,
          'phase',
          source.parameters['phase']!,
          pathAliases: <String>['layers[$layerId].source.sine.phase'],
        );
      return;
    }

    if (source is ImpulseSourceNode) {
      registry
        ..register(
          nodeId,
          'density',
          source.parameters['density']!,
          pathAliases: <String>['layers[$layerId].source.impulse.density'],
        )
        ..register(
          nodeId,
          'randomness',
          source.parameters['randomness']!,
          pathAliases: <String>['layers[$layerId].source.impulse.randomness'],
        );
    }
  }

  void _registerProcessorParameters(
    String layerId,
    String processorId,
    ProcessorNode processor,
    ParameterRegistry registry,
  ) {
    final nodeId = processor.id;

    if (processor is BiquadProcessorNode) {
      registry
        ..register(
          nodeId,
          'frequency',
          processor.parameters['frequency']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].biquad.frequency',
          ],
        )
        ..register(
          nodeId,
          'q',
          processor.parameters['q']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].biquad.q',
          ],
        )
        ..register(
          nodeId,
          'gainDb',
          processor.parameters['gainDb']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].biquad.gainDb',
          ],
        );
      return;
    }

    if (processor is GainProcessorNode) {
      registry.register(
        nodeId,
        'gain',
        processor.parameters['gain']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].gain.gain',
        ],
      );
      return;
    }

    if (processor is SaturatorProcessorNode) {
      registry.register(
        nodeId,
        'drive',
        processor.parameters['drive']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].saturator.drive',
        ],
      );
      return;
    }

    if (processor is DelayProcessorNode) {
      registry
        ..register(
          nodeId,
          'delayTimeMs',
          processor.parameters['delayTimeMs']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].delay.delayTimeMs',
          ],
        )
        ..register(
          nodeId,
          'feedback',
          processor.parameters['feedback']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].delay.feedback',
          ],
        )
        ..register(
          nodeId,
          'mix',
          processor.parameters['mix']!,
          pathAliases: <String>[
            'layers[$layerId].processors[$processorId].delay.mix',
          ],
        );
    }
  }
}
