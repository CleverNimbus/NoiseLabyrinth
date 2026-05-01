import 'dart:math' as math;
import 'dart:typed_data';

import 'package:noiselabyrinth_core/engine/audio_node.dart';
import 'package:noiselabyrinth_core/engine/modulation_engine.dart';
import 'package:noiselabyrinth_core/engine/event_engine.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/event_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_core/models/parameter.dart';
import 'package:noiselabyrinth_core/models/smoothed_parameter.dart';

class NoiseSourceNode extends SourceNode {
  static const double _twoPi = 2.0 * math.pi;

  final NoiseColor color;
  int _rngState;

  // State for brown and pink noise shaping.
  double _brownState = 0.0;
  double _pink0 = 0.0;
  double _pink1 = 0.0;
  double _pink2 = 0.0;
  double _pink3 = 0.0;
  double _pink4 = 0.0;
  double _pink5 = 0.0;
  double _pink6 = 0.0;

  // State for simple band-limiting (high-pass then low-pass).
  double _bandLowAlpha = 0.0;
  double _bandHighAlpha = 0.0;
  double _bandLowHz = 0.0;
  double _bandHighHz = 0.0;
  double _bandPrevInput = 0.0;
  double _bandHighState = 0.0;
  double _bandLowState = 0.0;

  NoiseSourceNode({
    required super.id,
    required this.color,
    required int low,
    required int high,
    int seed = 0,
  }) : _rngState = 1,
       super(
         parameters: <String, Parameter>{
           'bandLow': Parameter(low.toDouble()),
           'bandHigh': Parameter(high.toDouble()),
         },
       ) {
    _rngState = _nonZeroSeed(seed, id);
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    if (color == NoiseColor.bandlimited) {
      _updateBandlimitCoefficientsIfNeeded();
    }

    var state = _rngState;
    for (var i = 0; i < buffer.length; i++) {
      state = _xorshift32(state);
      final white = _stateToUnitFloat(state);

      switch (color) {
        case NoiseColor.white:
          buffer[i] = white;
          break;
        case NoiseColor.bandlimited:
          buffer[i] = _nextBandlimitedSample(white);
          break;
        case NoiseColor.brown:
          buffer[i] = _nextBrownSample(white);
          break;
        case NoiseColor.pink:
          buffer[i] = _nextPinkSample(white);
          break;
      }
    }
    _rngState = state;
  }

  void _updateBandlimitCoefficientsIfNeeded() {
    final nyquist = sampleRate > 0 ? (sampleRate * 0.5) : 22050.0;
    final requestedLow = parameter('bandLow')!.finalValue;
    final requestedHigh = parameter('bandHigh')!.finalValue;

    var low = requestedLow.clamp(0.0, nyquist - 2.0).toDouble();
    var high = requestedHigh.clamp(1.0, nyquist - 1.0).toDouble();
    if (high <= low + 1.0) {
      high = (low + 1.0).clamp(1.0, nyquist - 1.0).toDouble();
      low = (high - 1.0).clamp(0.0, nyquist - 2.0).toDouble();
    }

    if ((_bandLowHz - low).abs() < 1e-9 && (_bandHighHz - high).abs() < 1e-9) {
      return;
    }

    final dt = sampleRate > 0 ? 1.0 / sampleRate : 1.0 / 44100.0;

    if (low <= 0.0) {
      _bandLowAlpha = 0.0;
    } else {
      final rcLow = 1.0 / (_twoPi * low);
      _bandLowAlpha = rcLow / (rcLow + dt);
    }

    final rcHigh = 1.0 / (_twoPi * high);
    _bandHighAlpha = dt / (rcHigh + dt);

    _bandLowHz = low;
    _bandHighHz = high;
  }

  double _nextBandlimitedSample(double white) {
    final highPassed = _bandLowAlpha <= 0.0
        ? white
        : _bandLowAlpha * (_bandHighState + white - _bandPrevInput);
    _bandPrevInput = white;
    _bandHighState = highPassed;

    _bandLowState += _bandHighAlpha * (highPassed - _bandLowState);
    return _bandLowState.clamp(-1.0, 1.0).toDouble();
  }

