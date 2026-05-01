import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';

class LayerConfig {
  final String id;
  final double gain;
  final double pan;
  final SourceConfig source;
  final List<ProcessorConfig> processors;
  final List<ModulationConfig> modulations;
  final List<EventConfig> events;

  const LayerConfig({
    required this.id,
    this.gain = 1.0,
    this.pan = 0.0,
    required this.source,
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
