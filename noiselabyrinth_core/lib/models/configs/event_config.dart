import 'package:noiselabyrinth_core/models/enums.dart';

class EventConfig {
  final String id;
  final TriggerConfig trigger;
  final List<ActionConfig> actions;

  const EventConfig({
    required this.id,
    required this.trigger,
    required this.actions,
  });

  factory EventConfig.fromJson(Map<String, dynamic> json) {
    return EventConfig(
      id: json['id'] as String? ?? '',
      trigger: TriggerConfig.fromJson(
        json['trigger'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map((e) => ActionConfig.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const <ActionConfig>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trigger': trigger.toJson(),
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }
}

class TriggerConfig {
  final TriggerType type;
  final double rate; // For periodic triggers

  const TriggerConfig({this.type = TriggerType.periodic, this.rate = 0.2});

  factory TriggerConfig.fromJson(Map<String, dynamic> json) {
    return TriggerConfig(
      type: TriggerType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => TriggerType.periodic,
      ),
      rate: (json['rate'] as num?)?.toDouble() ?? 0.2,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'rate': rate};
  }
}

class ActionConfig {
  final String modulatorId;
  final ActionMode mode;

  const ActionConfig({
    required this.modulatorId,
    this.mode = ActionMode.trigger,
  });

  factory ActionConfig.fromJson(Map<String, dynamic> json) {
    return ActionConfig(
      modulatorId: json['modulatorId'] as String? ?? '',
      mode: ActionMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => ActionMode.trigger,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modulatorId': modulatorId,
      'mode': mode.toString().split('.').last,
    };
  }
}
