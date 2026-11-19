import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/stats_models.dart';
import '../stats_format.dart';

class PieChartWithTooltip extends StatefulWidget {
  final int totalSeconds;
  final List<Slice> slices;
  final SliceTooltip? tooltip;
  final void Function(SliceTooltip)? onSliceTap;
  final VoidCallback onDismiss;

  const PieChartWithTooltip({
    super.key,
    required this.totalSeconds,
    required this.slices,
    required this.tooltip,
    required this.onSliceTap,
    required this.onDismiss,
  });

  @override
  State<PieChartWithTooltip> createState() => _PieChartWithTooltipState();
}

class _PieChartWithTooltipState extends State<PieChartWithTooltip> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 300,
            child: LayoutBuilder(builder: _chartStack),
          ),
        ],
      ),
    );
  }

  Widget _chartStack(BuildContext context, BoxConstraints constraints) {
    final position = _tooltipPosition(constraints);
    return Stack(
      alignment: Alignment.center,
      children: [
        _chart(context),
        if (widget.totalSeconds == 0 || widget.slices.isEmpty) _noData(context),
        if (widget.totalSeconds > 0 && widget.slices.isNotEmpty)
          _totalLabel(context),
        if (widget.tooltip != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
        if (widget.tooltip != null)
          Positioned(
            left: position.dx,
            top: position.dy,
            child: IntrinsicWidth(
              child: IntrinsicHeight(
                child: _FadeInTooltipCard(data: widget.tooltip!),
              ),
            ),
          ),
      ],
    );
  }

  Offset _tooltipPosition(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    // Use more realistic max dimensions or better, handle it dynamically.
    // For now, let's just make the boundary checks more robust.
    const tooltipW = 160.0;
    const tooltipH = 80.0;

    final safeLocal = widget.tooltip?.local ?? Offset.zero;
    double left = safeLocal.dx - tooltipW / 2;
    double top = safeLocal.dy - tooltipH - 12;

    // Ensure it's within the LayoutBuilder constraints with some padding
    if (left < 12) left = 12;
    if (left + tooltipW > w - 12) left = w - tooltipW - 12;

    if (top < 12 && widget.tooltip != null) {
      // If it flies off top, show below the point
      top = safeLocal.dy + 12;
    }
    if (top + tooltipH > h - 12) {
      // If it flies off bottom, push it up
      top = h - tooltipH - 12;
    }

    return Offset(left, top);
  }

  Widget _chart(BuildContext context) {
    return PieChart(
      PieChartData(
        startDegreeOffset: -90,
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: _sections(context),
        pieTouchData: PieTouchData(touchCallback: _handleTouch),
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  List<PieChartSectionData> _sections(BuildContext context) {
    return widget.slices.isEmpty
        ? [
            PieChartSectionData(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withAlpha((0.6 * 255).round()),
              value: 1,
              radius: 90,
              showTitle: false,
            ),
          ]
        : [
            for (final s in widget.slices)
              () {
                final percent = widget.totalSeconds == 0
                    ? 0
                    : s.seconds / widget.totalSeconds;
                final showTitle = percent >= 0.03;
                final label = showTitle
                    ? pieSectionTitle(s.name, s.seconds, context)
                    : '';
                return PieChartSectionData(
                  color: s.color,
                  value: s.seconds.toDouble(),
                  radius: 90,
                  showTitle: showTitle,
                  title: label,
                  titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  titlePositionPercentageOffset: 0.65,
                );
              }(),
          ];
  }

  void _handleTouch(FlTouchEvent event, PieTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final touched = response?.touchedSection;
    if (touched == null) return;
    final index = touched.touchedSectionIndex;
    if (index < 0 || index >= widget.slices.length) {
      return;
    }

    final s = widget.slices[index];
    final local = event.localPosition;

    widget.onSliceTap?.call(
      SliceTooltip(local: local, id: s.id, name: s.name, seconds: s.seconds),
    );
  }

  Widget _noData(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noData,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalLabel(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.total,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fmtHMS(widget.totalSeconds),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _FadeInTooltipCard extends StatefulWidget {
  final SliceTooltip data;
  const _FadeInTooltipCard({required this.data});

  @override
  State<_FadeInTooltipCard> createState() => _FadeInTooltipCardState();
}

class _FadeInTooltipCardState extends State<_FadeInTooltipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.data.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                fmtHMS(widget.data.seconds),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
