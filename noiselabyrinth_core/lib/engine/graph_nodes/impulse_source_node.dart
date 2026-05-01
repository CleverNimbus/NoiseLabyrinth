import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';

class ImpulseSourceNode extends SourceNode {
  ImpulseSourceNode({
    required super.id,
    required double density,
    required double randomness,
    int seed = 0,
  }) : _rngState = 1,
       super(
         parameters: <String, Parameter>{
           'density': Parameter(density),
           'randomness': Parameter(randomness),
         },
       ) {
    _rngState = _nonZeroSeed(seed, id);
  }
  int _rngState;

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final density = parameter('density')!.finalValue.clamp(0.0, 1.0);
    final randomness = parameter(
      'randomness',
    )!.finalValue.clamp(0.0, 1.0);

    var state = _rngState;
    for (var i = 0; i < buffer.length; i++) {
      state = nextXorshift32(state);
      final trigger = _stateToUnit01(state) < density;
      if (!trigger) {
        buffer[i] = 0.0;
        continue;
      }

      state = nextXorshift32(state);
      final amplitudeJitter = _stateToUnit01(state) * randomness;
      final amplitude = 1.0 - amplitudeJitter;
      buffer[i] = amplitude;
    }

    _rngState = state;
  }

  static double _stateToUnit01(int state) {
    return (state & 0x7FFFFFFF) / 2147483647.0;
  }

  static int _nonZeroSeed(int seed, String id) {
    if (seed != 0) {
      return seed & 0xFFFFFFFF;
    }

    var hash = 2166136261;
    for (final codeUnit in id.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }

    return hash == 0 ? 0x9E3779B9 : hash;
  }
}
