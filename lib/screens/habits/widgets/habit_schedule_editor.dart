import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/habit.dart';

class HabitScheduleEditor extends StatefulWidget {
  final HabitFrequencyType frequencyType;
  final Set<int> weekDays;
  final int intervalDays;
  final HabitPeriod period;
  final int frequencyGoal;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<ScheduleData> onChanged;

  const HabitScheduleEditor({
    super.key,
    required this.frequencyType,
    required this.weekDays,
    required this.intervalDays,
    required this.period,
    required this.frequencyGoal,
    required this.startDate,
    this.endDate,
    required this.onChanged,
  });

  @override
  State<HabitScheduleEditor> createState() => _HabitScheduleEditorState();
}

class ScheduleData {
  final HabitFrequencyType frequencyType;
  final Set<int> weekDays;
  final int intervalDays;
  final HabitPeriod period;
  final int frequencyGoal;
  final DateTime startDate;
  final DateTime? endDate;

  ScheduleData({
    required this.frequencyType,
    required this.weekDays,
    required this.intervalDays,
    required this.period,
    required this.frequencyGoal,
    required this.startDate,
    this.endDate,
  });
}

class _HabitScheduleEditorState extends State<HabitScheduleEditor> {
  late HabitFrequencyType _freq;
  late Set<int> _weekDays;
  late int _interval; // Work Days
  late HabitPeriod _period;
  late int _frequencyGoal; // Rest Days (for interval) OR Count (for repeats)
  late DateTime _startDate;
  late DateTime? _endDate;

  late TextEditingController _frequencyGoalCtrl;
  late TextEditingController _workDaysCtrl;
  late TextEditingController _restDaysCtrl;

  @override
  void initState() {
    super.initState();
    _freq = widget.frequencyType;
    _weekDays = Set.from(widget.weekDays);
    _interval = widget.intervalDays;
    _period = widget.period;
    _frequencyGoal = widget.frequencyGoal;
    _startDate = widget.startDate;
    _endDate = widget.endDate;


    _frequencyGoalCtrl = TextEditingController(text: "$_frequencyGoal");
    _workDaysCtrl = TextEditingController(text: "$_interval");
    _restDaysCtrl = TextEditingController(text: _freq == HabitFrequencyType.interval ? "$_frequencyGoal" : "0");
  }

