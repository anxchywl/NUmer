import 'dart:async';
import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/widgets/habit_time_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/features/habits/models/habit.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/habits/data/habit_service.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import 'habit_numeric_picker.dart';

class HabitLoggingSheet extends StatefulWidget {
  final Habit habit;
  final DateTime date;
  final double? initialValue;
  final String userId;

  const HabitLoggingSheet({
    super.key,
    required this.habit,
    required this.date,
    this.initialValue,
    required this.userId,
  });

  @override
  State<HabitLoggingSheet> createState() => _HabitLoggingSheetState();
}

enum LoggingMode { set, add }

class _HabitLoggingSheetState extends State<HabitLoggingSheet> {
  late double _initialValue;
  late double _currentValue;
  late TextEditingController _numericController;
  final _focus = NumerSheetFocusMode();
  LoggingMode _mode = LoggingMode.set;
  Map<String, int> _courseContributions = {}; // courseId -> seconds
  Timer? _incrementTimer;
  StreamSubscription<void>? _historySubscription;

  double _maxValueForHabit() {
    if (widget.habit.type == HabitType.time) return 86399.0;
    if (widget.habit.comparator == HabitComparator.lessThan) {
      return widget.habit.targetValue;
    }
    return 10000.0;
  }

  double _clampValue(double raw) {
    if (raw.isNaN || raw.isInfinite) return 0;
    return raw.clamp(0.0, _maxValueForHabit()).toDouble();
  }

  @override
  void initState() {
    super.initState();
    // Use widget.initialValue as fallback, but fetch fresh data immediately
    _initialValue = _clampValue(widget.initialValue ?? 0);

    // Exactly: Pre-fill with target
    if (widget.habit.comparator == HabitComparator.exactly) {
      _currentValue = widget.habit.targetValue;
    } else {
      _currentValue = _initialValue;
    }

    _numericController = TextEditingController(
      text: widget.habit.type == HabitType.numeric
          ? _currentValue.toInt().toString()
          : "",
    );
    _numericController.addListener(_onNumericControllerChanged);

    // Fetch fresh data from Storage (bypasses stale l7 cache)
    _fetchFreshTotal();

    // Listen for history updates (e.g., session ended while popup is open)
    final habitService = context.read<HabitService>();
    _historySubscription = habitService.historyUpdates.listen((_) {
      _fetchFreshTotal();
    });
  }

  void _onNumericControllerChanged() {
    final val = double.tryParse(_numericController.text);
    if (val != null) {
      final clamped = _clampValue(val);
      if (_currentValue != clamped) {
        setState(() {
          _currentValue = clamped;
        });
      }
    } else if (_numericController.text.isEmpty) {
      if (_currentValue != 0) {
        setState(() {
          _currentValue = 0;
        });
      }
    }
  }