  double _nextBrownSample(double white) {
    // Integrated white with gentle leakage to avoid DC drift.
    _brownState = (_brownState + (white * 0.02)) * 0.995;
    _brownState = _brownState.clamp(-1.0, 1.0).toDouble();
    return _brownState;
  }

  double _nextPinkSample(double white) {
    // Paul Kellet-style pinking filter.
    _pink0 = (0.99886 * _pink0) + (white * 0.0555179);
    _pink1 = (0.99332 * _pink1) + (white * 0.0750759);
    _pink2 = (0.96900 * _pink2) + (white * 0.1538520);
    _pink3 = (0.86650 * _pink3) + (white * 0.3104856);
    _pink4 = (0.55000 * _pink4) + (white * 0.5329522);
    _pink5 = (-0.7616 * _pink5) - (white * 0.0168980);

    final pink =
        _pink0 +
        _pink1 +
        _pink2 +
        _pink3 +
        _pink4 +
        _pink5 +
        _pink6 +
        (white * 0.5362);
    _pink6 = white * 0.115926;

    return (pink * 0.11).clamp(-1.0, 1.0).toDouble();
  }

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
  }

  static double _stateToUnitFloat(int state) {
    return ((state & 0x7FFFFFFF) / 1073741824.0) - 1.0;
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

    return hash == 0 ? 0x6D2B79F5 : hash;
  }
}

class SineSourceNode extends SourceNode {
  static const double _twoPi = 2.0 * math.pi;

  double _phaseAccumulator = 0.0;

  SineSourceNode({
    required super.id,
    required int frequencyHz,
    required double phase,
  }) : super(
         parameters: <String, Parameter>{
           'frequencyHz': Parameter(frequencyHz.toDouble()),
           'phase': Parameter(phase),
         },
       );

  @override
  void prepare(int sampleRate, int blockSize) {
    super.prepare(sampleRate, blockSize);
    _phaseAccumulator = parameter('phase')!.baseValue;
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final nyquist = sampleRate > 0 ? sampleRate * 0.5 : 22050.0;
    final frequency = parameter(
      'frequencyHz',
    )!.finalValue.clamp(0.0, nyquist).toDouble();
    final phaseOffset = parameter('phase')!.finalValue;
    final phaseStep = sampleRate > 0 ? _twoPi * frequency / sampleRate : 0.0;

    var phase = _phaseAccumulator;
    for (var i = 0; i < buffer.length; i++) {
      final wrappedPhase = phase + phaseOffset;
      buffer[i] = math.sin(wrappedPhase);
      phase += phaseStep;
      if (phase >= _twoPi) {
        phase -= _twoPi;
      }
    }

    _phaseAccumulator = phase;
  }
}

class ImpulseSourceNode extends SourceNode {
  int _rngState;

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

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final density = parameter('density')!.finalValue.clamp(0.0, 1.0).toDouble();
    final randomness = parameter(
      'randomness',
    )!.finalValue.clamp(0.0, 1.0).toDouble();

    var state = _rngState;
    for (var i = 0; i < buffer.length; i++) {
      state = _xorshift32(state);
      final trigger = _stateToUnit01(state) < density;
      if (!trigger) {
        buffer[i] = 0.0;
        continue;
      }

      state = _xorshift32(state);
      final amplitudeJitter = _stateToUnit01(state) * randomness;
      final amplitude = 1.0 - amplitudeJitter;
      buffer[i] = amplitude;
    }

    _rngState = state;
  }

  static int _xorshift32(int state) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= (state >> 17) & 0xFFFFFFFF;
    state ^= (state << 5) & 0xFFFFFFFF;
    return state & 0xFFFFFFFF;
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

class BiquadProcessorNode extends ProcessorNode {
  static const double frequencySmoothing = 0.2;
  static final double _nonResonantMaxQ = 1.0 / math.sqrt(2.0);

  final BiquadMode mode;
  final bool resonant;
  final SmoothedParameter _smoothedFrequency;

