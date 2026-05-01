import 'dart:typed_data';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class CounterModulator implements Modulator {
  int triggerCount = 0;
  int resetCount = 0;

  @override
  void process(int blockSize, Float32List buffer) {
    for (var i = 0; i < blockSize; i++) {
      buffer[i] = 0.0;
    }
  }

  @override
  void trigger() {
    triggerCount++;
  }

  @override
  void reset() {
    resetCount++;
  }
}
