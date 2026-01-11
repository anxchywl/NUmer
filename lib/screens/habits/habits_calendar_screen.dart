import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import 'widgets/habit_day_sheet.dart';
import '../../l10n/app_localizations.dart';

class HabitsCalendarScreen extends StatefulWidget {
  const HabitsCalendarScreen({super.key});

  @override
  State<HabitsCalendarScreen> createState() => _HabitsCalendarScreenState();
}

class _HabitsCalendarScreenState extends State<HabitsCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  Map<String, Map<String, double>> _progressByDate = {}; // dateKey -> {habitId -> value}
  List<Habit> _allHabits = [];
  bool _isLoading = true;
  StreamSubscription<List<Habit>>? _habitsSub;
  String? _activeLoadKey;
  
  // Calendar navigation boundaries
  static final DateTime _minMonth = DateTime(2025, 1);
  DateTime get _maxMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1);
  }

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  void _loadMonthData() {
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      _habitsSub?.cancel();
      _activeLoadKey = null;
      setState(() {
        _isLoading = false;
        _progressByDate = {};
        _allHabits = [];
      });
      return;
    }

    final habitService = context.read<HabitService>();

    _habitsSub?.cancel();
    final loadKey = "${_focusedMonth.year}-${_focusedMonth.month}";
    _activeLoadKey = loadKey;
    setState(() => _isLoading = true);

    final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    final end = nextMonth.subtract(const Duration(days: 1));

    _habitsSub = habitService.habitsStream(uid).listen((habits) async {
      if (auth.currentUser?.uid != uid) return;
      final Map<String, Map<String, double>> newProgress = {};

      for (final habit in habits) {
        final history = await habitService.getHistory(uid, habit.id, start, end);
        for (final entry in history) {
          final dateKey = _dateKey(entry.date);
          newProgress.putIfAbsent(dateKey, () => {})[habit.id] = entry.value ?? 1.0;
        }
      }

      if (!mounted || _activeLoadKey != loadKey) return;
      setState(() {
        _allHabits = habits;
        _progressByDate = newProgress;
        _isLoading = false;
      });
    }, onError: (_) {
      if (!mounted || _activeLoadKey != loadKey) return;
      setState(() => _isLoading = false);
    });
  }

  void _prevMonth() {
    final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    if (prevMonth.isBefore(_minMonth)) return;
    
    setState(() {
      _focusedMonth = prevMonth;
      _loadMonthData();
    });
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    super.dispose();
  }

  void _nextMonth() {
    final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (nextMonth.isAfter(_maxMonth)) return;
    
    setState(() {
      _focusedMonth = nextMonth;
      _loadMonthData();
    });
  }

  void _showDaySheet(DateTime date) {
    if (_isLoading) return;
    
    final dateKey = _dateKey(date);
    final progressMap = _progressByDate[dateKey] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Sheet handles decoration
      builder: (context) => HabitDaySheet(
        date: date,
        allHabits: _allHabits,
        progressMap: progressMap,
        userId: context.read<AuthController>().currentUser?.uid ?? '',
        isReadOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.habitsCalendarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
               setState(() {
                 _focusedMonth = DateTime.now();
                 _loadMonthData();
               });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _focusedMonth.isAfter(_minMonth) ? _prevMonth : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat.yMMMM(l10n.localeName).format(_focusedMonth),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _focusedMonth.isBefore(_maxMonth) ? _nextMonth : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
               ? const Center(child: CircularProgressIndicator()) 
               : _buildCalendarGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstWeekday = firstDay.weekday; 
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final narrowWeekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final weekdayLabels = [...narrowWeekdays.skip(1), narrowWeekdays.first];

    return Column(
      children: [
         // Weekday headers
         Row(
           children: weekdayLabels.map((d) => 
             Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))))
           ).toList(),
         ),
         const SizedBox(height: 8),
         Expanded(
           child: GridView.builder(
             padding: const EdgeInsets.all(8),
             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 7, 
               childAspectRatio: 0.6, 
               crossAxisSpacing: 4,
               mainAxisSpacing: 4,
             ),
             itemCount: 42, 
             itemBuilder: (context, index) {
                final int dayOffset = index - (firstWeekday - 1);
                final date = firstDay.add(Duration(days: dayOffset));
                
                final isCurrentMonth = date.month == _focusedMonth.month;
                if (!isCurrentMonth) return const SizedBox.shrink(); 
                
                final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                final isFuture = date.isAfter(today);
                
                final dateKey = _dateKey(date);
                final progressMap = _progressByDate[dateKey] ?? {};
                
                // Determine which habits completed for dot/list
                final completedHabits = _allHabits.where((h) => progressMap.containsKey(h.id) && progressMap[h.id]! > 0).toList();

                return InkWell(
                  onTap: isFuture ? null : () => _showDaySheet(date),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFuture
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(30)
                          : (isToday
                              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(100)
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50)),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isFuture ? Border.all(color: Theme.of(context).colorScheme.primary) : null,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text("${date.day}", style: TextStyle(
                            fontSize: 12, 
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isFuture
                                ? Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(120)
                                : (isToday ? Theme.of(context).colorScheme.primary : null),
                         )),
                         const SizedBox(height: 2),
                         Expanded(
                           child: ListView(
                             physics: const NeverScrollableScrollPhysics(), // Dense list
                             children: completedHabits.map((h) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isFuture ? h.color.withAlpha(20) : h.color.withAlpha(50),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    h.name,
                                    style: TextStyle(fontSize: 8, color: isFuture ? h.color.withAlpha(120) : h.color, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                             }).toList(),
                           ),
                         ),
                      ],
                    ),
                  ),
                );
             },
           ),
         ),
      ],
    );
  }

  String _dateKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
