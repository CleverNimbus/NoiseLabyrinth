import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

void main() {
  group('audio sources', () {
    test('AudioNode base classes prepare and keep parameters', () {
      final source = SineSourceNode(
        id: 'source-1',
        frequencyHz: 220,
        phase: 0.0,
      );
      final processor = GainProcessorNode(id: 'proc-1', gain: 1.0);

      source.prepare(48000, 256);
      processor.prepare(48000, 256);

      expect(source.sampleRate, 48000);
      expect(source.blockSize, 256);
      expect(processor.sampleRate, 48000);
      expect(processor.blockSize, 256);
      expect(source.parameter('frequencyHz'), isA<Parameter>());
      expect(processor.parameter('gain'), isA<Parameter>());
    });

    test('white noise source produces non-silent samples', () {
      final source = NoiseSourceNode(
        id: 'noise-source',
        color: NoiseColor.white,
        low: 20,
        high: 20000,
      );

      source.prepare(44100, 64);
      for (final parameter in source.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(64);
      source.process(buffer);

      final allZero = buffer.every((sample) => sample == 0.0);
      expect(allZero, isFalse);

      final first = buffer.first;
      final allEqual = buffer.every((sample) => sample == first);
      expect(allEqual, isFalse);
    });

    test('pink and brown noise sources produce valid non-silent buffers', () {
      final pink = NoiseSourceNode(
        id: 'pink-source',
        color: NoiseColor.pink,
        low: 20,
        high: 20000,
      );
      final brown = NoiseSourceNode(
        id: 'brown-source',
        color: NoiseColor.brown,
        low: 20,
        high: 20000,
      );

      pink.prepare(44100, 256);
      brown.prepare(44100, 256);
      for (final parameter in pink.parameters.values) {
        parameter.update();
      }
      for (final parameter in brown.parameters.values) {
        parameter.update();
      }

      final pinkBuffer = Float32List(256);
      final brownBuffer = Float32List(256);
      pink.process(pinkBuffer);
      brown.process(brownBuffer);

      expect(pinkBuffer.every((sample) => sample == 0.0), isFalse);
      expect(brownBuffer.every((sample) => sample == 0.0), isFalse);

      for (final sample in pinkBuffer) {
        expect(sample, greaterThanOrEqualTo(-1.0));
        expect(sample, lessThanOrEqualTo(1.0));
      }
      for (final sample in brownBuffer) {
        expect(sample, greaterThanOrEqualTo(-1.0));
        expect(sample, lessThanOrEqualTo(1.0));
      }
    });

    test('pink and brown are temporally smoother than white noise', () {
      final white = NoiseSourceNode(
        id: 'white-compare',
        color: NoiseColor.white,
        low: 20,
        high: 20000,
      );
      final pink = NoiseSourceNode(
        id: 'pink-compare',
        color: NoiseColor.pink,
        low: 20,
        high: 20000,
      );
      final brown = NoiseSourceNode(
        id: 'brown-compare',
        color: NoiseColor.brown,
        low: 20,
        high: 20000,
      );

      white.prepare(44100, 1024);
      pink.prepare(44100, 1024);
      brown.prepare(44100, 1024);
      for (final parameter in white.parameters.values) {
        parameter.update();
      }
      for (final parameter in pink.parameters.values) {
        parameter.update();
      }
      for (final parameter in brown.parameters.values) {
        parameter.update();
      }

      final whiteBuffer = Float32List(1024);
      final pinkBuffer = Float32List(1024);
      final brownBuffer = Float32List(1024);

      white.process(whiteBuffer);
      pink.process(pinkBuffer);
      brown.process(brownBuffer);

      double averageDelta(Float32List buffer) {
        var sum = 0.0;
        for (var i = 1; i < buffer.length; i++) {
          sum += (buffer[i] - buffer[i - 1]).abs();
        }
        return sum / (buffer.length - 1);
      }

      final whiteDelta = averageDelta(whiteBuffer);
      final pinkDelta = averageDelta(pinkBuffer);
      final brownDelta = averageDelta(brownBuffer);

      expect(pinkDelta, lessThan(whiteDelta));
      expect(brownDelta, lessThan(whiteDelta));
    });

    test('impulse source generates sparse clicks', () {
      final impulse = ImpulseSourceNode(
        id: 'impulse-sparse',
        density: 0.01,
        randomness: 0.0,
      );

      impulse.prepare(44100, 1024);
      for (final parameter in impulse.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(1024);
      impulse.process(buffer);

      var nonZeroCount = 0;
      for (final sample in buffer) {
        if (sample != 0.0) {
          nonZeroCount++;
        }
      }

      expect(nonZeroCount, greaterThan(0));
      expect(nonZeroCount, lessThan(80));
    });

    test('impulse source supports amplitude variation', () {
      final impulse = ImpulseSourceNode(
        id: 'impulse-randomness',
        density: 1.0,
        randomness: 0.8,
      );

      impulse.prepare(44100, 256);
      for (final parameter in impulse.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(256);
      impulse.process(buffer);

      final allOne = buffer.every((sample) => (sample - 1.0).abs() < 1e-9);
      expect(allOne, isFalse);

      for (final sample in buffer) {
        expect(sample, greaterThan(0.19));
        expect(sample, lessThanOrEqualTo(1.0));
      }
    });

    test('sine source generates stable oscillator signal', () {
      final sine = SineSourceNode(
        id: 'sine-source',
        frequencyHz: 400,
        phase: 0.0,
      );

      sine.prepare(8000, 256);
      for (final parameter in sine.parameters.values) {
        parameter.update();
      }

      final buffer = Float32List(256);
      sine.process(buffer);

      var peak = 0.0;
      var energy = 0.0;
      var zeroCrossings = 0;
      for (var i = 0; i < buffer.length; i++) {
        final sample = buffer[i].toDouble();
        peak = math.max(peak, sample.abs());
        energy += sample * sample;
        if (i > 0 &&
            ((buffer[i - 1] <= 0.0 && sample > 0.0) ||
                (buffer[i - 1] >= 0.0 && sample < 0.0))) {
          zeroCrossings++;
        }
      }

      final rms = math.sqrt(energy / buffer.length);
      expect(peak, greaterThan(0.95));
      expect(rms, closeTo(0.707, 0.08));
      expect(zeroCrossings, greaterThan(20));
    });

    test('bandlimited noise attenuates out-of-band energy', () {
      const sampleRate = 8000;
      const n = 2048;

      final white = NoiseSourceNode(
        id: 'white-band-compare',
        color: NoiseColor.white,
        low: 0,
        high: sampleRate ~/ 2,
      );
      final bandlimited = NoiseSourceNode(
        id: 'bandlimited',
        color: NoiseColor.bandlimited,
        low: 80,
        high: 600,
      );

      white.prepare(sampleRate, n);
      bandlimited.prepare(sampleRate, n);
      for (final parameter in white.parameters.values) {
        parameter.update();
      }
      for (final parameter in bandlimited.parameters.values) {
        parameter.update();
      }

      final whiteBuffer = Float32List(n);
      final bandBuffer = Float32List(n);
      white.process(whiteBuffer);
      bandlimited.process(bandBuffer);

      double binMagnitude(Float32List data, int bin) {
        var real = 0.0;
        var imag = 0.0;
        for (var i = 0; i < data.length; i++) {
          final phase = 2.0 * math.pi * bin * i / data.length;
          real += data[i] * math.cos(phase);
          imag -= data[i] * math.sin(phase);
        }
        return math.sqrt(real * real + imag * imag) / data.length;
      }

      final lowBin = (200 * n / sampleRate).round();
      final highBin = (2200 * n / sampleRate).round();

      final whiteLow = binMagnitude(whiteBuffer, lowBin);
      final whiteHigh = binMagnitude(whiteBuffer, highBin);
      final bandLow = binMagnitude(bandBuffer, lowBin);
      final bandHigh = binMagnitude(bandBuffer, highBin);

      expect(bandLow, greaterThan(0.005));
      expect(bandHigh, lessThan(whiteHigh * 0.4));
      expect(bandHigh, lessThan(bandLow));
      expect(whiteLow, greaterThan(0.001));
    });
  });
}
