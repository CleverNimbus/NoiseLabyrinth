/// How an event action controls a modulator.
enum ActionMode { trigger, gate }

/// Biquad filter modes.
enum BiquadMode { lowpass, highpass, bandpass, peak }

/// Modulation source types.
enum ModulationType { lfo, random, drift, envelope, burst }

/// How modulation is applied to a target parameter value.
enum ModulationApplyMode { additive, multiplicative }

/// Noise color algorithms.
enum NoiseColor { white, pink, brown, bandlimited }

/// Processor types available in a layer signal chain.
enum ProcessorType { biquad, gain, saturator, delay }

/// Saturation transfer curve models.
enum SaturatorCurve { soft, tanh }

/// Source generator types available for a layer.
enum SourceType { noise, impulse, sine }

/// Event trigger types.
enum TriggerType { poisson, periodic, random }

/// LFO waveform shapes.
enum LFOType { sine, triangle, square, sawtooth }

/// Output file formats for rendered audio.
enum RenderFormat { wav, mp3 }

/// Dither algorithm types.
enum DitherType { tpdf }