  double _b0 = 1.0;
  double _b1 = 0.0;
  double _b2 = 0.0;
  double _a1 = 0.0;
  double _a2 = 0.0;

  double _x1 = 0.0;
  double _x2 = 0.0;
  double _y1 = 0.0;
  double _y2 = 0.0;

  double? _lastFrequency;
  double? _lastQ;
  double? _lastGainDb;
  int _coefficientUpdateCount = 0;

  int get coefficientUpdateCount => _coefficientUpdateCount;
  double get smoothedFrequency => _smoothedFrequency.current;

  BiquadProcessorNode({
    required super.id,
    required this.mode,
    required int frequency,
    required double q,
    required double gainDb,
    this.resonant = false,
  }) : _smoothedFrequency = SmoothedParameter(
         frequency.toDouble(),
         frequencySmoothing,
       ),
       super(
         parameters: <String, Parameter>{
           'frequency': Parameter(frequency.toDouble()),
           'q': Parameter(q),
           'gainDb': Parameter(gainDb),
         },
       );

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    _updateCoefficientsIfNeeded();

    var x1 = _x1;
    var x2 = _x2;
    var y1 = _y1;
    var y2 = _y2;

    for (var i = 0; i < buffer.length; i++) {
      final x0 = buffer[i].toDouble();
      final y0 = (_b0 * x0) + (_b1 * x1) + (_b2 * x2) - (_a1 * y1) - (_a2 * y2);

      buffer[i] = y0;

      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }

    _x1 = x1;
    _x2 = x2;
    _y1 = y1;
    _y2 = y2;
  }

  void _updateCoefficientsIfNeeded() {
    final frequencyParameter = parameter('frequency')!;
    final qParameter = parameter('q')!;
    final gainDbParameter = parameter('gainDb')!;

    final rawFrequency = frequencyParameter.finalValue;
    _smoothedFrequency.target = rawFrequency;
    _smoothedFrequency.update();
    final nyquist = sampleRate > 0 ? sampleRate * 0.5 : 22050.0;
    final frequency = _smoothedFrequency.current
        .clamp(1.0, nyquist - 1.0)
        .toDouble();
    final rawQ = qParameter.finalValue < 1e-4 ? 1e-4 : qParameter.finalValue;
    final q = resonant ? rawQ : rawQ.clamp(1e-4, _nonResonantMaxQ).toDouble();
    final gainDb = gainDbParameter.finalValue;

    final frequencyChanged =
        _lastFrequency == null || (_lastFrequency! - frequency).abs() > 1e-9;
    final qChanged = _lastQ == null || (_lastQ! - q).abs() > 1e-9;
    final gainChangedForPeak =
        mode == BiquadMode.peak &&
        (_lastGainDb == null || (_lastGainDb! - gainDb).abs() > 1e-9);

    if (!frequencyChanged && !qChanged && !gainChangedForPeak) {
      return;
    }

    final omega = 2.0 * math.pi * frequency / sampleRate;
    final cosOmega = math.cos(omega);
    final sinOmega = math.sin(omega);
    final alpha = sinOmega / (2.0 * q);

    final double b0;
    final double b1;
    final double b2;
    switch (mode) {
      case BiquadMode.lowpass:
        b0 = (1.0 - cosOmega) * 0.5;
        b1 = 1.0 - cosOmega;
        b2 = (1.0 - cosOmega) * 0.5;
        break;
      case BiquadMode.highpass:
        b0 = (1.0 + cosOmega) * 0.5;
        b1 = -(1.0 + cosOmega);
        b2 = (1.0 + cosOmega) * 0.5;
        break;
      case BiquadMode.bandpass:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
        break;
      case BiquadMode.peak:
        final gainLinear = math.pow(10.0, gainDb / 40.0).toDouble();
        b0 = 1.0 + alpha * gainLinear;
        b1 = -2.0 * cosOmega;
        b2 = 1.0 - alpha * gainLinear;
        final a0Peak = 1.0 + alpha / gainLinear;
        final a1Peak = -2.0 * cosOmega;
        final a2Peak = 1.0 - alpha / gainLinear;

        _b0 = b0 / a0Peak;
        _b1 = b1 / a0Peak;
        _b2 = b2 / a0Peak;
        _a1 = a1Peak / a0Peak;
        _a2 = a2Peak / a0Peak;

        _lastFrequency = frequency;
        _lastQ = q;
        _lastGainDb = gainDb;
        _coefficientUpdateCount++;
        return;
    }
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;

    _lastFrequency = frequency;
    _lastQ = q;
    _lastGainDb = gainDb;
    _coefficientUpdateCount++;
  }
}

