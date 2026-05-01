import 'package:flutter_test/flutter_test.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
  group('parameter models', () {
    test('Parameter applies modulation per block and resets accumulator', () {
      final parameter = Parameter(0.5);
      expect(parameter.finalValue, 0.5);

      parameter.modulationValue = 0.25;
      parameter.update();
      expect(parameter.finalValue, closeTo(0.75, 1e-9));
      expect(parameter.modulationValue, 0.0);
    });

    test('SmoothedParameter clamps smoothing and interpolates', () {
      final smoothed = SmoothedParameter(0.0, 2.0);
      smoothed.target = 1.0;
      smoothed.update();

      expect(smoothed.smoothing, 1.0);
      expect(smoothed.current, closeTo(1.0, 1e-9));
    });
  });
}
