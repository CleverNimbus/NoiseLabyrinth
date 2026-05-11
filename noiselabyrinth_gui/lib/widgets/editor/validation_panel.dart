import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_state.dart';

class ValidationPanel extends ConsumerStatefulWidget {
  const ValidationPanel({super.key});

  @override
  ConsumerState<ValidationPanel> createState() => _ValidationPanelState();
}

class _ValidationPanelState extends ConsumerState<ValidationPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(validationIssuesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / toggle
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    issues.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 16,
                    color: issues.isEmpty ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    issues.isEmpty
                        ? 'No validation errors'
                        : '${issues.length} validation error${issues.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: issues.isEmpty ? colorScheme.primary : colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (issues.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${issues.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && issues.isNotEmpty)
            Flexible(
              fit: FlexFit.loose,
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: issues.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return _ValidationIssueItem(issue: issue, index: index);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ValidationIssueItem extends ConsumerWidget {
  const _ValidationIssueItem({required this.issue, required this.index});

  final EditorValidationIssue issue;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to the offending node if available.
          if (issue.node != null) {
            ref.read(editorNotifierProvider.notifier).selectNode(issue.node);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.error.withValues(alpha: 0.2)),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorScheme.error, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.path,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      issue.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ],
                ),
              ),
              if (issue.node != null) Icon(Icons.chevron_right, size: 14, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
