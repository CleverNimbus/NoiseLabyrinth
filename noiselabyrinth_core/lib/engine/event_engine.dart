import 'dart:math' as math;

import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class RuntimeEventAction {
  final ActionMode mode;
  final RuntimeModulationBinding modulation;

  const RuntimeEventAction({required this.mode, required this.modulation});
}

class RuntimeEventBinding {
  final String id;
  final TriggerType type;
  final double rate;
  final List<RuntimeEventAction> actions;

  const RuntimeEventBinding({
    required this.id,
    required this.type,
    required this.rate,
    required this.actions,
  });
}

class EventScheduler {
  final List<RuntimeEventBinding> events;
  final int sampleRate;
  final int blockSize;

  final int _seed;
  int _rngState;
  double _timeSeconds = 0.0;

  final Map<String, double> _periodicAccumulators = <String, double>{};
  final Map<String, double> _nextPoissonTimes = <String, double>{};

  EventScheduler({
    required this.events,
    required this.sampleRate,
    required this.blockSize,
    int seed = 0x514E1D5B,
  }) : _seed = seed,
       _rngState = seed;

  double get currentTimeSeconds => _timeSeconds;

  List<String> processBlock() {
    if (events.isEmpty || sampleRate <= 0 || blockSize <= 0) {
      return const <String>[];
    }

    final triggeredIds = <String>[];
    final dt = blockSize / sampleRate;
    final endTime = _timeSeconds + dt;

    for (final event in events) {
      final rate = event.rate <= 0.0 ? 0.0 : event.rate;
      if (rate == 0.0) {
        continue;
      }

      switch (event.type) {
        case TriggerType.periodic:
          var accumulator = _periodicAccumulators[event.id] ?? 0.0;
          accumulator += rate * dt;
          while (accumulator >= 1.0) {
            _triggerEvent(event);
            triggeredIds.add(event.id);
            accumulator -= 1.0;
          }
          _periodicAccumulators[event.id] = accumulator;
          break;
        case TriggerType.poisson:
          var nextTime =
              _nextPoissonTimes[event.id] ??
              (_timeSeconds + _sampleExponentialInterval(rate));
          while (nextTime <= endTime) {
            _triggerEvent(event);
            triggeredIds.add(event.id);
            nextTime += _sampleExponentialInterval(rate);
          }
          _nextPoissonTimes[event.id] = nextTime;
          break;
        case TriggerType.random:
          final expectedEvents = rate * dt;
          final wholeEvents = expectedEvents.floor();
          final remainder = expectedEvents - wholeEvents;

          for (var n = 0; n < wholeEvents; n++) {
            _triggerEvent(event);
            triggeredIds.add(event.id);
          }

          if (_nextUnit01() < remainder) {
            _triggerEvent(event);
            triggeredIds.add(event.id);
          }
          break;
      }
    }

    _timeSeconds = endTime;
    return triggeredIds;
  }

  void reset() {
    _timeSeconds = 0.0;
    _periodicAccumulators.clear();
    _nextPoissonTimes.clear();
    _rngState = _seed;
  }

  void _triggerEvent(RuntimeEventBinding event) {
    for (final action in event.actions) {
      switch (action.mode) {
        case ActionMode.trigger:
          action.modulation.modulator.trigger();
          break;
        case ActionMode.gate:
          // Gate action currently maps to reset semantics.
          action.modulation.modulator.reset();
          break;
      }
    }
  }

  double _sampleExponentialInterval(double rate) {
    final u = _nextUnit01().clamp(1e-12, 1.0 - 1e-12);
    return -math.log(1.0 - u) / rate;
  }

  double _nextUnit01() {
    _rngState = _xorshift32(_rngState);
    return (_rngState & 0x7FFFFFFF) / 2147483647.0;
  }

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
  }
}
