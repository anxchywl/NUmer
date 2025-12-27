import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/heatmap_service.dart';

class HeatmapCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;

  const HeatmapCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<HeatmapCalendar> createState() => _HeatmapCalendarState();
}

class _HeatmapCalendarState extends State<HeatmapCalendar> {
  late final HeatmapService _service;
  Map<DateTime, int> _dailyMinutes = {};
  late DateTime _currentFocusedDay;
  bool _isLoading = false;

  
  static const List<Color> _greens = [
    Colors.transparent, 
    Color(0xFFD6F5D6), 
    Color(0xFFB3E6B3), 
    Color(0xFF80D180), 
    Color(0xFF4DB84D), 
    Color(0xFF269926), 
    Color(0xFF196127), 
  ];

  @override
  void initState() {
    super.initState();
    _service = HeatmapService();
    _currentFocusedDay = widget.focusedDay;
    _fetchMonthData(_currentFocusedDay);
  }

  Future<void> _fetchMonthData(DateTime date) async {
    final start = DateTime(date.year, date.month - 1, 1);
    final end = DateTime(date.year, date.month + 2, 0);

    setState(() => _isLoading = true);
    final data = await _service.fetchDailyTotals(start, end);
    if (!mounted) return;
    setState(() {
      _dailyMinutes = data;
      _isLoading = false;
    });
  }

  int _getLevel(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 90) return 3;
    if (minutes < 120) return 4;
    if (minutes < 150) return 5;
    return 6;
  }

  Color _getColor(int minutes) {
    final level = _getLevel(minutes);
    return _greens[level];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDay: DateTime.now().add(const Duration(days: 0)), 
      focusedDay: _currentFocusedDay,
      locale: Localizations.localeOf(context).languageCode,
      selectedDayPredicate: (day) => isSameDay(widget.selectedDay, day),
      onDaySelected: widget.onDaySelected,
      onPageChanged: (focusedDay) {
        _currentFocusedDay = focusedDay;
        _fetchMonthData(focusedDay);
      },
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildCell(day, isToday: false);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildCell(day, isToday: true);
        },
        selectedBuilder: (context, day, focusedDay) {
           return _buildCell(day, isToday: isSameDay(day, DateTime.now()), isSelected: true);
        },
        outsideBuilder: (context, day, focusedDay) {
          
          
          return null; 
        },
      ),
    ),
      if (_isLoading)
        const Positioned.fill(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ],
  );
  }

  
  Widget _buildCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    
    final key = DateTime(day.year, day.month, day.day);
    final minutes = _dailyMinutes[key] ?? 0;
    final color = _getColor(minutes);
    final hasHeat = minutes > 0;

    BoxDecoration? decoration;
    TextStyle? textStyle;

    
    textStyle = Theme.of(context).textTheme.bodyMedium;

    if (isSelected) {
       decoration = BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      );
      textStyle = textStyle?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);
    } else if (hasHeat) {
      decoration = BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      );
      textStyle = textStyle?.copyWith(
        color: _getLevel(minutes) > 4 ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600
      );
    } else if (isToday) {
       decoration = BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor),
        shape: BoxShape.circle,
      );
       textStyle = textStyle?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(6.0),
        alignment: Alignment.center,
        decoration: decoration,
        child: Text(
          '${day.day}',
          style: textStyle,
        ),
      ),
    );
  }
}
