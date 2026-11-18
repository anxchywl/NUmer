import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/habits/models/habit.dart';
import 'package:numer_app/features/habits/widgets/habit_completion_indicator.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/app/app_state.dart';

/// A single quadrant panel in the Eisenhower matrix
class _QuadrantPanel extends StatelessWidget {
  const _QuadrantPanel({
    required this.title,
    required this.quadrantIndex,
    required this.habits,
    required this.selectedDate,
    required this.onHabitTap,
    required this.onHabitDrop,
    this.colorAccent,
  });

  final String title;
  final int quadrantIndex;
  final List<Habit> habits;
  final DateTime selectedDate;
  final void Function(Habit) onHabitTap;
  final void Function(Habit, int) onHabitDrop;
  final Color? colorAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = colorAccent ?? theme.colorScheme.outlineVariant;

    return DragTarget<Habit>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        onHabitDrop(details.data, quadrantIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isHovering
                ? theme.colorScheme.primaryContainer.withAlpha(100)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? theme.colorScheme.primary : borderColor,
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colorAccent?.withAlpha(30) ??
                      theme.colorScheme.surfaceContainerHighest,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorAccent ?? theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(
                child: habits.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.colorScheme.outlineVariant,
                          size: 32,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: habits.length,
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          return _MatrixHabitChip(
                            habit: habit,
                            selectedDate: selectedDate,
                            onTap: () => onHabitTap(habit),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact habit chip displayed inside matrix quadrants
class _MatrixHabitChip extends StatelessWidget {
  const _MatrixHabitChip({
    required this.habit,
    required this.selectedDate,
    required this.onTap,
  });

  final Habit habit;
  final DateTime selectedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitColor = habit.color;
    final isComplete = habit.isGoalMetForPeriod(
      habit.last7,
      selectedDate,
      mondayFirst: context.read<AppState>().weekStart == WeekStart.monday,
    );

    return LongPressDraggable<Habit>(
      data: habit,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: habitColor.withAlpha(200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                habit.name,
                style:
                    theme.textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildChipContent(context, theme, habitColor, isComplete),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _buildChipContent(context, theme, habitColor, isComplete),
      ),
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildChipContent(BuildContext context, ThemeData theme,
      Color habitColor, bool isComplete) {
    // isComplete param deprecated by new logic but keeping for signature compat if needed, will recalculate
    final dateKeyStr = _dateKey(selectedDate);
    final currentValue = habit.last7[dateKeyStr] ?? 0.0;
    final isDoneToday = currentValue >= habit.targetValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDoneToday
              ? habitColor.withAlpha(100)
              : theme.colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              habit.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDoneToday
                    ? theme.colorScheme.onSurface.withAlpha(150)
                    : theme.colorScheme.onSurface,
                decoration: isDoneToday ? TextDecoration.lineThrough : null,
                fontWeight: isDoneToday ? FontWeight.normal : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          // Checkmark / Progress Control
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: HabitCompletionIndicator(
              habit: habit,
              currentValue: currentValue,
              size: 24,
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main Eisenhower Matrix widget with 2×2 grid layout
class EisenhowerMatrixWidget extends StatefulWidget {
  const EisenhowerMatrixWidget({
    super.key,
    required this.habits,
    required this.selectedDate,
    required this.onHabitTap,
  });

  final List<Habit> habits;
  final DateTime selectedDate;
  final void Function(Habit) onHabitTap;

  @override
  State<EisenhowerMatrixWidget> createState() => _EisenhowerMatrixWidgetState();
}

class _EisenhowerMatrixWidgetState extends State<EisenhowerMatrixWidget> {
  late Map<String, int> _placements;

  @override
  void initState() {
    super.initState();
    _placements = Map.from(Storage.getHabitQuadrantPlacements());
  }

  List<Habit> _habitsForQuadrant(int quadrant) {
    return widget.habits.where((h) => _placements[h.id] == quadrant).toList();
  }

  void _handleDrop(Habit habit, int quadrant) async {
    setState(() {
      _placements[habit.id] = quadrant;
    });
    await Storage.saveHabitQuadrantPlacement(habit.id, quadrant);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Define quadrant colors
    final quadrantColors = [
      Colors.red.shade400, // Urgent & Important
      Colors.blue.shade400, // Not urgent & Important
      Colors.orange.shade400, // Urgent & Not important
      Colors.grey.shade400, // Not urgent & Not important
    ];

    final quadrantTitles = [
      l10n.eisenhowerQuadrant1,
      l10n.eisenhowerQuadrant2,
      l10n.eisenhowerQuadrant3,
      l10n.eisenhowerQuadrant4,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _QuadrantPanel(
                    title: quadrantTitles[0],
                    quadrantIndex: 0,
                    habits: _habitsForQuadrant(0),
                    selectedDate: widget.selectedDate,
                    onHabitTap: widget.onHabitTap,
                    onHabitDrop: _handleDrop,
                    colorAccent: quadrantColors[0],
                  ),
                ),
                Expanded(
                  child: _QuadrantPanel(
                    title: quadrantTitles[1],
                    quadrantIndex: 1,
                    habits: _habitsForQuadrant(1),
                    selectedDate: widget.selectedDate,
                    onHabitTap: widget.onHabitTap,
                    onHabitDrop: _handleDrop,
                    colorAccent: quadrantColors[1],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _QuadrantPanel(
                    title: quadrantTitles[2],
                    quadrantIndex: 2,
                    habits: _habitsForQuadrant(2),
                    selectedDate: widget.selectedDate,
                    onHabitTap: widget.onHabitTap,
                    onHabitDrop: _handleDrop,
                    colorAccent: quadrantColors[2],
                  ),
                ),
                Expanded(
                  child: _QuadrantPanel(
                    title: quadrantTitles[3],
                    quadrantIndex: 3,
                    habits: _habitsForQuadrant(3),
                    selectedDate: widget.selectedDate,
                    onHabitTap: widget.onHabitTap,
                    onHabitDrop: _handleDrop,
                    colorAccent: quadrantColors[3],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
