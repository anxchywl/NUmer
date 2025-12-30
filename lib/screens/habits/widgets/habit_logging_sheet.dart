import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/habit.dart';
import '../../../models/course.dart';
import '../../../services/habit_service.dart';
import '../../../services/storage.dart';
import '../../../app_state.dart';

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
  late double _currentValue;
  LoggingMode _mode = LoggingMode.set;
  Map<String, int> _courseContributions = {}; // courseId -> seconds
  Timer? _incrementTimer;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue ?? 0;
    if (widget.habit.connectedCourseIds.isNotEmpty) {
      _fetchCourseContributions();
    }
  }

  Future<void> _fetchCourseContributions() async {
    final contributions = <String, int>{};
    
    try {
       final start = DateTime(widget.date.year, widget.date.month, widget.date.day);
       final end = start.add(const Duration(days: 1));
       
       final allContributions = await Storage.secondsByCourseBetween(start, end);
       
       for (final id in widget.habit.connectedCourseIds) {
          if (allContributions.containsKey(id)) {
             contributions[id] = allContributions[id]!;
          }
       }
       
       if (mounted) {
         setState(() {
           _courseContributions = contributions;
         });
       }
    } catch (e) {
       debugPrint("Error fetching contributions: $e");
    }
  }

  String _formatValue(double v) {
    if (widget.habit.type == HabitType.time) {
      final h = v ~/ 3600;
      final m = (v % 3600) ~/ 60;
      final s = v % 60;
      return "${h.toInt().toString().padLeft(2, '0')}:${m.toInt().toString().padLeft(2, '0')}:${s.toInt().toString().padLeft(2, '0')}";
    }
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  void _onConfirm() async {
    final habitService = context.read<HabitService>();
    final finalValue = _mode == LoggingMode.set 
        ? _currentValue 
        : (widget.initialValue ?? 0) + _currentValue;

    await habitService.toggleCompletion(
      userId: widget.userId,
      habit: widget.habit,
      date: widget.date,
      completed: finalValue > 0,
      value: finalValue,
    );
    if (mounted) {
       context.read<AppState>().triggerSync();
       Navigator.pop(context);
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
    final isNumeric = widget.habit.type == HabitType.numeric;
    
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.habit.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(widget.habit.iconCodePoint, 
                    fontFamily: widget.habit.iconFamily, 
                    fontPackage: widget.habit.iconPackage),
                  color: widget.habit.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.habit.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(_getGoalText(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<LoggingMode>(
              segments: const [
                ButtonSegment(value: LoggingMode.set, label: Text("Set total"), icon: Icon(Icons.edit)),
                ButtonSegment(value: LoggingMode.add, label: Text("Add more"), icon: Icon(Icons.add)),
              ],
              selected: {_mode},
              onSelectionChanged: (val) {
                setState(() {
                  _mode = val.first;
                  // Reset value when switching modes
                  _currentValue = (_mode == LoggingMode.set) ? (widget.initialValue ?? 0) : 0;
                });
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.comfortable,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (isNumeric) _buildNumericPicker(theme) else _buildTimePicker(theme),
          
          if (!isNumeric) const SizedBox(height: 16),
          
          const SizedBox(height: 32),
          
          _buildProgressInfo(theme),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: widget.habit.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Update progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNumericPicker(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepButton(Icons.remove, -1.0, theme),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: _showManualValueDialog,
          child: Column(
            children: [
              Text(
                _currentValue % 1 == 0 ? _currentValue.toInt().toString() : _currentValue.toStringAsFixed(1),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (widget.habit.unit != null)
                Text(widget.habit.unit!, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        _buildStepButton(Icons.add, 1.0, theme),
      ],
    );
  }

  void _showManualValueDialog() {
    final ctrl = TextEditingController(text: _currentValue % 1 == 0 ? _currentValue.toInt().toString() : _currentValue.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set value"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: widget.habit.unit,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                setState(() => _currentValue = val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(ThemeData theme) {
    final h = _currentValue ~/ 3600;
    final m = (_currentValue % 3600) ~/ 60;
    final s = _currentValue % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(h.toInt().toString().padLeft(2, '0'), "H", 3600, theme),
        _buildTimeSeparator(theme),
        _buildTimeUnit(m.toInt().toString().padLeft(2, '0'), "M", 60, theme),
        _buildTimeSeparator(theme),
        _buildTimeUnit(s.toInt().toString().padLeft(2, '0'), "S", 1, theme),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: IconButton(
            onPressed: () => setState(() => _currentValue = 0),
            icon: Icon(Icons.refresh, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            tooltip: "Clear time",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ],
    );
  }

  void _startAdjusting(double step) {
    _stopAdjusting();
    _adjustValue(step); // First one is immediate

    _incrementTimer = Timer(const Duration(milliseconds: 500), () {
      _incrementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _adjustValue(step);
        HapticFeedback.selectionClick();
      });
    });
  }

  void _stopAdjusting() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
  }

  void _adjustValue(double step) {
    setState(() {
      final maxVal = widget.habit.type == HabitType.time ? 86399.0 : 999999.0;
      _currentValue = (_currentValue + step).clamp(0.0, maxVal);
    });
  }

  Widget _buildTimeUnit(String val, String label, double step, ThemeData theme) {
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) {
            _startAdjusting(step);
            HapticFeedback.lightImpact();
          },
          onTapUp: (_) => _stopAdjusting(),
          onTapCancel: () => _stopAdjusting(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(val, style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            )),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }

  Widget _buildTimeSeparator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 20),
      child: Text(":", style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _buildStepButton(IconData icon, double step, ThemeData theme) {
    return GestureDetector(
      onTapDown: (_) {
        _startAdjusting(step);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => _stopAdjusting(),
      onTapCancel: () => _stopAdjusting(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }

  Widget _buildProgressInfo(ThemeData theme) {
    final target = widget.habit.targetValue;
    final total = _mode == LoggingMode.set ? _currentValue : (widget.initialValue ?? 0) + _currentValue;
    final isCompleted = total >= target;
    
    final dateStr = DateFormat('MMM d').format(widget.date);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Progress, $dateStr", style: theme.textTheme.labelMedium),
            Text("${_formatValue(total)} / ${_formatValue(target)}", style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            ? "Setting total to ${_formatValue(total)}"
            : "Adding ${_formatValue(_currentValue)} to ${_formatValue(widget.initialValue ?? 0)}",
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildStackedProgressBar(ThemeData theme, double total, double target, bool isCompleted) {
      if (total <= 0) {
         return Container(color: theme.colorScheme.surfaceContainerHighest);
      }
      if (_courseContributions.isEmpty) {
         // Standard bar
         return LinearProgressIndicator(
            value: (total / target).clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : widget.habit.color),
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
         final course = courses.firstWhere((c) => c.id == entry.key, orElse: () => const Course(id: 'unknown', name: '?', colorValue: 0xFF9E9E9E, day: '', start: '', end: ''));
         
         final pct = (seconds / target).clamp(0.0, 1.0);
         if (pct > 0) {
            children.add(
              Flexible(
                 flex: (pct * 1000).toInt(),
                 child: Container(color: Color(course.colorValue)),
              )
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
              )
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
            )
         );
      }
      
      return Row(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: children,
      );
  }

  String _getGoalText() {
    final target = widget.habit.targetValue;
    if (widget.habit.type == HabitType.time) {
      final h = target ~/ 3600;
      final m = (target % 3600) ~/ 60;
      return "Goal: ${h > 0 ? '$h h ' : ''}$m min";
    }
    return "Goal: ${target.toInt()} ${widget.habit.unit ?? ''}";
  }
}