class GainProcessorNode extends ProcessorNode {
  static const double gainSmoothing = 0.2;

  final SmoothedParameter _smoothedGain;

  double get smoothedGain => _smoothedGain.current;

  GainProcessorNode({required super.id, required double gain})
    : _smoothedGain = SmoothedParameter(gain, gainSmoothing),
      super(parameters: <String, Parameter>{'gain': Parameter(gain)});

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawGain = parameter('gain')!.finalValue;
    _smoothedGain.target = rawGain.isFinite ? rawGain : 0.0;
    _smoothedGain.update();
    final gainValue = _smoothedGain.current.isFinite
        ? _smoothedGain.current
        : 0.0;
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] *= gainValue;
    }
  }
}

class SaturatorProcessorNode extends ProcessorNode {
  static const double _driveSmoothing = 0.1;

  final SaturatorCurve curve;
  final SmoothedParameter _smoothedDrive;

  SaturatorProcessorNode({
    required super.id,
    required this.curve,
    required double drive,
  }) : _smoothedDrive = SmoothedParameter(drive, _driveSmoothing),
       super(parameters: <String, Parameter>{'drive': Parameter(drive)});

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawDrive = parameter('drive')!.finalValue;
    _smoothedDrive.target = rawDrive.isFinite ? rawDrive.clamp(0.0, 1.0) : 0.0;
    _smoothedDrive.update();
    final drive = _smoothedDrive.current.clamp(0.0, 1.0);

    if (drive <= 0.0) {
      return;
    }

    switch (curve) {
      case SaturatorCurve.tanh:
        _processTanh(buffer, drive);
      case SaturatorCurve.soft:
        _processSoft(buffer, drive);
    }
  }

  void _processTanh(Float32List buffer, double drive) {
    // preGain scales from 1× (drive=0) to 10× (drive=1).
    final preGain = 1.0 + drive * 9.0;
    // normFactor ensures unity gain for full-scale (1.0) input.
    final normFactor = 1.0 / _tanh(preGain);
    final dry = 1.0 - drive;
    for (var i = 0; i < buffer.length; i++) {
      final x = buffer[i].toDouble();
      final satOut = _tanh(x * preGain) * normFactor;
      buffer[i] = x * dry + satOut * drive;
    }
  }

  void _processSoft(Float32List buffer, double drive) {
    // preGain scales from 1× (drive=0) to 4× (drive=1).
    final preGain = 1.0 + drive * 3.0;
    final dry = 1.0 - drive;
    for (var i = 0; i < buffer.length; i++) {
      final x = buffer[i].toDouble();
      final driven = (x * preGain).clamp(-1.0, 1.0);
      // Cubic soft-clip: y = (3/2) * x * (1 - x²/3).  Max output ±1.0 at x=±1.
      final satOut = 1.5 * driven * (1.0 - driven * driven / 3.0);
      buffer[i] = x * dry + satOut * drive;
    }
  }

  // dart:math has no tanh; this identity is numerically stable.
  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }
}

class DelayProcessorNode extends ProcessorNode {
  static const double _feedbackSmoothing = 0.1;
  static const double _mixSmoothing = 0.1;

  Float32List _delayLine = Float32List(1);
  int _writeIndex = 0;
  int _delaySamples = 1;

  final SmoothedParameter _smoothedFeedback;
  final SmoothedParameter _smoothedMix;

