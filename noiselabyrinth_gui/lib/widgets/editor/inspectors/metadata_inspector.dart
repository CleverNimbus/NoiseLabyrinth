import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/editor/inspector_helpers.dart';

class MetadataInspector extends ConsumerStatefulWidget {
  const MetadataInspector({super.key, required this.metadata});
  final MetadataConfig metadata;

  @override
  ConsumerState<MetadataInspector> createState() => _MetadataInspectorState();
}

class _MetadataInspectorState extends ConsumerState<MetadataInspector> {
  late MetadataConfig _local;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _local = MetadataConfig(
      name: widget.metadata.name,
      description: widget.metadata.description,
      tags: List<String>.from(widget.metadata.tags),
      version: widget.metadata.version,
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _commit() {
    ref.read(editorNotifierProvider.notifier).updateMetadata(_local);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorSection(
          title: 'IDENTITY',
          children: [
            LabeledTextField(
              label: 'Name',
              value: _local.name,
              hint: 'Preset name',
              onChanged: (v) {
                setState(() => _local.name = v);
                _commit();
              },
            ),
            LabeledTextField(
              label: 'Description',
              value: _local.description,
              hint: 'Optional description',
              onChanged: (v) {
                setState(() => _local.description = v);
                _commit();
              },
            ),
          ],
        ),
        InspectorSection(
          title: 'TAGS',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _local.tags)
                  Chip(
                    label: Text(tag, style: Theme.of(context).textTheme.bodySmall),
                    deleteIcon: const Icon(Icons.close, size: 12),
                    onDeleted: () {
                      setState(() => _local.tags.remove(tag));
                      _commit();
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Add tag...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                    onFieldSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add tag',
                  onPressed: () => _addTag(_tagController.text),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        InspectorSection(
          title: 'VERSION',
          children: [
            LabeledIntField(
              label: 'Version',
              value: _local.version,
              min: 0,
              onChanged: (v) {
                setState(() => _local.version = v);
                _commit();
              },
            ),
          ],
        ),
      ],
    );
  }

  void _addTag(String text) {
    final tag = text.trim();
    if (tag.isEmpty || _local.tags.contains(tag)) return;
    setState(() {
      _local.tags.add(tag);
      _tagController.clear();
    });
    _commit();
  }
}
