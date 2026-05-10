import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class RenderInspector extends ConsumerWidget {
  const RenderInspector({super.key, required this.render});
  final RenderConfig render;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(RenderConfig r) => ref.read(editorNotifierProvider.notifier).updateRender(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'OUTPUT',
          children: [
            LabeledDropdown<RenderFormat>(
              label: 'Format',
              value: render.format,
              items: RenderFormat.values,
              itemLabel: (f) => f.name.toUpperCase(),
              onChanged: (v) => update(render..format = v),
            ),
            LabeledIntField(
              label: 'Duration (min)',
              value: render.durationMinutes,
              min: 1,
              onChanged: (v) => update(render..durationMinutes = v),
            ),
          ],
        ),
        InspectorSection(
          title: 'AUDIO QUALITY',
          children: [
            LabeledDropdown<int>(
              label: 'Sample Rate',
              value: render.sampleRate,
              items: const [22050, 44100, 48000, 96000],
              itemLabel: (v) => '$v Hz',
              onChanged: (v) => update(render..sampleRate = v),
            ),
            LabeledIntField(
              label: 'Bit Rate (kbps)',
              value: render.bitRate,
              min: 64,
              max: 320,
              onChanged: (v) => update(render..bitRate = v),
            ),
          ],
        ),
        InspectorSection(
          title: 'PROCESSING',
          children: [
            LabeledSwitch(
              label: 'DC Blocker',
              value: render.dcBlockerEnabled,
              onChanged: (v) => update(render..dcBlockerEnabled = v),
            ),
          ],
        ),
      ],
    );
  }
}