  DelayProcessorNode({
    required super.id,
    required int delayTimeMs,
    required double feedback,
    required double mix,
  }) : _smoothedFeedback = SmoothedParameter(feedback, _feedbackSmoothing),
       _smoothedMix = SmoothedParameter(mix, _mixSmoothing),
       super(
         parameters: <String, Parameter>{
           'delayTimeMs': Parameter(delayTimeMs.toDouble()),
           'feedback': Parameter(feedback),
           'mix': Parameter(mix),
         },
       );

  @override
  void prepare(int sampleRate, int blockSize) {
    super.prepare(sampleRate, blockSize);
    final delayMs = parameter('delayTimeMs')!.baseValue.clamp(1.0, 5000.0);
    _delaySamples = ((delayMs * sampleRate / 1000).round()).clamp(
      1,
      sampleRate * 5,
    );
    _delayLine = Float32List(_delaySamples);
    _writeIndex = 0;
  }

  @override
  void process(Float32List buffer, {Float32List? scratch}) {
    final rawFeedback = parameter('feedback')!.finalValue;
    _smoothedFeedback.target = rawFeedback.isFinite
        ? rawFeedback.clamp(0.0, 0.95)
        : 0.0;
    _smoothedFeedback.update();
    final feedback = _smoothedFeedback.current.clamp(0.0, 0.95);

    final rawMix = parameter('mix')!.finalValue;
    _smoothedMix.target = rawMix.isFinite ? rawMix.clamp(0.0, 1.0) : 0.0;
    _smoothedMix.update();
    final mix = _smoothedMix.current.clamp(0.0, 1.0);

    final len = _delayLine.length;
    for (var i = 0; i < buffer.length; i++) {
      // Read the oldest sample (delaySamples ago) from the ring buffer.
      final delayedOut = _delayLine[_writeIndex].toDouble();
      // Overwrite that slot with the current input plus feedback.
      _delayLine[_writeIndex] = buffer[i] + delayedOut * feedback;
      _writeIndex = (_writeIndex + 1) % len;
      buffer[i] = buffer[i] * (1.0 - mix) + delayedOut * mix;
    }
  }
}

class LayerRuntime {
  final String id;
  final Parameter gain;
  final Parameter pan;
  final SourceNode source;
  final List<ProcessorNode> processors;
  final String outputNodeId;
  final List<ResolvedModulationTarget> resolvedModulationTargets;
  final List<RuntimeModulationBinding> modulationBindings;
  final List<RuntimeEventBinding> eventBindings;

  const LayerRuntime({
    required this.id,
    required this.gain,
    required this.pan,
    required this.source,
    required this.processors,
    required this.outputNodeId,
    required this.resolvedModulationTargets,
    required this.modulationBindings,
    required this.eventBindings,
  });
}

class ResolvedParameterReference {
  final String nodeId;
  final String parameterName;
  final Parameter parameter;

  const ResolvedParameterReference({
    required this.nodeId,
    required this.parameterName,
    required this.parameter,
  });
}

class ResolvedModulationTarget {
  final String modulationId;
  final String targetPath;
  final double amount;
  final ModulationApplyMode mode;
  final double? minValue;
  final double? maxValue;
  final ResolvedParameterReference reference;

  const ResolvedModulationTarget({
    required this.modulationId,
    required this.targetPath,
    required this.amount,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.reference,
  });
}

class ParameterRegistry {
  final Map<String, ResolvedParameterReference> _byNodeAndParameter =
      <String, ResolvedParameterReference>{};
  final Map<String, ResolvedParameterReference> _byPath =
      <String, ResolvedParameterReference>{};

  void register(
    String nodeId,
    String parameterName,
    Parameter parameter, {
    List<String> pathAliases = const <String>[],
  }) {
    final reference = ResolvedParameterReference(
      nodeId: nodeId,
      parameterName: parameterName,
      parameter: parameter,
    );

    _byNodeAndParameter[_key(nodeId, parameterName)] = reference;

    for (final alias in pathAliases) {
      _byPath[alias] = reference;
    }
  }