  @override
  void dispose() {
    _frequencyGoalCtrl.dispose();
    _workDaysCtrl.dispose();
    _restDaysCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(ScheduleData(
      frequencyType: _freq,
      weekDays: _weekDays,
      intervalDays: _interval,
      period: _period,
      frequencyGoal: _frequencyGoal,
      startDate: _startDate,
      endDate: _endDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TITLE
        Text("Schedule", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        const SizedBox(height: 16),
        
        // DATES
        Row(
           children: [
             Expanded(
               child: _buildDatePicker(
                 context, 
                     label: "Start date", 
                 date: _startDate, 
                 onPick: (d) {
                    setState(() { _startDate = d; _notify(); });
                 },
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: _buildDatePicker(
                 context, 
                     label: "End date (optional)", 
                 date: _endDate, 
                 onPick: (d) {
                    setState(() { _endDate = d; _notify(); });
                 },
                 onClear: _endDate != null ? () {
                    setState(() { _endDate = null; _notify(); });
                 } : null,
                 placeholder: "Forever",
               ),
             ),
           ],
        ),
        const SizedBox(height: 24),
        
        const SizedBox(height: 24),
        
        Text("Frequency", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        const SizedBox(height: 12),

        _buildFreqOption(
           theme,
           type: HabitFrequencyType.daily,
           title: "Every day",
           child: Text("Do the habit daily without skipping.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(height: 12),

        const SizedBox(height: 12),

        _buildFreqOption(
           theme,
           type: HabitFrequencyType.specificDays,
           title: "Specific days",
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Choose exact weekdays or dates.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                 const SizedBox(height: 12),
                 Container(
                   width: double.infinity,
                   decoration: BoxDecoration(
                     color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   padding: const EdgeInsets.all(4),
                   child: Row(
                     children: [
                        _buildPeriodTab(theme, "Week", HabitPeriod.week),
                        _buildPeriodTab(theme, "Month", HabitPeriod.month),
                        _buildPeriodTab(theme, "Year", HabitPeriod.year),
                     ],
                   ),
                 ),
                 const SizedBox(height: 16),
                 if (_period == HabitPeriod.week) 
                    _buildWeekDaySelector(theme)
                 else if (_period == HabitPeriod.month)
                    _buildMonthDaySelector(theme)
                 else if (_period == HabitPeriod.year)
                    _buildYearSelector(theme),
              ],
           ),
        ),
        const SizedBox(height: 12),

        _buildFreqOption(
           theme,
           type: HabitFrequencyType.repeatsInPeriod,
           title: "Days per period",
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Set how many days within a week, month, or year.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                 const SizedBox(height: 12),
                 Row(
                    children: [
                      SizedBox(width: 80, child: TextFormField(
                        controller: _frequencyGoalCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                           FilteringTextInputFormatter.digitsOnly,
                           LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: _inputDecoration(theme),
                        onChanged: (v) {
                           final trimmed = v.trim();
                           if (trimmed.isEmpty) {
                             setState(() => _frequencyGoal = 0);
                             _notify();
                             return;
                           }
                           int val = int.tryParse(trimmed) ?? 1;
                           if (val < 1) val = 1;
                           final maxVal = switch(_period) {
                             HabitPeriod.week => 7,
                             HabitPeriod.month => 31,
                             HabitPeriod.year => 365,
                           };
                           if (val > maxVal) {
                             val = maxVal;
                             _frequencyGoalCtrl.text = "$val";
                             _frequencyGoalCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _frequencyGoalCtrl.text.length));
                           }
                           setState(() { _frequencyGoal = val; _notify(); });
                        },
                      )),
                       const SizedBox(width: 12),
                       const Text("times per"),
                       const SizedBox(width: 12),
                       GestureDetector(
                          onTap: () {
                             setState(() {
                                final nextIndex = (_period.index + 1) % HabitPeriod.values.length;
                                _period = HabitPeriod.values[nextIndex];
                                final maxVal = switch(_period) {
                                   HabitPeriod.week => 7,
                                   HabitPeriod.month => 31,
                                   HabitPeriod.year => 365,
                                };
                                if (_frequencyGoal > maxVal) {
                                   _frequencyGoal = maxVal;
                                   _frequencyGoalCtrl.text = "$_frequencyGoal";
                                }
                                _notify();
                             });
                          },
                          child: _buildPeriodToggle(theme, _period),
                       ),
                    ],
                 ),
              ],
           ),
        ),
        const SizedBox(height: 12),

        _buildFreqOption(
          theme,
          type: HabitFrequencyType.interval,
          title: "Work / Rest",
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text("Set a repeating cycle for the habit.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                   children: [
                      const Text("Work "),
                     SizedBox(width: 60, child: TextFormField(
                       controller: _workDaysCtrl,
                       keyboardType: TextInputType.number,
                       textAlign: TextAlign.center,
                       inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                       decoration: _inputDecoration(theme).copyWith(hintText: "0"),
                       onChanged: (v) {
                         final val = int.tryParse(v) ?? 0;
                         setState(() { _interval = val; _notify(); });
                       },
                     )),
                      const SizedBox(width: 12),
                      const Text("X"),
                      const SizedBox(width: 12),
                     SizedBox(width: 60, child: TextFormField(
                       controller: _restDaysCtrl,
                       keyboardType: TextInputType.number,
                       textAlign: TextAlign.center,
                       inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                       decoration: _inputDecoration(theme).copyWith(hintText: "0"),
                       onChanged: (v) {
                         final val = int.tryParse(v) ?? 0;
                         setState(() { _frequencyGoal = val; _notify(); }); // Storing rest days in frequencyGoal
                       },
                     )),
                      const Text(" Rest"),
                   ],
                ),
             ],
          ),
       ),
      ],
    );
  }

  InputDecoration _inputDecoration(ThemeData theme) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
    );
  }

  Widget _buildDatePicker(BuildContext context, {required String label, required DateTime? date, required Function(DateTime) onPick, VoidCallback? onClear, String? placeholder}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onPick(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? DateFormat.yMMMd().format(date) : (placeholder ?? "Select"),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: date != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (date != null && onClear != null)
                   GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 16))
                else
                   const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreqOption(ThemeData theme, {required HabitFrequencyType type, required String title, required Widget child}) {
     final selected = _freq == type;
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         GestureDetector(
           onTap: () => setState(() { _freq = type; _notify(); }),
           child: AnimatedContainer(
             duration: const Duration(milliseconds: 200),
             curve: Curves.easeInOut,
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
             decoration: BoxDecoration(
                color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                   color: selected ? theme.colorScheme.primary : Colors.transparent,
                   width: 1,
                ),
             ),
             child: Row(
               children: [
                 Icon(
                   selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                   color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
                 ),
                 const SizedBox(width: 12),
                 Text(title, style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
                 )),
               ],
             ),
           ),
         ),
         AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: selected 
              ? Padding(
                  padding: const EdgeInsets.only(top: 12, left: 16, bottom: 8), // Indent content below
                  child: child,
                )
              : const SizedBox.shrink(),
         ),
       ],
     );
  }

  Widget _buildPeriodTab(ThemeData theme, String label, HabitPeriod p) {
     final selected = _period == p;
     return Expanded(
       child: GestureDetector(
         onTap: () {
            if (_period != p) {
               setState(() {
                  _period = p;
                  _weekDays.clear();
                  _notify();
               });
            }
         },
         child: Container(
            decoration: BoxDecoration(
               color: selected ? theme.colorScheme.primary : Colors.transparent,
               borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
               label,
               textAlign: TextAlign.center,
               style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
               ),
            ),
         ),
       ),
     );
  }

  Widget _buildWeekDaySelector(ThemeData theme) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayNum = index + 1;
        final active = _weekDays.contains(dayNum);
        return GestureDetector(
          onTap: () => setState(() {
             if (active) {
                _weekDays.remove(dayNum);
             } else {
                _weekDays.add(dayNum);
             }
             _notify();
          }),
          child: CircleAvatar(
             radius: 18,
             backgroundColor: active ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
             foregroundColor: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
             child: Text(days[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      }),
    );
  }
  
  Widget _buildMonthDaySelector(ThemeData theme) {
     final rows = <Widget>[];
     for (int rowStart = 1; rowStart <= 31; rowStart += 6) {
        final rowEnd = (rowStart + 5 > 31) ? 31 : rowStart + 5;
        final rowDays = <Widget>[];
        for (int day = rowStart; day <= rowEnd; day++) {
           final selected = _weekDays.contains(day);
           rowDays.add(
             GestureDetector(
               onTap: () => setState(() {
                  if (selected) {
                    _weekDays.remove(day);
                  } else {
                    _weekDays.add(day);
                  }
                  _notify();
               }),
               child: Container(
                 width: 40, height: 40,
                 alignment: Alignment.center,
                 decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                 ),
                 child: Text("$day", style: TextStyle(
                    color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                 )),
               ),
             ),
           );
           if (day < rowEnd) rowDays.add(const SizedBox(width: 8));
        }
        rows.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowDays,
        ));
        if (rowEnd < 31) rows.add(const SizedBox(height: 8));
     }
     
     return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rows,
     );
  }
  
  Widget _buildYearSelector(ThemeData theme) {
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Wrap(
             spacing: 8, runSpacing: 8,
             children: _weekDays.where((encoded) {
                 final m = encoded ~/ 100;
                 final d = encoded % 100;
                 return m >= 1 && m <= 12 && d >= 1 && d <= 31;
             }).map((encoded) {
                 final m = encoded ~/ 100;
                 final d = encoded % 100;
                 return Chip(
                   label: Text("${months[m-1]} $d"),
                   onDeleted: () => setState(() {
                      _weekDays.remove(encoded);
                      _notify();
                   }),
                 );
             }).toList(),
           ),
           const SizedBox(height: 12),
           OutlinedButton.icon(
             onPressed: () async {
                 final now = DateTime.now();
                 final picked = await showDatePicker(
                    context: context, 
                    initialDate: now, 
                    firstDate: DateTime(now.year, 1, 1), 
                    lastDate: DateTime(now.year, 12, 31)
                 );
                 if (picked != null) {
                    final encoded = picked.month * 100 + picked.day;
                    setState(() {
                       _weekDays.add(encoded);
                       _notify();
                    });
                 }
             }, 
             icon: const Icon(Icons.add), 
             label: const Text("Add date"),
           ),
        ],
      );
  }

  Widget _buildPeriodToggle(ThemeData theme, HabitPeriod p) {
       return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
             color: theme.colorScheme.primaryContainer,
             borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
            child: Text(
               p.name.toUpperCase(),
               key: ValueKey(p),
               style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
            ),
          ),
       );
  }
}
