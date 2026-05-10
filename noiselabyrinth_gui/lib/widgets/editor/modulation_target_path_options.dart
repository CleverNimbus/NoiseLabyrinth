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

List<ModulationTargetPathOption> buildModulationTargetPathOptions(
  LayerConfig layer,
) {
  return ModulationTargetCatalog.describeLayerTargets(layer)
      .map(
        (target) => ModulationTargetPathOption(
          path: target.path,
          label: target.label,
        ),
      )
      .toList(growable: false);
}
