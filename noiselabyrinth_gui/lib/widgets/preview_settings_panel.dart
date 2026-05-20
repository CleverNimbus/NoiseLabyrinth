import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/preview/preview_settings_state.dart';

class PreviewSettingsPanel extends ConsumerStatefulWidget {
  const PreviewSettingsPanel({super.key});

  @override
  ConsumerState<PreviewSettingsPanel> createState() => _PreviewSettingsPanelState();
}

class _PreviewSettingsPanelState extends ConsumerState<PreviewSettingsPanel> {
  late TextEditingController _previewMaxSecondsController;
  late TextEditingController _segmentSecondsController;
  late TextEditingController _minAheadSegmentsController;
  late TextEditingController _maxAheadSegmentsController;
  late TextEditingController _bufferRemainingController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(previewSettingsProvider);
    _previewMaxSecondsController = TextEditingController(text: settings.previewMaxSeconds.toString());
    _segmentSecondsController = TextEditingController(text: settings.segmentSeconds.toString());
    _minAheadSegmentsController = TextEditingController(text: settings.minAheadSegments.toString());
    _maxAheadSegmentsController = TextEditingController(text: settings.maxAheadSegments.toString());
    _bufferRemainingController = TextEditingController(
      text: settings.bufferRemainingFractionToRefill.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _previewMaxSecondsController.dispose();
    _segmentSecondsController.dispose();
    _minAheadSegmentsController.dispose();
    _maxAheadSegmentsController.dispose();
    _bufferRemainingController.dispose();
    super.dispose();
  }

  void _updatePreviewMaxSeconds(String value) {
    final seconds = int.tryParse(value);
    if (seconds != null && seconds > 0) {
      ref.read(previewSettingsProvider.notifier).setPreviewMaxSeconds(seconds);
    }
  }

  void _updateSegmentSeconds(String value) {
    final seconds = int.tryParse(value);
    if (seconds != null && seconds > 0) {
      ref.read(previewSettingsProvider.notifier).setSegmentSeconds(seconds);
    }
  }

  void _updateMinAheadSegments(String value) {
    final segments = int.tryParse(value);
    if (segments != null && segments >= 0) {
      ref.read(previewSettingsProvider.notifier).setMinAheadSegments(segments);
    }
  }

  void _updateMaxAheadSegments(String value) {
    final segments = int.tryParse(value);
    if (segments != null && segments > 0) {
      ref.read(previewSettingsProvider.notifier).setMaxAheadSegments(segments);
    }
  }

  void _updateBufferRemaining(String value) {
    final fraction = double.tryParse(value);
    if (fraction != null && fraction >= 0 && fraction <= 1) {
      ref.read(previewSettingsProvider.notifier).setBufferRemainingFractionToRefill(fraction);
    }
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('This will restore all preview settings to their default values.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(previewSettingsProvider.notifier).resetToDefaults();
              final settings = ref.read(previewSettingsProvider);
              _previewMaxSecondsController.text = settings.previewMaxSeconds.toString();
              _segmentSecondsController.text = settings.segmentSeconds.toString();
              _minAheadSegmentsController.text = settings.minAheadSegments.toString();
              _maxAheadSegmentsController.text = settings.maxAheadSegments.toString();
              _bufferRemainingController.text = settings.bufferRemainingFractionToRefill.toStringAsFixed(2);
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Preview Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildSettingField(
                label: 'Preview Max Duration (seconds)',
                hint: 'Maximum preview duration',
                controller: _previewMaxSecondsController,
                onChanged: _updatePreviewMaxSeconds,
                suffix: 's',
                min: 1,
              ),
              const SizedBox(height: 16),
              _buildSettingField(
                label: 'Segment Duration (seconds)',
                hint: 'Duration per audio segment',
                controller: _segmentSecondsController,
                onChanged: _updateSegmentSeconds,
                suffix: 's',
                min: 1,
              ),
              const SizedBox(height: 16),
              _buildSettingField(
                label: 'Min Ahead Segments',
                hint: 'Minimum buffered segments',
                controller: _minAheadSegmentsController,
                onChanged: _updateMinAheadSegments,
                min: 0,
              ),
              const SizedBox(height: 16),
              _buildSettingField(
                label: 'Max Ahead Segments',
                hint: 'Maximum buffered segments',
                controller: _maxAheadSegmentsController,
                onChanged: _updateMaxAheadSegments,
                min: 1,
              ),
              const SizedBox(height: 16),
              _buildSettingField(
                label: 'Buffer Refill Threshold',
                hint: 'Fraction to trigger buffer refill',
                controller: _bufferRemainingController,
                onChanged: _updateBufferRemaining,
                isDouble: true,
                min: 0,
                max: 1,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Defaults'),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Function(String) onChanged,
    String? suffix,
    bool isDouble = false,
    double? min,
    double? max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isDouble ? TextInputType.number : TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffix: suffix != null ? Text(suffix) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About These Settings', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              'Preview Max Duration: Total length of preview to generate (capped by actual config duration).\n\n'
              'Segment Duration: Size of each audio chunk queued to the player.\n\n'
              'Min/Max Ahead Segments: Buffering strategy — controls how many segments to keep queued.\n\n'
              'Buffer Refill Threshold: Fraction of current segment remaining before requesting more data.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
