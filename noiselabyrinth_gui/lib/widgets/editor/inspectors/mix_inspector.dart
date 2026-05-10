import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class MixInspector extends ConsumerWidget {
  const MixInspector({super.key, required this.mix});
  final MixConfig mix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(MixConfig m) => ref.read(editorNotifierProvider.notifier).updateMix(m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'MASTER MIX',
          children: [
            LabeledSlider(
              label: 'Mix',
              value: mix.mix,
              min: 0,
              max: 1,
              displayValue: mix.mix.toStringAsFixed(2),
              onChanged: (v) => update(_copyMix(mix, mixLevel: v)),
            ),
          ],
        ),
        InspectorSection(
          title: 'DITHER',
          children: [
            LabeledSwitch(
              label: 'Enabled',
              value: mix.dither.enabled,
              onChanged: (v) => update(_copyMix(mix, ditherEnabled: v)),
            ),
            if (mix.dither.enabled) ...[
              LabeledDropdown<DitherType>(
                label: 'Algorithm',
                value: mix.dither.type,
                items: DitherType.values,
                itemLabel: (t) => t.name.toUpperCase(),
                onChanged: (v) => update(_copyMix(mix, ditherType: v)),
              ),
              LabeledIntField(
                label: 'Bit Depth',
                value: mix.dither.bitDepth,
                min: 1,
                max: 32,
                onChanged: (v) => update(_copyMix(mix, ditherBitDepth: v)),
              ),
              LabeledSlider(
                label: 'Amount',
                value: mix.dither.amount,
                min: 0,
                max: 2,
                displayValue: mix.dither.amount.toStringAsFixed(2),
                onChanged: (v) => update(_copyMix(mix, ditherAmount: v)),
              ),
            ],
          ],
        ),
        InspectorSection(
          title: 'NORMALIZATION',
          children: [
            LabeledSwitch(
              label: 'Enabled',
              value: mix.normalization.enabled,
              onChanged: (v) => update(_copyMix(mix, normEnabled: v)),
            ),
            if (mix.normalization.enabled)
              LabeledSlider(
                label: 'Target (dBFS)',
                value: mix.normalization.targetDb,
                min: -120,
                max: 0,
                displayValue: '${mix.normalization.targetDb.toStringAsFixed(1)} dB',
                onChanged: (v) => update(_copyMix(mix, normTargetDb: v)),
              ),
          ],
        ),
      ],
    );
  }

  MixConfig _copyMix(
    MixConfig m, {
    double? mixLevel,
    bool? ditherEnabled,
    DitherType? ditherType,
    int? ditherBitDepth,
    double? ditherAmount,
    bool? normEnabled,
    double? normTargetDb,
  }) {
    final dither = DitherConfig(
      enabled: ditherEnabled ?? m.dither.enabled,
      type: ditherType ?? m.dither.type,
      bitDepth: ditherBitDepth ?? m.dither.bitDepth,
      amount: ditherAmount ?? m.dither.amount,
    );
    final norm = NormalizationConfig(
      enabled: normEnabled ?? m.normalization.enabled,
      targetDb: normTargetDb ?? m.normalization.targetDb,
    );
    return MixConfig(mix: mixLevel ?? m.mix, dither: dither, normalization: norm);
  }
}