  ResolvedParameterReference? resolveNodeParameter(
    String nodeId,
    String parameterName,
  ) {
    return _byNodeAndParameter[_key(nodeId, parameterName)];
  }

  ResolvedParameterReference? resolvePath(String path) => _byPath[path];

  static String _key(String nodeId, String parameterName) =>
      '$nodeId::$parameterName';
}

class RuntimeGraph {
  final GenerationConfig config;
  final Parameter masterMix;
  final List<LayerRuntime> layers;
  final Map<String, AudioNode> nodesById;
  final ParameterRegistry parameters;

  const RuntimeGraph({
    required this.config,
    required this.masterMix,
    required this.layers,
    required this.nodesById,
    required this.parameters,
  });

  ResolvedParameterReference? resolveNodeParameter(
    String nodeId,
    String parameterName,
  ) {
    return parameters.resolveNodeParameter(nodeId, parameterName);
  }

  ResolvedParameterReference? resolvePath(String path) {
    return parameters.resolvePath(path);
  }
}

class NodeFactory {
  static SourceNode createSource(SourceConfig config) {
    switch (config.type) {
      case SourceType.noise:
        final noise = config.noiseConfig;
        if (noise == null) {
          throw StateError('noiseConfig is required for noise source.');
        }

        return NoiseSourceNode(
          id: 'source',
          color: noise.color,
          low: noise.band.low,
          high: noise.band.high,
        );
      case SourceType.impulse:
        final impulse = config.impulseConfig;
        if (impulse == null) {
          throw StateError('impulseConfig is required for impulse source.');
        }

        return ImpulseSourceNode(
          id: 'source',
          density: impulse.density,
          randomness: impulse.randomness,
        );
      case SourceType.sine:
        final sine = config.sineConfig;
        if (sine == null) {
          throw StateError('sineConfig is required for sine source.');
        }

        return SineSourceNode(
          id: 'source',
          frequencyHz: sine.frequencyHz,
          phase: sine.phase,
        );
    }
  }

  static ProcessorNode createProcessor(ProcessorConfig config) {
    switch (config.type) {
      case ProcessorType.biquad:
        final biquad = config.biquad;
        if (biquad == null) {
          throw StateError('biquad config is required for biquad processor.');
        }

        return BiquadProcessorNode(
          id: config.id,
          mode: biquad.biquadMode,
          frequency: biquad.frequency,
          q: biquad.q,
          gainDb: biquad.gainDb,
          resonant: biquad.resonant,
        );
      case ProcessorType.gain:
        final gain = config.gain;
        if (gain == null) {
          throw StateError('gain config is required for gain processor.');
        }

        return GainProcessorNode(id: config.id, gain: gain.gain);
      case ProcessorType.saturator:
        final saturator = config.saturator;
        if (saturator == null) {
          throw StateError(
            'saturator config is required for saturator processor.',
          );
        }

        return SaturatorProcessorNode(
          id: config.id,
          curve: saturator.curve,
          drive: saturator.drive,
        );
      case ProcessorType.delay:
        final delay = config.delay;
        if (delay == null) {
          throw StateError('delay config is required for delay processor.');
        }

        return DelayProcessorNode(
          id: config.id,
          delayTimeMs: delay.delayTimeMs,
          feedback: delay.feedback,
          mix: delay.mix,
        );
    }
  }
}

class RuntimeGraphBuilder {
  final int sampleRate;

  const RuntimeGraphBuilder({this.sampleRate = 44100});

  int get _sampleRate => sampleRate <= 0 ? 44100 : sampleRate;

  RuntimeGraph build(GenerationConfig config) {
    final masterMix = Parameter(config.mix.mix);
    final layers = <LayerRuntime>[];
    final nodesById = <String, AudioNode>{};
    final registry = ParameterRegistry();

    for (final layerConfig in config.layers) {
      final layer = _buildLayer(layerConfig, nodesById, registry);
      layers.add(layer);
    }

    return RuntimeGraph(
      config: config,
      masterMix: masterMix,
      layers: List<LayerRuntime>.unmodifiable(layers),
      nodesById: Map<String, AudioNode>.unmodifiable(nodesById),
      parameters: registry,
    );
  }

