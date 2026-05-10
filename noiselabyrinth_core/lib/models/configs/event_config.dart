import 'package:noiselabyrinth_core/models/enums.dart';

/// Event trigger and action definition for a layer.
class EventConfig {
  EventConfig({
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

  /// Unique identifier of the event definition within a layer.
  String id;

  /// Trigger definition controlling when event actions execute.
  TriggerConfig trigger;

  /// Actions executed when the trigger fires.
  List<ActionConfig> actions;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trigger': trigger.toJson(),
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }
}

/// Trigger configuration for an event.
class TriggerConfig {
  TriggerConfig({this.type = TriggerType.periodic, this.rate = 0.2});

  factory TriggerConfig.fromJson(Map<String, dynamic> json) {
    return TriggerConfig(
      type: TriggerType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => TriggerType.periodic,
      ),
      rate: (json['rate'] as num?)?.toDouble() ?? 0.2,
    );
  }

  /// Trigger behavior type.
  TriggerType type;

  /// Trigger rate in Hz or equivalent cadence units, depending on type.
  double rate;

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'rate': rate};
  }
}

/// Action configuration for an event trigger.
class ActionConfig {
  ActionConfig({
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

  /// Identifier of the modulation source affected by this action.
  String modulatorId;

  /// Action mode describing how the modulator is controlled.
  ActionMode mode;

  Map<String, dynamic> toJson() {
    return {
      'modulatorId': modulatorId,
      'mode': mode.toString().split('.').last,
    };
  }
}
