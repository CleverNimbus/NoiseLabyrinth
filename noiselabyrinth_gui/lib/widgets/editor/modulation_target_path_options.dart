import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class ModulationTargetPathOption {
  const ModulationTargetPathOption({required this.path, required this.label});

  final String path;
  final String label;

  @override
  bool operator ==(Object other) {
    return other is ModulationTargetPathOption && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => label;
}

List<ModulationTargetPathOption> buildModulationTargetPathOptions(GenerationConfig config) {
  final options = <ModulationTargetPathOption>[];

  for (var layerIndex = 0; layerIndex < config.layers.length; layerIndex++) {
    final layer = config.layers[layerIndex];
    final layerLabel = layer.id;

    options
      ..add(ModulationTargetPathOption(path: 'layers[${layer.id}].gain', label: '$layerLabel > Gain'))
      ..add(ModulationTargetPathOption(path: 'layers[${layer.id}].pan', label: '$layerLabel > Pan'));

    switch (layer.source.type) {
      case SourceType.noise:
        if (layer.source.noiseConfig != null) {
          options
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.noise.band.low',
                label: '$layerLabel > Source > Noise > Band > Low (Hz)',
              ),
            )
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.noise.band.high',
                label: '$layerLabel > Source > Noise > Band > High (Hz)',
              ),
            );
        }
      case SourceType.impulse:
        if (layer.source.impulseConfig != null) {
          options
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.impulse.density',
                label: '$layerLabel > Source > Impulse > Density',
              ),
            )
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.impulse.randomness',
                label: '$layerLabel > Source > Impulse > Randomness',
              ),
            );
        }
      case SourceType.sine:
        if (layer.source.sineConfig != null) {
          options
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.sine.frequencyHz',
                label: '$layerLabel > Source > Sine > Frequency (Hz)',
              ),
            )
            ..add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].source.sine.phase',
                label: '$layerLabel > Source > Sine > Phase',
              ),
            );
        }
    }

    for (var processorIndex = 0; processorIndex < layer.processors.length; processorIndex++) {
      final processor = layer.processors[processorIndex];
      final processorLabel = processor.id;

      switch (processor.type) {
        case ProcessorType.biquad:
          if (processor.biquad != null) {
            options
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].biquad.frequency',
                  label: '$layerLabel > $processorLabel > Biquad > Frequency (Hz)',
                ),
              )
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].biquad.q',
                  label: '$layerLabel > $processorLabel > Biquad > Q',
                ),
              )
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].biquad.gainDb',
                  label: '$layerLabel > $processorLabel > Biquad > Gain (dB)',
                ),
              );
          }
        case ProcessorType.gain:
          if (processor.gain != null) {
            options.add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].processors[${processor.id}].gain.gain',
                label: '$layerLabel > $processorLabel > Gain',
              ),
            );
          }
        case ProcessorType.saturator:
          if (processor.saturator != null) {
            options.add(
              ModulationTargetPathOption(
                path: 'layers[${layer.id}].processors[${processor.id}].saturator.drive',
                label: '$layerLabel > $processorLabel > Saturator > Drive',
              ),
            );
          }
        case ProcessorType.delay:
          if (processor.delay != null) {
            options
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].delay.delayTimeMs',
                  label: '$layerLabel > $processorLabel > Delay > Time (ms)',
                ),
              )
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].delay.feedback',
                  label: '$layerLabel > $processorLabel > Delay > Feedback',
                ),
              )
              ..add(
                ModulationTargetPathOption(
                  path: 'layers[${layer.id}].processors[${processor.id}].delay.mix',
                  label: '$layerLabel > $processorLabel > Delay > Mix',
                ),
              );
          }
      }
    }
  }

  return options;
}
