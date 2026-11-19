import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stats_models.dart';

Offset? extractLocal(FlTouchEvent e) {
  if (e is FlTapUpEvent) return e.localPosition;
  if (e is FlTapDownEvent) return e.localPosition;
  if (e is FlLongPressStart) return e.localPosition;
  if (e is FlLongPressMoveUpdate) return e.localPosition;
  if (e is FlPanDownEvent) return e.localPosition;
  if (e is FlPanUpdateEvent) return e.localPosition;
  if (e is FlPointerHoverEvent) return e.localPosition;
  return null;
}

class ChartWithTooltipOverlay extends StatelessWidget {
  final BucketTooltip? tooltip;
  final VoidCallback onDismiss;
  final Widget child;
  const ChartWithTooltipOverlay({
    super.key,
    required this.tooltip,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (tooltip != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
        if (tooltip != null)
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _TooltipLayoutDelegate(
                anchor: tooltip!.anchor,
                screenPadding: 16.0,
              ),
              child: _TooltipBubble(data: tooltip!),
            ),
          ),
      ],
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  final BucketTooltip data;
  const _TooltipBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 160,
          maxWidth: 240,
          maxHeight: 400,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final it in data.items) _TooltipRow(item: it),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final TooltipItem item;
  const _TooltipRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item.valueHms,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchor;
  final double screenPadding;

  _TooltipLayoutDelegate({required this.anchor, this.screenPadding = 8.0});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: 0,
      maxWidth: constraints.maxWidth,
      minHeight: 0,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Center horizontally on anchor
    double left = anchor.dx - (childSize.width / 2);

    // Ensure it doesn't go off the left/right edges
    if (left < screenPadding) left = screenPadding;
    if (left + childSize.width > size.width - screenPadding) {
      left = size.width - childSize.width - screenPadding;
    }

    // Position vertically
    double top;
    if (anchor.dy < size.height / 2) {
      // Show below
      top = anchor.dy + 12;
    } else {
      // Show above
      top = anchor.dy - childSize.height - 12;
    }

    // Ensure it doesn't go off the top/bottom edges
    if (top < screenPadding) top = screenPadding;
    if (top + childSize.height > size.height - screenPadding) {
      top = size.height - childSize.height - screenPadding;
    }

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor;
  }
}
