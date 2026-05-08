import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

class GenerationMergeException implements Exception {
  const GenerationMergeException(this.message);

  final String message;

  @override
  String toString() => 'GenerationMergeException: $message';
}

class GenerationMergeContext {
  const GenerationMergeContext(this.configs);

  final List<GenerationConfig> configs;
}

class GenerationMergeDraft {
  MetadataConfig? metadata;
  RenderConfig? render;
  MixConfig? mix;
  final List<LayerConfig> layers = <LayerConfig>[];

  GenerationConfig build() {
    final metadata = this.metadata;
    final render = this.render;
    final mix = this.mix;

    if (metadata == null || render == null || mix == null) {
      throw const GenerationMergeException(
        'Merge rules did not produce metadata, render, and mix sections.',
      );
    }

    return GenerationConfig(
      metadata: metadata,
      render: render,
      mix: mix,
      layers: List<LayerConfig>.unmodifiable(layers),
    );
  }
}

abstract class GenerationMergeRule {
  const GenerationMergeRule();

  String get id;

  void apply(GenerationMergeContext context, GenerationMergeDraft draft);
}

class GenerationsMerger {
  const GenerationsMerger({
    required this.parser,
    this.rules = defaultGenerationMergeRules,
  });

  static const List<GenerationMergeRule> defaultGenerationMergeRules = <GenerationMergeRule>[
    _MinimumInputCountRule(),
    _MetadataMergeRule(),
    _RenderMergeRule(),
    _MixMergeRule(),
    _LayerMergeRule(),
  ];

  final GenerationConfigParser parser;
  final List<GenerationMergeRule> rules;

  GenerationConfig merge(
    GenerationConfig first,
    GenerationConfig second, [
    List<GenerationConfig> rest = const <GenerationConfig>[],
  ]) {
    return mergeAll(<GenerationConfig>[
      first,
      second,
      ...rest,
    ]);
  }

  GenerationConfig mergeAll(Iterable<GenerationConfig> configs) {
    final configList = List<GenerationConfig>.unmodifiable(configs);
    _validateInputs(configList);

    final context = GenerationMergeContext(configList);
    final draft = GenerationMergeDraft();

    for (final rule in rules) {
      rule.apply(context, draft);
    }

    final merged = draft.build();
    final issues = parser.validate(merged);
    if (issues.isNotEmpty) {
      throw ConfigValidationException(issues);
    }

    return merged;
  }

  void _validateInputs(List<GenerationConfig> configs) {
    for (var i = 0; i < configs.length; i++) {
      final issues = parser.validate(configs[i]);
      if (issues.isNotEmpty) {
        throw ConfigValidationException(
          issues
              .map(
                (issue) => ConfigValidationIssue(
                  path: 'configs[$i].${issue.path}',
                  message: issue.message,
                ),
              )
              .toList(growable: false),
        );
      }
    }
  }
}

class _MinimumInputCountRule extends GenerationMergeRule {
  const _MinimumInputCountRule();

  @override
  String get id => 'minimumInputCount';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    if (context.configs.length < 2) {
      throw const GenerationMergeException(
        'At least two generation configs are required to merge.',
      );
    }
  }
}

class _MetadataMergeRule extends GenerationMergeRule {
  const _MetadataMergeRule();

  @override
  String get id => 'metadata';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    final names = <String>[
      for (final config in context.configs)
        if (config.metadata.name.trim().isNotEmpty) config.metadata.name.trim(),
    ];
    final descriptions = <String>[
      for (final config in context.configs)
        if (config.metadata.description.trim().isNotEmpty) config.metadata.description.trim(),
    ];
    final tags = <String>{};
    for (final config in context.configs) {
      tags.addAll(config.metadata.tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty));
    }

    draft.metadata = MetadataConfig(
      name: names.join(' + '),
      description: descriptions.join('\n\n'),
      tags: <String>['merged', ...tags],
      version: context.configs
          .map((config) => config.metadata.version)
          .fold<int>(0, (max, version) => version > max ? version : max),
    );
  }
}

class _RenderMergeRule extends GenerationMergeRule {
  const _RenderMergeRule();

  @override
  String get id => 'render';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    final configs = context.configs;
    final lastRender = configs.last.render;

    draft.render = RenderConfig(
      durationMinutes: configs
          .map((config) => config.render.durationMinutes)
          .fold<int>(0, (max, value) => value > max ? value : max),
      sampleRate: configs
          .map((config) => config.render.sampleRate)
          .fold<int>(0, (max, value) => value > max ? value : max),
      bitRate: configs.map((config) => config.render.bitRate).fold<int>(0, (max, value) => value > max ? value : max),
      format: lastRender.format,
    );
  }
}

class _MixMergeRule extends GenerationMergeRule {
  const _MixMergeRule();

  @override
  String get id => 'mix';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    final total = context.configs.fold<double>(
      0,
      (sum, config) => sum + config.mix.mix,
    );

    draft.mix = MixConfig(
      dither: DitherConfig(),
      normalization: NormalizationConfig(),
      mix: total / context.configs.length,
    );
  }
}

class _LayerMergeRule extends GenerationMergeRule {
  const _LayerMergeRule();

  @override
  String get id => 'layers';

  @override
  void apply(GenerationMergeContext context, GenerationMergeDraft draft) {
    final usedLayerIds = <String>{};

    for (final config in context.configs) {
      final layerIdMapping = <String, String>{};
      for (final layer in config.layers) {
        layerIdMapping[layer.id] = _uniqueLayerId(layer.id, usedLayerIds);
      }

      for (final layer in config.layers) {
        final layerJson = Map<String, dynamic>.from(layer.toJson());
        final originalLayerId = layer.id;
        layerJson['id'] = layerIdMapping[originalLayerId];
        _rewriteLayerReferences(layerJson, layerIdMapping);
        draft.layers.add(LayerConfig.fromJson(layerJson));
      }
    }
  }

  String _uniqueLayerId(String preferredId, Set<String> usedIds) {
    if (usedIds.add(preferredId)) {
      return preferredId;
    }

    var suffix = 2;
    while (true) {
      final candidate = '$preferredId-$suffix';
      if (usedIds.add(candidate)) {
        return candidate;
      }
      suffix++;
    }
  }

  void _rewriteLayerReferences(
    Map<String, dynamic> layerJson,
    Map<String, String> layerIdMapping,
  ) {
    final modulations = layerJson['modulations'] as List<dynamic>? ?? const <dynamic>[];
    for (final modulation in modulations) {
      final modulationJson = modulation as Map<String, dynamic>;
      final targets = modulationJson['targets'] as List<dynamic>? ?? const <dynamic>[];
      for (final target in targets) {
        final targetJson = target as Map<String, dynamic>;
        final path = targetJson['path'] as String?;
        if (path == null) {
          continue;
        }

        var rewrittenPath = path;
        for (final entry in layerIdMapping.entries) {
          rewrittenPath = rewrittenPath.replaceAll(
            'layers[${entry.key}]',
            'layers[${entry.value}]',
          );
        }
        targetJson['path'] = rewrittenPath;
      }
    }
  }
}
