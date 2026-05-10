import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDirty = ref.watch(isDirtyProvider);
    final isOpen = ref.watch(isEditorOpenProvider);
    final config = ref.watch(editorNotifierProvider).config;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          // Config name / dirty indicator
          if (config != null) ...[
            Icon(Icons.tune_outlined, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              isDirty ? '${config.metadata.name} •' : config.metadata.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDirty ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
          ],

          // New
          _ToolbarButton(
            icon: Icons.add_outlined,
            tooltip: 'New Config',
            onPressed: () => ref.read(editorNotifierProvider.notifier).newConfig(),
          ),

          // Import JSON
          _ToolbarButton(
            icon: Icons.upload_file_outlined,
            tooltip: 'Import JSON',
            onPressed: () => importJson(context, ref),
          ),

          const VerticalDivider(width: 16, indent: 8, endIndent: 8),

          // Save
          _ToolbarButton(
            icon: Icons.save_outlined,
            tooltip: 'Save to Library',
            onPressed: isOpen ? () => _save(context, ref) : null,
          ),

          const Spacer(),

          // Validation badge
          _ValidationBadge(),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    await ref.read(editorNotifierProvider.notifier).saveToRepository(repo);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to library.'), duration: Duration(seconds: 2)));
    }
  }

  static Future<void> importJson(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final fileBytes = result.files.first.bytes;
    String jsonString;
    if (fileBytes != null) {
      jsonString = utf8.decode(fileBytes);
    } else {
      final path = result.files.first.path;
      if (path == null) return;
      jsonString = await File(path).readAsString();
    }

    try {
      final parser = GenerationConfigParser();
      final config = parser.parseJsonString(jsonString);
      ref.read(editorNotifierProvider.notifier).openConfig(config);
    } on ConfigValidationException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Config has ${e.issues.length} validation error(s). Opened with errors.'),
            duration: const Duration(seconds: 4),
          ),
        );
        // Still open despite validation issues (parse succeeded at json level)
        try {
          final config = GenerationConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
          ref.read(editorNotifierProvider.notifier).openConfig(config);
        } catch (_) {}
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid JSON: ${e.message}'), duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import: $e'), duration: const Duration(seconds: 4)));
      }
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
      ),
    );
  }
}

class _ValidationBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(validationIssuesProvider);
    if (issues.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Valid',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 4),
        Text(
          '${issues.length} error${issues.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}
