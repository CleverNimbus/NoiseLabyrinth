import 'package:flutter/material.dart';

class TreeItemAction {
  const TreeItemAction({required this.icon, required this.tooltip, required this.onPressed, this.isDestructive = true});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDestructive;
}

class StructureTreeItem extends StatelessWidget {
  const StructureTreeItem({
    super.key,
    required this.label,
    required this.icon,
    required this.depth,
    this.isSelected = false,
    this.isExpandable = false,
    this.isExpanded = false,
    this.hasError = false,
    this.isPreviewDisabled = false,
    this.onTap,
    this.onToggleExpand,
    this.trailingActions = const [],
  });

  final String label;
  final IconData icon;
  final int depth;
  final bool isSelected;
  final bool isExpandable;
  final bool isExpanded;
  final bool hasError;
  final bool isPreviewDisabled;
  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;
  final List<TreeItemAction> trailingActions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final indent = 8.0 + (depth * 16.0);
    final selectedBg = colorScheme.primary.withValues(alpha: 0.12);
    final hoverBg = colorScheme.onSurface.withValues(alpha: 0.06);

    final disabledOpacity = isPreviewDisabled ? 0.45 : 1.0;

    final iconColor = hasError
        ? colorScheme.error
        : isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final labelStyle = textTheme.bodySmall?.copyWith(
      color: hasError
          ? colorScheme.error
          : isSelected
          ? colorScheme.primary
          : colorScheme.onSurface,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: hoverBg,
        child: Container(
          height: 28,
          decoration: isSelected
              ? BoxDecoration(
                  color: selectedBg,
                  border: Border(left: BorderSide(color: colorScheme.primary, width: 2)),
                )
              : null,
          child: Row(
            children: [
              SizedBox(width: indent),

              Expanded(
                child: Opacity(
                  opacity: disabledOpacity,
                  child: Row(
                    children: [
                      // Expand/collapse toggle
                      if (isExpandable)
                        GestureDetector(
                          onTap: onToggleExpand,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isExpanded ? Icons.expand_more : Icons.chevron_right,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 22),

                      // Node icon
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),

                      // Label
                      Expanded(
                        child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Error indicator
              if (hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.warning_amber_rounded, size: 12, color: colorScheme.error),
                ),

              // Trailing action buttons (shown on hover via Hoverable)
              for (final action in trailingActions) _HoverableAction(action: action),

              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverableAction extends StatefulWidget {
  const _HoverableAction({required this.action});
  final TreeItemAction action;

  @override
  State<_HoverableAction> createState() => _HoverableActionState();
}

class _HoverableActionState extends State<_HoverableAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hoveredColor = widget.action.isDestructive ? colorScheme.error : colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.action.tooltip,
        child: GestureDetector(
          onTap: widget.action.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Icon(
              widget.action.icon,
              size: 13,
              color: _hovered ? hoveredColor : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