  LayerRuntime _buildLayer(
    LayerConfig config,
    Map<String, AudioNode> nodesById,
    ParameterRegistry registry,
  ) {
    final layerGain = Parameter(config.gain);
    final layerPan = Parameter(config.pan);
    registry.register(
      config.id,
      'gain',
      layerGain,
      pathAliases: <String>['layers[${config.id}].gain'],
    );
    registry.register(
      config.id,
      'pan',
      layerPan,
      pathAliases: <String>['layers[${config.id}].pan'],
    );

    final source = NodeFactory.createSource(config.source);
    source.id = '${config.id}.source';
    _registerSourceParameters(config.id, source, registry);
    nodesById[source.id] = source;

    final processors = <ProcessorNode>[];
    var previousNodeId = source.id;
    for (final processorConfig in config.processors) {
      final processor = NodeFactory.createProcessor(processorConfig);
      processor.id = '${config.id}.${processorConfig.id}';
      processor.inputNodeId = previousNodeId;
      previousNodeId = processor.id;
      _registerProcessorParameters(
        config.id,
        processorConfig.id,
        processor,
        registry,
      );
      nodesById[processor.id] = processor;
      processors.add(processor);
    }

    final resolvedTargets = _resolveModulationTargets(
      config.modulations,
      registry,
    );
    final modulationBindings = _buildModulationBindings(
      config.modulations,
      resolvedTargets,
    );
    final eventBindings = _buildEventBindings(
      config.events,
      modulationBindings,
    );

    return LayerRuntime(
      id: config.id,
      gain: layerGain,
      pan: layerPan,
      source: source,
      processors: List<ProcessorNode>.unmodifiable(processors),
      outputNodeId: previousNodeId,
      resolvedModulationTargets: List<ResolvedModulationTarget>.unmodifiable(
        resolvedTargets,
      ),
      modulationBindings: List<RuntimeModulationBinding>.unmodifiable(
        modulationBindings,
      ),
      eventBindings: List<RuntimeEventBinding>.unmodifiable(eventBindings),
    );
  }

  List<RuntimeEventBinding> _buildEventBindings(
    List<EventConfig> events,
    List<RuntimeModulationBinding> modulationBindings,
  ) {
    if (events.isEmpty) {
      return const <RuntimeEventBinding>[];
    }

    final modulationById = <String, RuntimeModulationBinding>{
      for (final modulation in modulationBindings) modulation.id: modulation,
    };

    final bindings = <RuntimeEventBinding>[];
    for (final event in events) {
      final actions = <RuntimeEventAction>[];
      for (final action in event.actions) {
        final modulation = modulationById[action.modulatorId];
        if (modulation == null) {
          throw StateError(
            'Unable to resolve event action modulator ${action.modulatorId}.',
          );
        }

        actions.add(
          RuntimeEventAction(mode: action.mode, modulation: modulation),
        );
      }

      bindings.add(
        RuntimeEventBinding(
          id: event.id,
          type: event.trigger.type,
          rate: event.trigger.rate,
          actions: List<RuntimeEventAction>.unmodifiable(actions),
        ),
      );
    }

    return bindings;
  }

  List<RuntimeModulationBinding> _buildModulationBindings(
    List<ModulationConfig> modulations,
    List<ResolvedModulationTarget> resolvedTargets,
  ) {
    final byId = <String, List<ResolvedModulationTarget>>{};
    for (final target in resolvedTargets) {
      byId
          .putIfAbsent(target.modulationId, () => <ResolvedModulationTarget>[])
          .add(target);
    }

    final bindings = <RuntimeModulationBinding>[];
    for (final modulation in modulations) {
      final targetsForMod =
          byId[modulation.id] ?? const <ResolvedModulationTarget>[];
      if (targetsForMod.isEmpty) {
        continue;
      }

      final modulator = ModulatorFactory.create(modulation, _sampleRate);
      final targetBindings = targetsForMod
          .map(
            (target) => ModulationTargetBinding(
              parameter: target.reference.parameter,
              amount: target.amount,
              mode: target.mode,
              minValue: target.minValue,
              maxValue: target.maxValue,
            ),
          )
          .toList(growable: false);

      bindings.add(
        RuntimeModulationBinding(
          id: modulation.id,
          modulator: modulator,
          amount: modulation.amount,
          targets: targetBindings,
        ),
      );
    }

    return bindings;
  }