  /// Fetches fresh total from Storage (sessions) + Firestore history (manual value)
  Future<void> _fetchFreshTotal() async {
    if (!mounted) return;
    final contributions = <String, int>{};
    try {
      final dateKey =
          '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

      // Prefer local cache for history to avoid stale remote overwriting fresh edits
      final localHistory = Storage.getHabitHistoryFromCache(widget.habit.id);
      LocalHabitHistory? localEntry;
      for (final entry in localHistory) {
        if (entry.dateKey == dateKey && !entry.deleted) {
          localEntry = entry;
          break;
        }
      }

      double total = _clampValue(widget.initialValue ?? 0.0);

      // Only recalc from sessions for time habits with connected courses
      if (widget.habit.type == HabitType.time &&
          widget.habit.connectedCourseIds.isNotEmpty) {
        final start = DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
        );
        final end = start.add(const Duration(days: 1));

        // 1. Get session contributions from Storage
        final allContributions = await Storage.secondsByCourseBetween(
          start,
          end,
        );

        double sessionTotal = 0.0;
        for (final id in widget.habit.connectedCourseIds) {
          if (allContributions.containsKey(id)) {
            contributions[id] = allContributions[id]!;
            sessionTotal += allContributions[id]!;
          }
        }

        // 2. Get manual value from local history (if exists)
        final manualValue = localEntry?.manualValue ?? 0.0;

        // 3. Total = sessions + manual
        total = _clampValue(sessionTotal + manualValue);
      } else {
        // Numeric or non-linked time habits: use local history value if present
        if (localEntry != null) {
          total = _clampValue(localEntry.value ?? 0.0);
        }
      }

      if (mounted) {
        setState(() {
          _courseContributions = contributions;
          _initialValue = total;
          // Only update _currentValue if user hasn't interacted yet (still at widget.initialValue)
          if (_currentValue == _clampValue(widget.initialValue ?? 0) &&
              _mode == LoggingMode.set) {
            _currentValue = total;
            if (widget.habit.type == HabitType.numeric) {
              _numericController.text = _currentValue.toInt().toString();
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching fresh total: $e");
    }
  }

  String _formatValue(double v) {
    if (widget.habit.type == HabitType.time) {
      final h = v ~/ 3600;
      final m = (v % 3600) ~/ 60;
      final s = v % 60;
      return "${h.toInt().toString().padLeft(2, '0')}:${m.toInt().toString().padLeft(2, '0')}:${s.toInt().toString().padLeft(2, '0')}";
    }
    final numberFormat = NumberFormat.decimalPattern(
      AppLocalizations.of(context)!.localeName,
    );
    if (v % 1 == 0) return numberFormat.format(v.toInt());
    return numberFormat.format(double.parse(v.toStringAsFixed(1)));
  }

  bool _isCompleted(double val) {
    switch (widget.habit.comparator) {
      case HabitComparator.lessThan:
        return val > 0 && val <= widget.habit.targetValue;
      case HabitComparator.exactly:
        return (val - widget.habit.targetValue).abs() < 0.001;
      case HabitComparator.atLeast:
      default:
        return val >= widget.habit.targetValue;
    }
  }

  void _onConfirm() async {
    final habitService = context.read<HabitService>();
    final current = _clampValue(_currentValue);
    final base = _mode == LoggingMode.set ? 0 : _initialValue;
    final finalValue = _clampValue(base + current);

    // Final Safety Check
    if (widget.habit.comparator == HabitComparator.lessThan) {
      if (finalValue > widget.habit.targetValue) {
        // Should be prevented by UI but safe guard
        return;
      }
    }

    await habitService.toggleCompletion(
      userId: widget.userId,
      habit: widget.habit,
      date: widget.date,
      // Logic Update:
      // For "Exactly", completed if = target
      // For "Less Than", completed if <= target
      // For "At Least", completed if >= target (default)
      // BUT toggleCompletion calculates status? No, toggleCompletion takes 'completed' bool.
      // So we must determine 'completed' here.
      completed: _isCompleted(finalValue),
      value: finalValue,
      mondayFirst: context.read<AppState>().weekStart == WeekStart.monday,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _incrementTimer?.cancel();
    _historySubscription?.cancel();
    _numericController.removeListener(_onNumericControllerChanged);
    _numericController.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    final theme = Theme.of(context);
    final isNumeric = widget.habit.type == HabitType.numeric;
    final l10n = AppLocalizations.of(context)!;
    final chrome = _focus.hidesChrome;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumerFocusFold(hidden: chrome, child: _buildHeader(theme)),
          NumerFocusGap(hidden: chrome, height: 24),
          NumerFocusFold(hidden: chrome, child: _buildModeSelector(l10n)),
          NumerFocusGap(hidden: chrome, height: 24),
          if (isNumeric)
            _buildNumericPicker()
          else
            _buildTimePicker(theme, l10n),
          NumerFocusGap(hidden: chrome, height: 24),
          NumerFocusFold(
            hidden: chrome,
            child: _buildProgressInfo(theme, l10n),
          ),
          const SizedBox(height: 24),
          _buildConfirmButton(l10n, isNumeric),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.habit.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconData(
              widget.habit.iconCodePoint,
              fontFamily: widget.habit.iconFamily,
              fontPackage: widget.habit.iconPackage,
            ),
            color: widget.habit.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.habit.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<LoggingMode>(
        segments: [
          ButtonSegment(
            value: LoggingMode.set,
            label: Text(l10n.habitLogSetTotal),
            icon: const Icon(Icons.edit),
          ),
          ButtonSegment(
            value: LoggingMode.add,
            label: Text(l10n.habitLogAddMore),
            icon: const Icon(Icons.add),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (val) => _selectMode(val.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.comfortable,
        ),
      ),
    );
  }

  void _selectMode(LoggingMode newMode) {
    setState(() {
      // set shows the current total, add starts from the amount to put on top
      _currentValue = newMode == LoggingMode.set ? _initialValue : 0;
      _mode = newMode;
      if (widget.habit.type == HabitType.numeric) {
        _numericController.text = _currentValue.toInt().toString();
      }
    });
  }

  Widget _buildConfirmButton(AppLocalizations l10n, bool isNumeric) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: (isNumeric && _numericController.text.isEmpty)
            ? null
            : _onConfirm,
        style: FilledButton.styleFrom(
          backgroundColor: widget.habit.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          l10n.habitUpdateProgress,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNumericPicker() {
    return HabitNumericPicker(
      controller: _numericController,
      focusNode: _focus.nodeFor('value'),
      locked: widget.habit.comparator == HabitComparator.exactly,
      hideSteps: _focus.hidesChrome,
      maxValue: _maxValueForHabit(),
      unit: widget.habit.unit,
      onStepStart: _startAdjusting,
      onStepStop: _stopAdjusting,
    );
  }

  Widget _buildTimePicker(ThemeData theme, AppLocalizations l10n) {
    return HabitTimePicker(
      value: _currentValue,
      onChanged: (v) => setState(() => _currentValue = v),
      activeColor: widget.habit.color,
    );
  }

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
    setState(() {
      _currentValue = _clampValue(_currentValue + step);
      if (widget.habit.type == HabitType.numeric) {
        _numericController.text = _currentValue.toInt().toString();
      }
    });
  }

  Widget _buildProgressInfo(ThemeData theme, AppLocalizations l10n) {
    final target = widget.habit.targetValue;
    final total = _mode == LoggingMode.set
        ? _clampValue(_currentValue)
        : _clampValue(_initialValue + _currentValue);
    final isCompleted = total >= target;

    final dateStr = DateFormat('MMM d', l10n.localeName).format(widget.date);
    final totalLabel = _formatValue(total);
    final targetLabel = _formatValue(target);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.habitProgressLabel(dateStr),
              style: theme.textTheme.labelMedium,
            ),
            Text(
              "$totalLabel / $targetLabel (${(total / target * 100).toInt()}%)",
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12, // slightly taller for detail
            width: double.infinity,
            child: _buildStackedProgressBar(theme, total, target, isCompleted),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _mode == LoggingMode.set
              ? l10n.habitLogSettingTotal(totalLabel)
              : l10n.habitLogAdding(
                  _formatValue(_currentValue),
                  _formatValue(_initialValue),
                ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedProgressBar(
    ThemeData theme,
    double total,
    double target,
    bool isCompleted,
  ) {
    if (total <= 0) {
      return Container(color: theme.colorScheme.surfaceContainerHighest);
    }
    if (_courseContributions.isEmpty) {
      // Standard bar
      return LinearProgressIndicator(
        value: (total / target).clamp(0.0, 1.0),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          isCompleted ? Colors.green : widget.habit.color,
        ),
      );
    }

    // Stacked Bar
    final courses = context.read<AppState>().courses;

    double accumulatedSeconds = 0;

    // 1. Course segments
    for (final entry in _courseContributions.entries) {
      final seconds = entry.value.toDouble();
      if (seconds <= 0) continue;

      accumulatedSeconds += seconds;
    }

    // Calculate "Manually Added" amount (Total - Sum(courses))
    final manualSeconds = total - accumulatedSeconds;

    // If total > target, we need to handle overflow visually or just clamp full bar.
    // We render the bar relative to 'target' (if total < target) OR relative to 'total' (if total > target)?
    // Usually progress bar is relative to target (100%).

    // Let's just use a Row with flex factors relative to `target`.
    // Segments: [Course A][Course B][Manual][Remaining]

    List<Widget> children = [];

    for (final entry in _courseContributions.entries) {
      final seconds = entry.value.toDouble();
      if (seconds <= 0) continue;
      final course = courses.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => const Course(
          id: 'unknown',
          name: '?',
          colorValue: 0xFF9E9E9E,
          day: '',
          start: '',
          end: '',
        ),
      );

      final pct = (seconds / target).clamp(0.0, 1.0);
      if (pct > 0) {
        children.add(
          Flexible(
            flex: (pct * 1000).toInt(),
            child: Container(color: Color(course.colorValue)),
          ),
        );
      }
    }

    if (manualSeconds > 0) {
      final pct = (manualSeconds / target).clamp(0.0, 1.0);
      if (pct > 0) {
        children.add(
          Flexible(
            flex: (pct * 1000).toInt(),
            child: Container(color: widget.habit.color),
          ),
        );
      }
    }

    // Remaining space
    final currentTotalPct = (total / target).clamp(0.0, 1.0);
    if (currentTotalPct < 1.0) {
      final remainingPct = 1.0 - currentTotalPct;
      children.add(
        Flexible(
          flex: (remainingPct * 1000).toInt(),
          child: Container(color: theme.colorScheme.surfaceContainerHighest),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
