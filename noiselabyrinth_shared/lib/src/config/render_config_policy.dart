import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class RenderConfigPolicy {
  const RenderConfigPolicy();

  GenerationConfig forceMp3(GenerationConfig config) {
    return GenerationConfig(
      metadata: config.metadata,
      render: RenderConfig(
        durationMinutes: config.render.durationMinutes,
        sampleRate: config.render.sampleRate,
        bitRate: config.render.bitRate,
        dcBlockerEnabled: config.render.dcBlockerEnabled,
      ),
      mix: config.mix,
      layers: config.layers,
    );
  }
}
