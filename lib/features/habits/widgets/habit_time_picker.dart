import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class HabitTimePicker extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final double maxValue;

  const HabitTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.maxValue = 86399.0, // 23:59:59
  });

  @override
  State<HabitTimePicker> createState() => _HabitTimePickerState();
}

class _HabitTimePickerState extends State<HabitTimePicker> {
  Timer? _incrementTimer;

  void _startAdjusting(double step) {
    _stopAdjusting();
    _adjustValue(step);

    int count = 0;
    void tick() {
      _incrementTimer = Timer(_getTickDuration(count), () {
        _adjustValue(step);
        HapticFeedback.selectionClick();
        count++;
        tick();
      });
    }

    tick();
  }

  Duration _getTickDuration(int count) {
    if (count > 25) return const Duration(milliseconds: 40);
    if (count > 15) return const Duration(milliseconds: 80);
    if (count > 5) return const Duration(milliseconds: 120);
    return const Duration(milliseconds: 250);
  }

  void _stopAdjusting() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
  }

  void _adjustValue(double step) {
    final newValue = (widget.value + step).clamp(0.0, widget.maxValue);
    if (newValue != widget.value) {
      widget.onChanged(newValue);
    }
  }

  @override
  void dispose() {
    _incrementTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final h = widget.value ~/ 3600;
    final m = (widget.value % 3600) ~/ 60;
    final s = widget.value % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(
          h.toInt().toString().padLeft(2, '0'),
          l10n.habitTimeHourShort,
          3600,
          theme,
        ),
        _buildTimeSeparator(theme),
        _buildTimeUnit(
          m.toInt().toString().padLeft(2, '0'),
          l10n.habitTimeMinuteShort,
          60,
          theme,
        ),
        _buildTimeSeparator(theme),
        _buildTimeUnit(
          s.toInt().toString().padLeft(2, '0'),
          l10n.habitTimeSecondShort,
          1,
          theme,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => widget.onChanged(0),
          icon: Icon(
            Icons.refresh,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          tooltip: l10n.habitClearTime,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }

  Widget _buildTimeUnit(
    String val,
    String label,
    double step,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTapDown: (_) {
        _startAdjusting(step);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _stopAdjusting(),
      onTapCancel: () => _stopAdjusting(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          val,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSeparator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ":",
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
