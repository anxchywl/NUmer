import 'package:flutter/material.dart';
import '../../../models/habit.dart';

class HabitTrackingStep extends StatefulWidget {
  final HabitType initialType;
  final HabitFrequencyType initialFreq;
  final double initialTarget;
  final String? initialUnit;
  final Set<int> initialWeekDays;
  final int initialInterval;
  
  final Function({
     required HabitType type, 
     required HabitFrequencyType freq, 
     required double target, 
     required String? unit,
     required Set<int> weekDays,
     required int interval,
  }) onChanged;

  const HabitTrackingStep({
    super.key,
    required this.initialType,
    required this.initialFreq,
    required this.initialTarget,
    this.initialUnit,
    required this.initialWeekDays,
    required this.initialInterval,
    required this.onChanged,
  });

  @override
  State<HabitTrackingStep> createState() => _HabitTrackingStepState();
}

class _HabitTrackingStepState extends State<HabitTrackingStep> {
  late HabitType _type;
  late HabitFrequencyType _freq;
  late double _target;
  late TextEditingController _unitController;
  late Set<int> _weekDays;
  late int _interval;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _freq = widget.initialFreq;
    _target = widget.initialTarget;
    _unitController = TextEditingController(text: widget.initialUnit);
    _weekDays = Set.from(widget.initialWeekDays);
    _interval = widget.initialInterval;
    
    // Default weekdays if specific is chosen but empty
    if (_freq == HabitFrequencyType.specificDays && _weekDays.isEmpty) {
        _weekDays = {1, 3, 5};
    }
    
    _unitController.addListener(_notify);
  }
  
  void _notify() {
    widget.onChanged(
        type: _type,
        freq: _freq,
        target: _target,
        unit: _unitController.text.isEmpty ? null : _unitController.text,
        weekDays: _weekDays,
        interval: _interval,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Selection
          Text("How tracking works?", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<HabitType>(
            segments: const [
              ButtonSegment(value: HabitType.yesNo, label: Text("Yes/No")),
              ButtonSegment(value: HabitType.numeric, label: Text("Numeric")),
              ButtonSegment(value: HabitType.time, label: Text("Time")),
            ],
            selected: {_type},
            onSelectionChanged: (newSet) {
               setState(() {
                 _type = newSet.first;
                 if (_type == HabitType.yesNo) _target = 1;
                 if (_type == HabitType.time && _target < 60) _target = 30 * 60; // Default 30 min
               });
               _notify();
            },
          ),
          
          const SizedBox(height: 24),
          
          // Target Inputs
          if (_type == HabitType.numeric) ...[
             Row(
               children: [
                 Expanded(
                   child: TextFormField(
                     initialValue: _target.toInt().toString(),
                     decoration: const InputDecoration(labelText: "Target Value", hintText: "5"),
                     keyboardType: TextInputType.number,
                     onChanged: (v) {
                       setState(() => _target = double.tryParse(v) ?? 1);
                       _notify();
                     },
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: TextFormField(
                     controller: _unitController,
                     decoration: const InputDecoration(labelText: "Unit", hintText: "pages, cups"),
                   ),
                 ),
               ],
             ),
          ] else if (_type == HabitType.time) ...[
             // Simple minutes slider for MVP
             Text("Duration: ${(_target / 60).round()} minutes"),
             Slider(
               value: _target,
               min: 60, // 1 min
               max: 180 * 60, // 3 hours
               divisions: 179,
               label: "${(_target / 60).round()} min",
               onChanged: (v) {
                 setState(() => _target = v);
                 _notify();
               },
             ),
          ],

          const SizedBox(height: 32),
          
          // Frequency
          Text("Frequency", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<HabitFrequencyType>(
            value: _freq,
             decoration: const InputDecoration(
               border: OutlineInputBorder(),
               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             ),
            items: const [
              DropdownMenuItem(value: HabitFrequencyType.daily, child: Text("Every Day")),
              DropdownMenuItem(value: HabitFrequencyType.specificDays, child: Text("Specific Days")),
              DropdownMenuItem(value: HabitFrequencyType.interval, child: Text("Repeating Interval")),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                 _freq = v;
                 if (_freq == HabitFrequencyType.specificDays && _weekDays.isEmpty) {
                   _weekDays = {1, 3, 5};
                 }
              });
              _notify();
            },
          ),
          const SizedBox(height: 16),
          
          if (_freq == HabitFrequencyType.specificDays) 
            _buildDaySelector(theme),
            
          if (_freq == HabitFrequencyType.interval)
            Row(
              children: [
                const Text("Repeat every "),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: "$_interval",
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                       setState(() => _interval = int.tryParse(v) ?? 1);
                       _notify();
                    },
                  ),
                ),
                const Text(" days"),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayNum = index + 1;
        final active = _weekDays.contains(dayNum);

        return GestureDetector(
          onTap: () {
            setState(() {
               if (_weekDays.contains(dayNum)) {
                 if (_weekDays.length > 1) _weekDays.remove(dayNum);
               } else {
                 _weekDays.add(dayNum);
               }
            });
            _notify();
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(
              days[index],
              style: TextStyle(
                color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }
}
