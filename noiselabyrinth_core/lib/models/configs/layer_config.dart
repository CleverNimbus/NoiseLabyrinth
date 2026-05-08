import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';

/// Audio layer configuration.
class LayerConfig {
  LayerConfig({
    required this.id,
    required this.source,
    this.gain = 1.0,
    this.pan = 0.0,
    this.processors = const [],
    this.modulations = const [],
    this.events = const [],
  });

  factory LayerConfig.fromJson(Map<String, dynamic> json) {
    return LayerConfig(
      id: json['id'] as String? ?? '',
      gain: (json['gain'] as num?)?.toDouble() ?? 1.0,
      pan: (json['pan'] as num?)?.toDouble() ?? 0.0,
      source: SourceConfig.fromJson(
        json['source'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      processors:
          (json['processors'] as List<dynamic>?)
              ?.map((e) => ProcessorConfig.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <ProcessorConfig>[],
      modulations:
          (json['modulations'] as List<dynamic>?)
              ?.map((e) => ModulationConfig.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <ModulationConfig>[],
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => EventConfig.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <EventConfig>[],
    );
  }

  /// Unique identifier of the layer within the generation.
  String id;

  /// Linear gain multiplier applied to the layer output.
  double gain;

  /// Pan position of the layer in the stereo field, where -1 is full left, 0 is center, and 1 is full right.
  double pan;

  /// Primary source definition that generates the layer signal.
  SourceConfig source;

  /// Ordered list of processors applied to the layer signal chain.
  List<ProcessorConfig> processors;

  /// Modulators available in this layer to animate parameters over time.
  List<ModulationConfig> modulations;

  /// Event triggers that can activate or gate modulators.
  List<EventConfig> events;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gain': gain,
      'pan': pan,
      'source': source.toJson(),
      'processors': processors.map((e) => e.toJson()).toList(),
      'modulations': modulations.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
    };
  }
}