  List<ResolvedModulationTarget> _resolveModulationTargets(
    List<ModulationConfig> modulations,
    ParameterRegistry registry,
  ) {
    final targets = <ResolvedModulationTarget>[];

    for (final modulation in modulations) {
      for (final target in modulation.targets) {
        final reference = registry.resolvePath(target.path);
        if (reference == null) {
          throw StateError(
            'Unable to resolve modulation target path ${target.path}.',
          );
        }

        targets.add(
          ResolvedModulationTarget(
            modulationId: modulation.id,
            targetPath: target.path,
            amount: target.amount,
            mode: target.mode,
            minValue: target.minValue,
            maxValue: target.maxValue,
            reference: reference,
          ),
        );
      }
    }

    return targets;
  }

  void _registerSourceParameters(
    String layerId,
    SourceNode source,
    ParameterRegistry registry,
  ) {
    final nodeId = source.id;

    if (source is NoiseSourceNode) {
      registry.register(
        nodeId,
        'bandLow',
        source.parameters['bandLow']!,
        pathAliases: <String>['layers[$layerId].source.noise.band.low'],
      );
      registry.register(
        nodeId,
        'bandHigh',
        source.parameters['bandHigh']!,
        pathAliases: <String>['layers[$layerId].source.noise.band.high'],
      );
      return;
    }

    if (source is SineSourceNode) {
      registry.register(
        nodeId,
        'frequencyHz',
        source.parameters['frequencyHz']!,
        pathAliases: <String>['layers[$layerId].source.sine.frequencyHz'],
      );
      registry.register(
        nodeId,
        'phase',
        source.parameters['phase']!,
        pathAliases: <String>['layers[$layerId].source.sine.phase'],
      );
      return;
    }

    if (source is ImpulseSourceNode) {
      registry.register(
        nodeId,
        'density',
        source.parameters['density']!,
        pathAliases: <String>['layers[$layerId].source.impulse.density'],
      );
      registry.register(
        nodeId,
        'randomness',
        source.parameters['randomness']!,
        pathAliases: <String>['layers[$layerId].source.impulse.randomness'],
      );
    }
  }

  void _registerProcessorParameters(
    String layerId,
    String processorId,
    ProcessorNode processor,
    ParameterRegistry registry,
  ) {
    final nodeId = processor.id;

    if (processor is BiquadProcessorNode) {
      registry.register(
        nodeId,
        'frequency',
        processor.parameters['frequency']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].biquad.frequency',
        ],
      );
      registry.register(
        nodeId,
        'q',
        processor.parameters['q']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].biquad.q',
        ],
      );
      registry.register(
        nodeId,
        'gainDb',
        processor.parameters['gainDb']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].biquad.gainDb',
        ],
      );
      return;
    }

    if (processor is GainProcessorNode) {
      registry.register(
        nodeId,
        'gain',
        processor.parameters['gain']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].gain.gain',
        ],
      );
      return;
    }

    if (processor is SaturatorProcessorNode) {
      registry.register(
        nodeId,
        'drive',
        processor.parameters['drive']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].saturator.drive',
        ],
      );
      return;
    }

    if (processor is DelayProcessorNode) {
      registry.register(
        nodeId,
        'delayTimeMs',
        processor.parameters['delayTimeMs']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].delay.delayTimeMs',
        ],
      );
      registry.register(
        nodeId,
        'feedback',
        processor.parameters['feedback']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].delay.feedback',
        ],
      );
      registry.register(
        nodeId,
        'mix',
        processor.parameters['mix']!,
        pathAliases: <String>[
          'layers[$layerId].processors[$processorId].delay.mix',
        ],
      );
    }
  }
}
