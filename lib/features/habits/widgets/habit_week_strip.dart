import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:provider/provider.dart';

import '../habit_dates.dart';
import '../models/habit.dart';
import 'habit_frequency_text.dart';
import 'habit_week_day.dart';

class HabitWeekStrip extends StatefulWidget {
  final Habit habit;
  final List<DateTime> weekDates; // Base week dates from parent (current week)
  final Function(DateTime) onToggle;

  const HabitWeekStrip({
    super.key,
    required this.habit,
    required this.weekDates,
    required this.onToggle,
  });

  @override
  State<HabitWeekStrip> createState() => _HabitWeekStripState();
}

class _HabitWeekStripState extends State<HabitWeekStrip> {
  int _weekOffset = 0; // 0 = current week, -1 = last week, +1 = next week
  /// Tracks date keys currently being toggled (pending confirmation from service)
  final Set<String> _pendingKeys = {};

  /// Calculate the allowed minimum week offset based on habit start date
  int get _minWeekOffset {
    final now = DateTime.now();

    // Find start of current week
    final weekStart = context.read<AppState>().weekStart;
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStartOffset = weekStartOffset(today, weekStart);
    final currentWeekStart = today.subtract(
      Duration(days: currentWeekStartOffset),
    );

    // Find start of the week containing start date
    final startDate = DateTime(
      widget.habit.startDate.year,
      widget.habit.startDate.month,
      widget.habit.startDate.day,
    );
    final startWeekStartOffset = weekStartOffset(startDate, weekStart);
    final startWeekStart = startDate.subtract(
      Duration(days: startWeekStartOffset),
    );

    // Calculate weeks between these two boundaries
    final daysDiff = currentWeekStart.difference(startWeekStart).inDays;
    final weeksDiff = (daysDiff / 7).round();

    // Minimum offset is negative (going back in time)
    return -weeksDiff;
  }

  /// Maximum week offset is 1 (allow one week future)
  int get _maxWeekOffset => 1;

  /// Get the week dates for the current offset
  List<DateTime> get _currentWeekDates {
    if (_weekOffset == 0) {
      return widget.weekDates;
    }
    return widget.weekDates
        .map((d) => d.add(Duration(days: _weekOffset * 7)))
        .toList();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      // Swiped right → go to previous week
      if (_weekOffset > _minWeekOffset) {
        setState(() => _weekOffset--);
      }
    } else if (velocity < -300) {
      // Swiped left → go to next week
      if (_weekOffset < _maxWeekOffset) {
        setState(() => _weekOffset++);
      }
    }
  }

  Future<void> _handleToggle(DateTime date) async {
    // Defer state changes to the service; no optimistic UI flips to avoid stale caches.
    final key = dateKey(date);

    // Prevent double-taps on same key while pending
    if (_pendingKeys.contains(key)) return;

    // Mark as pending (NO optimistic state change - wait for service confirmation)
    setState(() => _pendingKeys.add(key));

    try {
      await widget.onToggle(date);
    } finally {
      // Remove from pending when complete (success or failure)
      // The actual state update will come via widget.habit.last7 from stream
      if (mounted) {
        setState(() => _pendingKeys.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week navigation row with arrows and date range
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left arrow (go to previous week)
            _buildArrow(
              Icons.chevron_left,
              _weekOffset > _minWeekOffset
                  ? () => setState(() => _weekOffset--)
                  : null,
            ),
            // Week date range label
            Expanded(child: Center(child: _buildRangeLabel())),
            // Right arrow (go to next week)
            _buildArrow(
              Icons.chevron_right,
              _weekOffset < _maxWeekOffset
                  ? () => setState(() => _weekOffset++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Swipeable 7-day row
        _buildDays(),
      ],
    );
  }

  Widget _buildArrow(IconData icon, VoidCallback? onTap) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildRangeLabel() {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _weekOffset == 0
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _weekOffset == 0
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Text(
        formatWeekRange(_currentWeekDates),
        style: theme.textTheme.labelSmall?.copyWith(
          color: _weekOffset == 0
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: _weekOffset == 0 ? FontWeight.bold : FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDays() {
    return GestureDetector(
      onHorizontalDragEnd: _handleSwipe,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _currentWeekDates.map((date) {
            return HabitWeekDay(
              habit: widget.habit,
              date: date,
              isSaving: _pendingKeys.contains(dateKey(date)),
              onTap: () => _handleToggle(date),
            );
          }).toList(),
        ),
      ),
    );
  }
}
