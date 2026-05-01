import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:noiselabyrinth_core/models/configs/band_config.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_core/models/configs/layer_config.dart';
import 'package:noiselabyrinth_core/models/configs/metadata_config.dart';
import 'package:noiselabyrinth_core/models/configs/mix_config.dart';
import 'package:noiselabyrinth_core/models/configs/modulation_config.dart';
import 'package:noiselabyrinth_core/models/configs/processor_config.dart';
import 'package:noiselabyrinth_core/models/configs/render_config.dart';
import 'package:noiselabyrinth_core/models/configs/source_config.dart';
import 'package:noiselabyrinth_core/models/enums.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _effectsLayerIndex = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final profile = store.activeProfile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No profile selected')));
    }

    final config = profile.config;
    final layers = config.layers;
    if (_effectsLayerIndex >= layers.length) {
      _effectsLayerIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Editor • ${config.metadata.name}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open Player',
            onPressed: () {
              store.setSelectedTab(3);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _OverviewSection(
            config: config,
            onChanged: (updated) => store.updateActiveProfile(updated),
          ),
          const SizedBox(height: 12),
          _LayersSection(
            layers: layers,
            onAddLayer: () {
              final newLayers = <LayerConfig>[
                ...layers,
                LayerConfig(
                  id: 'layer_${DateTime.now().millisecondsSinceEpoch}',
                  gain: 0.5,
                  pan: 0.0,
                  source: const SourceConfig(
                    type: SourceType.noise,
                    noiseConfig: NoiseConfig(
                      color: NoiseColor.white,
                      band: BandConfig(low: 20, high: 16000),
                    ),
                  ),
                  processors: const <ProcessorConfig>[
                    ProcessorConfig(
                      id: 'lowpass',
                      type: ProcessorType.biquad,
                      biquad: BiquadConfig(
                        biquadMode: BiquadMode.lowpass,
                        frequency: 12000,
                        q: 0.8,
                      ),
                    ),
                  ],
                ),
              ];
              store.updateActiveProfile(_withLayers(config, newLayers));
            },
            onDuplicateLayer: (index) {
              final layer = layers[index];
              final copy = LayerConfig(
                id: '${layer.id}_copy',
                gain: layer.gain,
                pan: layer.pan,
                source: layer.source,
                processors: layer.processors,
                modulations: layer.modulations,
                events: layer.events,
              );
              final next = <LayerConfig>[...layers]..insert(index + 1, copy);
              store.updateActiveProfile(_withLayers(config, next));
            },
            onDeleteLayer: (index) {
              if (layers.length == 1) {
                return;
              }
              final next = <LayerConfig>[...layers]..removeAt(index);
              store.updateActiveProfile(_withLayers(config, next));
            },
            onEditLayer: (index) async {
              final updated = await showDialog<LayerConfig>(
                context: context,
                builder: (_) => _LayerEditDialog(initial: layers[index]),
              );
              if (updated == null) {
                return;
              }
              final next = <LayerConfig>[...layers]..[index] = updated;
              store.updateActiveProfile(_withLayers(config, next));
            },
          ),
          const SizedBox(height: 12),
          _ModulationSection(
            layers: layers,
            onAddBurstModulation: (layerIndex) {
              final layer = layers[layerIndex];
              final updated = LayerConfig(
                id: layer.id,
                gain: layer.gain,
                pan: layer.pan,
                source: layer.source,
                processors: layer.processors,
                events: layer.events,
                modulations: <ModulationConfig>[
                  ...layer.modulations,
                  const ModulationConfig(
                    id: 'burst_new',
                    type: ModulationType.burst,
                    amount: 0.4,
                    burstConfig: BurstConfig(
                      durationMs: 120,
                      intensity: 0.8,
                      randomness: 0.4,
                      attackMs: 12,
                      releaseMs: 90,
                      clusterMin: 1,
                      clusterMax: 3,
                      clusterSpreadMs: 120,
                    ),
                    targets: <ModulationTargetConfig>[
                      ModulationTargetConfig(path: 'gain', amount: 0.35),
                    ],
                  ),
                ],
              );
              final nextLayers = <LayerConfig>[...layers]
                ..[layerIndex] = updated;
              store.updateActiveProfile(_withLayers(config, nextLayers));
            },
          ),
          const SizedBox(height: 12),
          _EffectsSection(
            layers: layers,
            selectedLayerIndex: _effectsLayerIndex,
            onSelectLayer: (index) =>
                setState(() => _effectsLayerIndex = index),
            onReorder: (oldIndex, newIndex) {
              final layer = layers[_effectsLayerIndex];
              final processors = <ProcessorConfig>[...layer.processors];
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = processors.removeAt(oldIndex);
              processors.insert(newIndex, item);
              final updatedLayer = LayerConfig(
                id: layer.id,
                gain: layer.gain,
                pan: layer.pan,
                source: layer.source,
                processors: processors,
                modulations: layer.modulations,
                events: layer.events,
              );
              final updatedLayers = <LayerConfig>[...layers]
                ..[_effectsLayerIndex] = updatedLayer;
              store.updateActiveProfile(_withLayers(config, updatedLayers));
            },
            onAddEffect: () {
              final layer = layers[_effectsLayerIndex];
              final updatedLayer = LayerConfig(
                id: layer.id,
                gain: layer.gain,
                pan: layer.pan,
                source: layer.source,
                modulations: layer.modulations,
                events: layer.events,
                processors: <ProcessorConfig>[
                  ...layer.processors,
                  const ProcessorConfig(
                    id: 'gain_boost',
                    type: ProcessorType.gain,
                    gain: GainConfig(gain: 1.1),
                  ),
                ],
              );
              final updatedLayers = <LayerConfig>[...layers]
                ..[_effectsLayerIndex] = updatedLayer;
              store.updateActiveProfile(_withLayers(config, updatedLayers));
            },
          ),
        ],
      ),
    );
  }

  GenerationConfig _withLayers(
    GenerationConfig config,
    List<LayerConfig> layers,
  ) {
    return GenerationConfig(
      metadata: config.metadata,
      render: config.render,
      mix: config.mix,
      layers: layers,
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.config, required this.onChanged});

  final GenerationConfig config;
  final ValueChanged<GenerationConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: config.metadata.name,
              decoration: const InputDecoration(labelText: 'Profile Name'),
              onFieldSubmitted: (value) {
                onChanged(
                  GenerationConfig(
                    metadata: MetadataConfig(
                      name: value.trim().isEmpty
                          ? config.metadata.name
                          : value.trim(),
                      description: config.metadata.description,
                      tags: config.metadata.tags,
                      version: config.metadata.version,
                    ),
                    render: config.render,
                    mix: config.mix,
                    layers: config.layers,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: config.metadata.description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              onFieldSubmitted: (value) {
                onChanged(
                  GenerationConfig(
                    metadata: MetadataConfig(
                      name: config.metadata.name,
                      description: value,
                      tags: config.metadata.tags,
                      version: config.metadata.version,
                    ),
                    render: config.render,
                    mix: config.mix,
                    layers: config.layers,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _NumericChip(
                  label: 'Duration',
                  value: config.render.durationMinutes,
                  suffix: 'min',
                  onChanged: (value) {
                    onChanged(
                      GenerationConfig(
                        metadata: config.metadata,
                        render: RenderConfig(
                          durationMinutes: value,
                          sampleRate: config.render.sampleRate,
                          bitRate: config.render.bitRate,
                          format: config.render.format,
                        ),
                        mix: config.mix,
                        layers: config.layers,
                      ),
                    );
                  },
                ),
                _NumericChip(
                  label: 'Sample Rate',
                  value: config.render.sampleRate,
                  suffix: 'Hz',
                  onChanged: (value) {
                    onChanged(
                      GenerationConfig(
                        metadata: config.metadata,
                        render: RenderConfig(
                          durationMinutes: config.render.durationMinutes,
                          sampleRate: value,
                          bitRate: config.render.bitRate,
                          format: config.render.format,
                        ),
                        mix: config.mix,
                        layers: config.layers,
                      ),
                    );
                  },
                ),
                _NumericChip(
                  label: 'Bitrate',
                  value: config.render.bitRate,
                  suffix: 'kbps',
                  onChanged: (value) {
                    onChanged(
                      GenerationConfig(
                        metadata: config.metadata,
                        render: RenderConfig(
                          durationMinutes: config.render.durationMinutes,
                          sampleRate: config.render.sampleRate,
                          bitRate: value,
                          format: config.render.format,
                        ),
                        mix: config.mix,
                        layers: config.layers,
                      ),
                    );
                  },
                ),
                _NumericChip(
                  label: 'Master Mix',
                  value: (config.mix.mix * 100).round(),
                  suffix: '%',
                  onChanged: (value) {
                    onChanged(
                      GenerationConfig(
                        metadata: config.metadata,
                        render: config.render,
                        mix: MixConfig(mix: value.clamp(0, 100) / 100),
                        layers: config.layers,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LayersSection extends StatelessWidget {
  const _LayersSection({
    required this.layers,
    required this.onAddLayer,
    required this.onDuplicateLayer,
    required this.onDeleteLayer,
    required this.onEditLayer,
  });

  final List<LayerConfig> layers;
  final VoidCallback onAddLayer;
  final ValueChanged<int> onDuplicateLayer;
  final ValueChanged<int> onDeleteLayer;
  final ValueChanged<int> onEditLayer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Noise Layers',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${layers.length} configured layer(s)'),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List<Widget>.generate(layers.length, (index) {
                final layer = layers[index];
                final noiseColor =
                    layer.source.noiseConfig?.color.name ??
                    layer.source.type.name;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          layer.id,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type: $noiseColor • Gain: ${layer.gain.toStringAsFixed(2)} • Pan: ${layer.pan.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: () => onEditLayer(index),
                              icon: const Icon(Icons.tune),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: () => onDuplicateLayer(index),
                              icon: const Icon(Icons.copy),
                              label: const Text('Duplicate'),
                            ),
                            TextButton.icon(
                              onPressed: () => onDeleteLayer(index),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: onAddLayer,
              icon: const Icon(Icons.add),
              label: const Text('Add Layer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulationSection extends StatelessWidget {
  const _ModulationSection({
    required this.layers,
    required this.onAddBurstModulation,
  });

  final List<LayerConfig> layers;
  final ValueChanged<int> onAddBurstModulation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Modulation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('LFO, Envelope, Burst overview and quick add'),
        children: <Widget>[
          for (var layerIndex = 0; layerIndex < layers.length; layerIndex++)
            ListTile(
              title: Text(layers[layerIndex].id),
              subtitle: Text(
                '${layers[layerIndex].modulations.length} modulation(s)',
              ),
              trailing: TextButton.icon(
                onPressed: () => onAddBurstModulation(layerIndex),
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Add Burst'),
              ),
            ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.all(12),
            child: _BurstPreviewWidget(),
          ),
        ],
      ),
    );
  }
}

class _EffectsSection extends StatelessWidget {
  const _EffectsSection({
    required this.layers,
    required this.selectedLayerIndex,
    required this.onSelectLayer,
    required this.onReorder,
    required this.onAddEffect,
  });

  final List<LayerConfig> layers;
  final int selectedLayerIndex;
  final ValueChanged<int> onSelectLayer;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAddEffect;

  @override
  Widget build(BuildContext context) {
    final processors = layers[selectedLayerIndex].processors;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Effects Chain',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('DAW-style vertical stack with reorder'),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: DropdownButtonFormField<int>(
              initialValue: selectedLayerIndex,
              items: List<DropdownMenuItem<int>>.generate(
                layers.length,
                (index) => DropdownMenuItem<int>(
                  value: index,
                  child: Text(layers[index].id),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  onSelectLayer(value);
                }
              },
              decoration: const InputDecoration(labelText: 'Layer'),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: processors.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final processor = processors[index];
              return ListTile(
                key: ValueKey('${processor.id}_$index'),
                title: Text(processor.id),
                subtitle: Text(processor.type.name),
                trailing: const Icon(Icons.drag_indicator),
              );
            },
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: onAddEffect,
              icon: const Icon(Icons.add),
              label: const Text('Add Effect'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumericChip extends StatelessWidget {
  const _NumericChip({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text('$label: $value $suffix'),
      onPressed: () async {
        final controller = TextEditingController(text: '$value');
        final parsed = await showDialog<int>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Set $label'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Value'),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final next = int.tryParse(controller.text.trim());
                    Navigator.of(context).pop(next);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
        if (parsed != null && parsed > 0) {
          onChanged(parsed);
        }
      },
    );
  }
}

class _LayerEditDialog extends StatefulWidget {
  const _LayerEditDialog({required this.initial});

  final LayerConfig initial;

  @override
  State<_LayerEditDialog> createState() => _LayerEditDialogState();
}

class _LayerEditDialogState extends State<_LayerEditDialog> {
  late double _gain;
  late double _pan;
  late SourceType _sourceType;
  late NoiseColor _noiseColor;
  late int _bandLow;
  late int _bandHigh;

  @override
  void initState() {
    super.initState();
    _gain = widget.initial.gain;
    _pan = widget.initial.pan;
    _sourceType = widget.initial.source.type;
    _noiseColor = widget.initial.source.noiseConfig?.color ?? NoiseColor.white;
    _bandLow = widget.initial.source.noiseConfig?.band.low ?? 20;
    _bandHigh = widget.initial.source.noiseConfig?.band.high ?? 16000;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Layer Detail • ${widget.initial.id}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Generator',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<SourceType>(
                initialValue: _sourceType,
                items: SourceType.values
                    .map(
                      (value) => DropdownMenuItem<SourceType>(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _sourceType = value ?? _sourceType),
                decoration: const InputDecoration(labelText: 'Source Type'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<NoiseColor>(
                initialValue: _noiseColor,
                items: NoiseColor.values
                    .map(
                      (value) => DropdownMenuItem<NoiseColor>(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _noiseColor = value ?? _noiseColor),
                decoration: const InputDecoration(labelText: 'Noise Color'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Spectral Shaping',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_bandLow',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Band Low (Hz)',
                      ),
                      onChanged: (value) =>
                          _bandLow = int.tryParse(value) ?? _bandLow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_bandHigh',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Band High (Hz)',
                      ),
                      onChanged: (value) =>
                          _bandHigh = int.tryParse(value) ?? _bandHigh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Spatial',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Gain: ${_gain.toStringAsFixed(2)}'),
              Slider(
                value: _gain,
                min: 0,
                max: 1.2,
                onChanged: (value) => setState(() => _gain = value),
              ),
              Text('Pan: ${_pan.toStringAsFixed(2)}'),
              Slider(
                value: _pan,
                min: -1,
                max: 1,
                onChanged: (value) => setState(() => _pan = value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final updated = LayerConfig(
              id: widget.initial.id,
              gain: _gain,
              pan: _pan,
              source: SourceConfig(
                type: _sourceType,
                noiseConfig: NoiseConfig(
                  color: _noiseColor,
                  band: BandConfig(
                    low: _bandLow.clamp(0, 20000),
                    high: _bandHigh.clamp((_bandLow + 1), 22000),
                  ),
                ),
                impulseConfig: widget.initial.source.impulseConfig,
                sineConfig: widget.initial.source.sineConfig,
              ),
              processors: widget.initial.processors,
              modulations: widget.initial.modulations,
              events: widget.initial.events,
            );
            Navigator.of(context).pop(updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BurstPreviewWidget extends StatelessWidget {
  const _BurstPreviewWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: CustomPaint(
        painter: _BurstPainter(),
        child: const Center(
          child: Text(
            'Burst timing preview',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CB4D4)),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF36507A)
      ..strokeWidth = 1;
    final wave = Paint()
      ..color = const Color(0xFF7DB9FF)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      line,
    );

    final path = Path()..moveTo(0, size.height * 0.8);
    for (double x = 0; x <= size.width; x += 8) {
      final normalized = x / size.width;
      final y =
          size.height * 0.8 -
          math.sin(normalized * 8).abs() * size.height * 0.55;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
