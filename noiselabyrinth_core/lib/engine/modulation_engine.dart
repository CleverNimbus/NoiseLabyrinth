import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/modulators/modulator_factory.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

int nextXorshift32(int state) {
  var next = state;
  next ^= (next << 13) & 0xFFFFFFFF;
  next ^= (next >> 17) & 0xFFFFFFFF;
  next ^= (next << 5) & 0xFFFFFFFF;
  return next & 0xFFFFFFFF;
}

class ModulationEngine {
  ModulationEngine({required this.bindings});
  final List<RuntimeModulationBinding> bindings;
  Float32List _scratch = Float32List(0);

  void processBlock(int blockSize) {
    if (bindings.isEmpty || blockSize <= 0) {
      return;
    }

    if (_scratch.length != blockSize) {
      _scratch = Float32List(blockSize);
    }

    for (final binding in bindings) {
      binding.modulator.process(blockSize, _scratch);

      var sum = 0.0;
      for (var i = 0; i < blockSize; i++) {
        sum += _scratch[i];
      }
      final blockValue = sum / blockSize;

      final modulationValue = blockValue * binding.amount;
      for (final target in binding.targets) {
        _applyToTarget(target, modulationValue);
      }
    }
  }

  void _applyToTarget(ModulationTargetBinding target, double modulationValue) {
    final parameter = target.parameter;
    final scaled = modulationValue * target.amount;

    final delta = switch (target.mode) {
      ModulationApplyMode.additive => scaled,
      ModulationApplyMode.multiplicative => parameter.baseValue * scaled,
    };

    final currentFinal = parameter.baseValue + parameter.modulationValue;
    var nextFinal = currentFinal + delta;

    final minValue = target.minValue;
    final maxValue = target.maxValue;
    if (minValue != null || maxValue != null) {
      final clampMin = minValue ?? double.negativeInfinity;
      final clampMax = maxValue ?? double.infinity;
      nextFinal = nextFinal.clamp(clampMin, clampMax);
    }

    parameter.modulationValue = nextFinal - parameter.baseValue;
  }
}
