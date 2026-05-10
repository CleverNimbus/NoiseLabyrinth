import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';

class ModulationTargetDescriptor {
  const ModulationTargetDescriptor({
    required this.path,
    required this.label,
  });

  final String path;
  final String label;
}

abstract final class ModulationTargetCatalog {
  static String layerGainPath(String layerId) => 'layers[$layerId].gain';

  static String layerPanPath(String layerId) => 'layers[$layerId].pan';

  static String noiseBandLowPath(String layerId) =>
      'layers[$layerId].source.noise.band.low';

  static String noiseBandHighPath(String layerId) =>
      'layers[$layerId].source.noise.band.high';

  static String sineFrequencyHzPath(String layerId) =>
      'layers[$layerId].source.sine.frequencyHz';

  static String sinePhasePath(String layerId) =>
      'layers[$layerId].source.sine.phase';

  static String impulseDensityPath(String layerId) =>
      'layers[$layerId].source.impulse.density';

  static String impulseRandomnessPath(String layerId) =>
      'layers[$layerId].source.impulse.randomness';

  static String biquadFrequencyPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].biquad.frequency';

  static String biquadQPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].biquad.q';

  static String biquadGainDbPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].biquad.gainDb';

  static String gainProcessorGainPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].gain.gain';

  static String saturatorDrivePath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].saturator.drive';

  static String delayTimeMsPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].delay.delayTimeMs';

  static String delayFeedbackPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].delay.feedback';

  static String delayMixPath(String layerId, String processorId) =>
      'layers[$layerId].processors[$processorId].delay.mix';

  static List<ModulationTargetDescriptor> describeLayerTargets(
    LayerConfig layer,
  ) {
    final layerId = layer.id;
    final layerLabel = layer.id;
    final targets = <ModulationTargetDescriptor>[
      ModulationTargetDescriptor(
        path: layerGainPath(layerId),
        label: '$layerLabel > Gain',
      ),
      ModulationTargetDescriptor(
        path: layerPanPath(layerId),
        label: '$layerLabel > Pan',
      ),
    ];

    switch (layer.source.type) {
      case SourceType.noise:
        if (layer.source.noiseConfig != null) {
          targets
            ..add(
              ModulationTargetDescriptor(
                path: noiseBandLowPath(layerId),
                label: '$layerLabel > Source > Noise > Band > Low (Hz)',
              ),
            )
            ..add(
              ModulationTargetDescriptor(
                path: noiseBandHighPath(layerId),
                label: '$layerLabel > Source > Noise > Band > High (Hz)',
              ),
            );
        }
      case SourceType.impulse:
        if (layer.source.impulseConfig != null) {
          targets
            ..add(
              ModulationTargetDescriptor(
                path: impulseDensityPath(layerId),
                label: '$layerLabel > Source > Impulse > Density',
              ),
            )
            ..add(
              ModulationTargetDescriptor(
                path: impulseRandomnessPath(layerId),
                label: '$layerLabel > Source > Impulse > Randomness',
              ),
            );
        }
      case SourceType.sine:
        if (layer.source.sineConfig != null) {
          targets
            ..add(
              ModulationTargetDescriptor(
                path: sineFrequencyHzPath(layerId),
                label: '$layerLabel > Source > Sine > Frequency (Hz)',
              ),
            )
            ..add(
              ModulationTargetDescriptor(
                path: sinePhasePath(layerId),
                label: '$layerLabel > Source > Sine > Phase',
              ),
            );
        }
    }

    for (final processor in layer.processors) {
      final processorId = processor.id;
      final processorLabel = processor.id;

      switch (processor.type) {
        case ProcessorType.biquad:
          if (processor.biquad != null) {
            targets
              ..add(
                ModulationTargetDescriptor(
                  path: biquadFrequencyPath(layerId, processorId),
                  label:
                      '$layerLabel > $processorLabel > Biquad > Frequency (Hz)',
                ),
              )
              ..add(
                ModulationTargetDescriptor(
                  path: biquadQPath(layerId, processorId),
                  label: '$layerLabel > $processorLabel > Biquad > Q',
                ),
              )
              ..add(
                ModulationTargetDescriptor(
                  path: biquadGainDbPath(layerId, processorId),
                  label: '$layerLabel > $processorLabel > Biquad > Gain (dB)',
                ),
              );
          }
        case ProcessorType.gain:
          if (processor.gain != null) {
            targets.add(
              ModulationTargetDescriptor(
                path: gainProcessorGainPath(layerId, processorId),
                label: '$layerLabel > $processorLabel > Gain',
              ),
            );
          }
        case ProcessorType.saturator:
          if (processor.saturator != null) {
            targets.add(
              ModulationTargetDescriptor(
                path: saturatorDrivePath(layerId, processorId),
                label: '$layerLabel > $processorLabel > Saturator > Drive',
              ),
            );
          }
        case ProcessorType.delay:
          if (processor.delay != null) {
            targets
              ..add(
                ModulationTargetDescriptor(
                  path: delayTimeMsPath(layerId, processorId),
                  label: '$layerLabel > $processorLabel > Delay > Time (ms)',
                ),
              )
              ..add(
                ModulationTargetDescriptor(
                  path: delayFeedbackPath(layerId, processorId),
                  label: '$layerLabel > $processorLabel > Delay > Feedback',
                ),
              )
              ..add(
                ModulationTargetDescriptor(
                  path: delayMixPath(layerId, processorId),
                  label: '$layerLabel > $processorLabel > Delay > Mix',
                ),
              );
          }
      }
    }

    return List<ModulationTargetDescriptor>.unmodifiable(targets);
  }

  static Set<String> pathsForLayer(LayerConfig layer) {
    return describeLayerTargets(layer).map((target) => target.path).toSet();
  }
}
