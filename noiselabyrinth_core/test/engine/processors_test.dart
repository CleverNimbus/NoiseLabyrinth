import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
  group('gain processor', () {
    test('gain processor scales buffer samples', () {
      final gain = GainProcessorNode(id: 'gain-node', gain: 0.5);
      gain.prepare(44100, 4);
      for (final parameter in gain.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List.fromList(<double>[1.0, -1.0, 0.5, -0.25]);
      gain.process(buffer);

      expect(buffer[0], closeTo(0.5, 1e-9));
      expect(buffer[1], closeTo(-0.5, 1e-9));
      expect(buffer[2], closeTo(0.25, 1e-9));
      expect(buffer[3], closeTo(-0.125, 1e-9));
    });

    test('gain processor supports negative gain for polarity inversion', () {
      final gain = GainProcessorNode(id: 'gain-invert', gain: -1.0);
      gain.prepare(44100, 3);
      for (final parameter in gain.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List.fromList(<double>[0.3, -0.5, 1.0]);
      gain.process(buffer);

      expect(buffer[0], closeTo(-0.3, 1e-6));
      expect(buffer[1], closeTo(0.5, 1e-6));
      expect(buffer[2], closeTo(-1.0, 1e-6));
    });

    test('gain processor guards against non-finite finalValue', () {
      final gain = GainProcessorNode(id: 'gain-safe', gain: 1.0);
      gain.prepare(44100, 4);

      gain.parameter('gain')!.baseValue = double.nan;
      gain.parameter('gain')!.update();

      final buffer = Float32List.fromList(<double>[1.0, -1.0, 0.5, -0.5]);
      gain.process(buffer);

      // Smoothed gain moves gradually toward the safety fallback target.
      for (final sample in buffer) {
        expect(sample.isFinite, isTrue);
        expect(sample.abs(), lessThanOrEqualTo(1.0));
      }

      for (var i = 0; i < 30; i++) {
        final decay = Float32List.fromList(<double>[1.0]);
        gain.process(decay);
      }

      final settled = Float32List.fromList(<double>[1.0]);
      gain.process(settled);
      expect(settled[0], lessThan(0.01));
    });

    test('gain processor reads finalValue and requires update cycle', () {
      final gain = GainProcessorNode(id: 'gain-cycle', gain: 1.0);
      gain.prepare(44100, 2);
      gain.parameter('gain')!.update(); // finalValue = 1.0

      gain.parameter('gain')!.baseValue = 0.25;
      final noUpdate = Float32List.fromList(<double>[1.0, 1.0]);
      gain.process(noUpdate);
      expect(noUpdate[0], closeTo(1.0, 1e-9));

      gain.parameter('gain')!.update(); // finalValue now reflects baseValue
      final updated = Float32List.fromList(<double>[1.0, 1.0]);
      gain.process(updated);
      expect(updated[0], lessThan(1.0));
      expect(updated[0], greaterThan(0.25));
    });

    test('gain smoothing eases abrupt target changes', () {
      final gain = GainProcessorNode(id: 'gain-smoothing', gain: 1.0);
      gain.prepare(44100, 1);
      gain.parameter('gain')!.update();

      final first = Float32List.fromList(<double>[1.0]);
      gain.process(first);
      expect(first[0], closeTo(1.0, 1e-9));

      gain.parameter('gain')!.baseValue = 0.0;
      gain.parameter('gain')!.update();

      final second = Float32List.fromList(<double>[1.0]);
      gain.process(second);
      expect(second[0], greaterThan(0.0));
      expect(second[0], lessThan(1.0));
      expect(gain.smoothedGain, closeTo(second[0], 1e-6));
    });
  });

  group('biquad processor', () {
    test('low-pass biquad attenuates fast alternating signal', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-lp',
        mode: BiquadMode.lowpass,
        frequency: 300,
        q: 0.707,
        gainDb: 0.0,
      );

      biquad.prepare(44100, 128);
      for (final parameter in biquad.parameters.values) {
        parameter.update();
      }

      final input = Float32List(128);
      for (var i = 0; i < input.length; i++) {
        input[i] = i.isEven ? 1.0 : -1.0;
      }

      biquad.process(input);

      var sumAbs = 0.0;
      for (final sample in input) {
        sumAbs += sample.abs();
      }
      final averageAbs = sumAbs / input.length;

      expect(averageAbs, lessThan(0.6));
      expect(biquad.coefficientUpdateCount, 1);
    });

    test('high-pass biquad attenuates DC content', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-hp',
        mode: BiquadMode.highpass,
        frequency: 600,
        q: 0.707,
        gainDb: 0.0,
      );

      biquad.prepare(44100, 256);
      for (final parameter in biquad.parameters.values) {
        parameter.update();
      }

      final input = Float32List(256);
      input.fillRange(0, input.length, 1.0);

      biquad.process(input);

      var trailingAbs = 0.0;
      const start = 200;
      for (var i = start; i < input.length; i++) {
        trailingAbs += input[i].abs();
      }
      final trailingAverageAbs = trailingAbs / (input.length - start);

      expect(trailingAverageAbs, lessThan(0.01));
      expect(biquad.coefficientUpdateCount, 1);
    });

    test('band-pass biquad emphasizes target frequency region', () {
      const sampleRate = 44100;
      const length = 4096;

      Float32List sine(double frequencyHz) {
        final data = Float32List(length);
        for (var i = 0; i < data.length; i++) {
          data[i] = math.sin(2.0 * math.pi * frequencyHz * i / sampleRate);
        }
        return data;
      }

      double rms(Float32List values, int start) {
        var sum = 0.0;
        final count = values.length - start;
        for (var i = start; i < values.length; i++) {
          final v = values[i].toDouble();
          sum += v * v;
        }
        return math.sqrt(sum / count);
      }

      final centerTone = sine(1200.0);
      final lowTone = sine(80.0);

      final centerFilter = BiquadProcessorNode(
        id: 'biquad-bp-center',
        mode: BiquadMode.bandpass,
        frequency: 1200,
        q: 4.0,
        gainDb: 0.0,
      );
      final lowFilter = BiquadProcessorNode(
        id: 'biquad-bp-low',
        mode: BiquadMode.bandpass,
        frequency: 1200,
        q: 4.0,
        gainDb: 0.0,
      );

      for (final filter in <BiquadProcessorNode>[centerFilter, lowFilter]) {
        filter.prepare(sampleRate, length);
        for (final parameter in filter.parameters.values) {
          parameter.update();
        }
      }

      centerFilter.process(centerTone);
      lowFilter.process(lowTone);

      final centerRms = rms(centerTone, 1024);
      final lowRms = rms(lowTone, 1024);

      expect(centerRms, greaterThan(lowRms * 6.0));
      expect(centerFilter.coefficientUpdateCount, 1);
      expect(lowFilter.coefficientUpdateCount, 1);
    });

    test('peak biquad boosts and cuts center frequency with gainDb', () {
      const sampleRate = 44100;
      const length = 4096;

      Float32List sine(double frequencyHz) {
        final data = Float32List(length);
        for (var i = 0; i < data.length; i++) {
          data[i] = math.sin(2.0 * math.pi * frequencyHz * i / sampleRate);
        }
        return data;
      }

      double rms(Float32List values, int start) {
        var sum = 0.0;
        final count = values.length - start;
        for (var i = start; i < values.length; i++) {
          final v = values[i].toDouble();
          sum += v * v;
        }
        return math.sqrt(sum / count);
      }

      final boost = BiquadProcessorNode(
        id: 'biquad-peak-boost',
        mode: BiquadMode.peak,
        frequency: 1200,
        q: 2.0,
        gainDb: 9.0,
      );
      final cut = BiquadProcessorNode(
        id: 'biquad-peak-cut',
        mode: BiquadMode.peak,
        frequency: 1200,
        q: 2.0,
        gainDb: -9.0,
      );

      for (final filter in <BiquadProcessorNode>[boost, cut]) {
        filter.prepare(sampleRate, length);
        for (final parameter in filter.parameters.values) {
          parameter.update();
        }
      }

      final boosted = sine(1200.0);
      final cutSignal = sine(1200.0);
      boost.process(boosted);
      cut.process(cutSignal);

      final boostedRms = rms(boosted, 1024);
      final cutRms = rms(cutSignal, 1024);

      expect(boostedRms, greaterThan(1.4));
      expect(cutRms, lessThan(0.45));
    });

    test('biquad updates coefficients only when frequency or q changes', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-cache',
        mode: BiquadMode.lowpass,
        frequency: 1000,
        q: 0.8,
        gainDb: 0.0,
      );

      biquad.prepare(44100, 32);
      for (final parameter in biquad.parameters.values) {
        parameter.update();
      }

      final bufferA = Float32List(32);
      biquad.process(bufferA);
      final afterFirstProcess = biquad.coefficientUpdateCount;

      final bufferB = Float32List(32);
      biquad.process(bufferB);
      final afterSecondProcess = biquad.coefficientUpdateCount;

      expect(afterFirstProcess, 1);
      expect(afterSecondProcess, afterFirstProcess);

      biquad.parameter('frequency')!.baseValue = 500.0;
      biquad.parameter('frequency')!.update();

      final bufferC = Float32List(32);
      biquad.process(bufferC);

      expect(biquad.coefficientUpdateCount, afterSecondProcess + 1);
    });

    test('biquad reads frequency from finalValue after update cycle', () {
      final biquad = BiquadProcessorNode(
        id: 'biquad-final',
        mode: BiquadMode.lowpass,
        frequency: 1200,
        q: 0.707,
        gainDb: 0.0,
      );

      biquad.prepare(44100, 16);
      biquad.parameter('frequency')!.update();
      biquad.parameter('q')!.update();
      biquad.parameter('gainDb')!.update();

      biquad.process(Float32List(16));
      final initialUpdates = biquad.coefficientUpdateCount;

      biquad.parameter('frequency')!.baseValue = 500.0;
      biquad.process(Float32List(16));
      expect(biquad.coefficientUpdateCount, initialUpdates);
      expect(biquad.smoothedFrequency, greaterThan(500.0));

      biquad.parameter('frequency')!.update();
      biquad.process(Float32List(16));
      expect(biquad.coefficientUpdateCount, initialUpdates + 1);
      expect(biquad.smoothedFrequency, lessThan(1200.0));
      expect(biquad.smoothedFrequency, greaterThan(500.0));
    });

    test('peak biquad updates coefficients when gainDb changes', () {
      final peak = BiquadProcessorNode(
        id: 'biquad-peak-cache',
        mode: BiquadMode.peak,
        frequency: 1000,
        q: 1.5,
        gainDb: 0.0,
      );

      peak.prepare(44100, 32);
      for (final parameter in peak.parameters.values) {
        parameter.update();
      }

      peak.process(Float32List(32));
      final initial = peak.coefficientUpdateCount;

      peak.process(Float32List(32));
      expect(peak.coefficientUpdateCount, initial);

      peak.parameter('gainDb')!.baseValue = 6.0;
      peak.parameter('gainDb')!.update();
      peak.process(Float32List(32));

      expect(peak.coefficientUpdateCount, initial + 1);
    });

    test('resonant flag shapes Q handling for lowpass/highpass modes', () {
      final lowpassNonResonant = BiquadProcessorNode(
        id: 'lp-non-res',
        mode: BiquadMode.lowpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: false,
      );
      final lowpassResonant = BiquadProcessorNode(
        id: 'lp-res',
        mode: BiquadMode.lowpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: true,
      );

      final highpassNonResonant = BiquadProcessorNode(
        id: 'hp-non-res',
        mode: BiquadMode.highpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: false,
      );
      final highpassResonant = BiquadProcessorNode(
        id: 'hp-res',
        mode: BiquadMode.highpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: true,
      );

      final nodes = <BiquadProcessorNode>[
        lowpassNonResonant,
        lowpassResonant,
        highpassNonResonant,
        highpassResonant,
      ];

      for (final node in nodes) {
        node.prepare(44100, 128);
        for (final parameter in node.parameters.values) {
          parameter.update();
        }
      }

      Float32List impulse() {
        final data = Float32List(128);
        data[0] = 1.0;
        return data;
      }

      final lpNonResBuf = impulse();
      final lpResBuf = impulse();
      final hpNonResBuf = impulse();
      final hpResBuf = impulse();

      lowpassNonResonant.process(lpNonResBuf);
      lowpassResonant.process(lpResBuf);
      highpassNonResonant.process(hpNonResBuf);
      highpassResonant.process(hpResBuf);

      double maxAbs(Float32List buffer) {
        var peak = 0.0;
        for (final sample in buffer) {
          final abs = sample.abs();
          if (abs > peak) {
            peak = abs;
          }
        }
        return peak;
      }

      expect(maxAbs(lpResBuf), greaterThan(maxAbs(lpNonResBuf)));
      expect(maxAbs(hpResBuf), greaterThan(maxAbs(hpNonResBuf)));
    });

    test('resonant flag shapes bandpass selectivity and peak width', () {
      const sampleRate = 44100;
      const length = 4096;

      Float32List sine(double frequencyHz) {
        final data = Float32List(length);
        for (var i = 0; i < data.length; i++) {
          data[i] = math.sin(2.0 * math.pi * frequencyHz * i / sampleRate);
        }
        return data;
      }

      double rms(Float32List values, int start) {
        var sum = 0.0;
        final count = values.length - start;
        for (var i = start; i < values.length; i++) {
          final v = values[i].toDouble();
          sum += v * v;
        }
        return math.sqrt(sum / count);
      }

      final bpResonant = BiquadProcessorNode(
        id: 'bp-res',
        mode: BiquadMode.bandpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: true,
      );
      final bpNonResonant = BiquadProcessorNode(
        id: 'bp-non-res',
        mode: BiquadMode.bandpass,
        frequency: 1200,
        q: 8.0,
        gainDb: 0.0,
        resonant: false,
      );

      final peakResonant = BiquadProcessorNode(
        id: 'peak-res',
        mode: BiquadMode.peak,
        frequency: 1200,
        q: 8.0,
        gainDb: 9.0,
        resonant: true,
      );
      final peakNonResonant = BiquadProcessorNode(
        id: 'peak-non-res',
        mode: BiquadMode.peak,
        frequency: 1200,
        q: 8.0,
        gainDb: 9.0,
        resonant: false,
      );

      for (final filter in <BiquadProcessorNode>[
        bpResonant,
        bpNonResonant,
        peakResonant,
        peakNonResonant,
      ]) {
        filter.prepare(sampleRate, length);
        for (final parameter in filter.parameters.values) {
          parameter.update();
        }
      }

      final bpOffCenterRes = sine(1500.0);
      final bpOffCenterNonRes = sine(1500.0);
      bpResonant.process(bpOffCenterRes);
      bpNonResonant.process(bpOffCenterNonRes);

      // High-Q resonant bandpass is narrower, so off-center tone is rejected more.
      expect(rms(bpOffCenterRes, 1024), lessThan(rms(bpOffCenterNonRes, 1024)));

      final nearBand = sine(1500.0);
      final nearBandRes = Float32List.fromList(nearBand);
      final nearBandNonRes = Float32List.fromList(nearBand);
      peakResonant.process(nearBandRes);
      peakNonResonant.process(nearBandNonRes);

      final dryNear = rms(nearBand, 1024);
      final resNear = rms(nearBandRes, 1024);
      final nonResNear = rms(nearBandNonRes, 1024);

      // High-Q resonant peak is narrower, so off-center tone is less affected.
      expect((resNear - dryNear).abs(), lessThan((nonResNear - dryNear).abs()));
    });
  });

  group('saturator processor', () {
    test(
      'saturator config serializes and deserializes with both curve types',
      () {
        const tanhConfig = ProcessorConfig(
          id: 'sat-1',
          type: ProcessorType.saturator,
          saturator: SaturatorConfig(drive: 0.7, curve: SaturatorCurve.tanh),
        );
        final softJson = <String, dynamic>{
          'id': 'sat-2',
          'type': 'saturator',
          'saturator': <String, dynamic>{'drive': 0.4, 'curve': 'soft'},
        };

        final tanhRound = ProcessorConfig.fromJson(tanhConfig.toJson());
        expect(tanhRound.id, 'sat-1');
        expect(tanhRound.saturator!.drive, closeTo(0.7, 1e-9));
        expect(tanhRound.saturator!.curve, SaturatorCurve.tanh);

        final softConfig = ProcessorConfig.fromJson(softJson);
        expect(softConfig.saturator!.drive, closeTo(0.4, 1e-6));
        expect(softConfig.saturator!.curve, SaturatorCurve.soft);
      },
    );

    test('saturator drive=0 passes buffer unchanged', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-bypass',
        curve: SaturatorCurve.tanh,
        drive: 0.0,
      );
      sat.prepare(44100, 4);
      for (final p in sat.parameters.values) {
        p.update();
      }

      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.3, -0.8]);
      final original = Float32List.fromList(buffer);
      sat.process(buffer);

      for (var i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(original[i], 1e-9));
      }
    });

    test(
      'saturator tanh drive=1 compresses and normalizes high-amplitude input',
      () {
        final sat = SaturatorProcessorNode(
          id: 'sat-tanh',
          curve: SaturatorCurve.tanh,
          drive: 1.0,
        );
        sat.prepare(44100, 4);
        for (final p in sat.parameters.values) {
          p.update();
        }

        // Input 0.5 with drive=1: tanh(5.0)/tanh(10.0) ≈ 1.0 — strongly saturated.
        final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.5, -0.5]);
        sat.process(buffer);

        for (final s in buffer) {
          expect(s.isFinite, isTrue);
        }
        // 0.5 input pushed strongly toward ±1.0 (gain+saturation).
        expect(buffer[0], greaterThan(0.9));
        expect(buffer[1], lessThan(-0.9));
        // Normalization keeps output within ±1.0.
        for (final s in buffer) {
          expect(s.abs(), lessThanOrEqualTo(1.0 + 1e-6));
        }
      },
    );

    test('saturator soft drive=1 clips and shapes high-amplitude input', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-soft',
        curve: SaturatorCurve.soft,
        drive: 1.0,
      );
      sat.prepare(44100, 4);
      for (final p in sat.parameters.values) {
        p.update();
      }

      // Input 0.5 with soft+drive=1: preGain=4, driven=clamp(2.0,-1,1)=1.0
      // satOut = 1.5*1.0*(1-1/3) = 1.0 — full soft clip output.
      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.5, -0.5]);
      sat.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
        expect(s.abs(), lessThanOrEqualTo(1.0 + 1e-6));
      }
      expect(buffer[0], greaterThan(0.9));
      expect(buffer[1], lessThan(-0.9));
    });

    test('saturator guards against non-finite drive parameter', () {
      final sat = SaturatorProcessorNode(
        id: 'sat-safe',
        curve: SaturatorCurve.tanh,
        drive: 1.0,
      );
      sat.prepare(44100, 4);
      sat.parameter('drive')!.baseValue = double.nan;
      sat.parameter('drive')!.update();

      final buffer = Float32List.fromList(<double>[0.5, -0.5, 0.3, -0.3]);
      sat.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
      }
    });
  });

  group('delay processor', () {
    test('delay config serializes and deserializes safely', () {
      const config = ProcessorConfig(
        id: 'delay-proc',
        type: ProcessorType.delay,
        delay: DelayConfig(delayTimeMs: 200, feedback: 0.4, mix: 0.5),
      );
      final roundTrip = ProcessorConfig.fromJson(config.toJson());

      expect(roundTrip.id, 'delay-proc');
      expect(roundTrip.delay!.delayTimeMs, 200);
      expect(roundTrip.delay!.feedback, closeTo(0.4, 1e-9));
      expect(roundTrip.delay!.mix, closeTo(0.5, 1e-9));
    });

    test('delay mix=0 passes buffer unchanged (dry bypass)', () {
      final delay = DelayProcessorNode(
        id: 'delay-dry',
        delayTimeMs: 10,
        feedback: 0.0,
        mix: 0.0,
      );
      delay.prepare(44100, 8);
      for (final p in delay.parameters.values) {
        p.update();
      }

      final buffer = Float32List.fromList(<double>[
        0.1,
        0.2,
        0.3,
        0.4,
        0.5,
        0.6,
        0.7,
        0.8,
      ]);
      final original = Float32List.fromList(buffer);
      delay.process(buffer);

      for (var i = 0; i < buffer.length; i++) {
        expect(buffer[i], closeTo(original[i], 1e-6));
      }
    });

    test(
      'delay mix=1 feedback=0 outputs delayed signal after delaySamples',
      () {
        // 10ms × 44100 Hz = 441 samples of delay.
        final delay = DelayProcessorNode(
          id: 'delay-impulse',
          delayTimeMs: 10,
          feedback: 0.0,
          mix: 1.0,
        );
        const blockSize = 512;
        delay.prepare(44100, blockSize);
        for (final p in delay.parameters.values) {
          p.update();
        }

        // Single impulse at index 0; rest silent.
        final buffer = Float32List(blockSize);
        buffer[0] = 1.0;
        delay.process(buffer);

        // Samples before the delay window should be silent.
        expect(buffer[0], closeTo(0.0, 1e-6));
        for (var i = 1; i < 441; i++) {
          expect(buffer[i], closeTo(0.0, 1e-6));
        }
        // Impulse emerges exactly 441 samples later.
        expect(buffer[441], closeTo(1.0, 1e-4));
      },
    );

    test('delay feedback accumulates signal energy over time', () {
      final delay = DelayProcessorNode(
        id: 'delay-feedback',
        delayTimeMs: 5,
        feedback: 0.5,
        mix: 0.5,
      );
      const blockSize = 256;
      delay.prepare(44100, blockSize);
      for (final p in delay.parameters.values) {
        p.update();
      }

      // Drive the delay with a constant signal for one block.
      final block1 = Float32List(blockSize);
      block1.fillRange(0, blockSize, 0.5);
      delay.process(block1);

      // Feed silence into the delay — energy should appear from feedback tails.
      final block2 = Float32List(blockSize);
      delay.process(block2);
      final energy = block2.fold<double>(0.0, (sum, s) => sum + s * s);

      expect(energy, greaterThan(0.0));
    });

    test('delay guards against non-finite feedback parameter', () {
      final delay = DelayProcessorNode(
        id: 'delay-safe',
        delayTimeMs: 10,
        feedback: 0.5,
        mix: 0.5,
      );
      delay.prepare(44100, 8);
      delay.parameter('feedback')!.baseValue = double.nan;
      delay.parameter('feedback')!.update();

      final buffer = Float32List(8);
      buffer.fillRange(0, 8, 0.5);
      delay.process(buffer);

      for (final s in buffer) {
        expect(s.isFinite, isTrue);
      }
    });
  });
}
