import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/habit.dart';
import '../../../services/auth_service.dart';
import '../../../services/habit_service.dart';
import 'step_category.dart';
import 'step_tracking.dart';
import 'step_schedule.dart';

class CreateHabitWizard extends StatefulWidget {
  const CreateHabitWizard({super.key});

  @override
  State<CreateHabitWizard> createState() => _CreateHabitWizardState();
}

class _CreateHabitWizardState extends State<CreateHabitWizard> {
  int _currentStep = 0;
  
  // Draft Habit Data
  String? _category;
  String _name = "";
  Color _color = Colors.blue;
  
  // Tracking Defaults
  HabitType _type = HabitType.yesNo;
  HabitFrequencyType _freq = HabitFrequencyType.daily;
  double _target = 1.0;
  String? _unit;
  Set<int> _weekDays = {};
  int _interval = 1;

  // Schedule Defaults
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  bool _isSaving = false;

  final Map<String, Color> _categoryColors = const {
    'Quit a bad habit': Colors.red,
    'Art': Colors.purple,
    'Meditation': Colors.indigo,
    'Study': Colors.blue,
    'Sports': Colors.orange,
    'Entertainment': Colors.pink,
    'Social': Colors.teal,
    'Finance': Colors.green,
    'Health': Colors.redAccent,
    'Work': Colors.brown,
    'Nutrition': Colors.deepOrange,
    'Outdoor': Colors.greenAccent,
    'Home': Colors.blueGrey,
    'Other': Colors.grey,
    'Custom': Colors.black, // Placeholder
  };
  
  void _nextStep() {
    if (_currentStep == 0) {
      if (_category == null) return; 
      // Auto-set Name and Color from category if not set? 
      // For now, let's prompt name if custom, or settle on category name as default.
      if (_name.isEmpty && _category != 'Custom') {
        _name = _category!;
      }
      if (_category != 'Custom') {
         _color = _categoryColors[_category!] ?? Colors.blue;
      }
    }
    
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Step ${_currentStep + 1} of 3"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / 3),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                HabitCategoryStep(
                  selectedCategory: _category,
                  onCategorySelected: (cat) {
                    setState(() => _category = cat);
                    if (cat == "Custom") {
                      _showCustomCategoryDialog();
                    } else {
                       // Auto advance for smooth UX?
                       _nextStep();
                    }
                  },
                ),
                HabitTrackingStep(
                  initialType: _type,
                  initialFreq: _freq,
                  initialTarget: _target,
                  initialUnit: _unit,
                  initialWeekDays: _weekDays,
                  initialInterval: _interval,
                  onChanged: ({required freq, required interval, required target, required type, required unit, required weekDays}) {
                    // Update state silently so when we hit Next it's ready
                    _type = type;
                    _freq = freq;
                    _target = target;
                    _unit = unit;
                    _weekDays = weekDays;
                    _interval = interval;
                  },
                ),
                HabitScheduleStep(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartDateChanged: (d) => setState(() => _startDate = d),
                  onEndDateChanged: (d) => setState(() => _endDate = d),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_currentStep == 0) 
                     // No button needed if using auto-advance on tile tap, except for maybe custom?
                     const Spacer()
                  else 
                    Expanded(
                      child: FilledButton(
                        onPressed: _currentStep == 2 
                           ? (_isSaving ? null : _submit) 
                           : _nextStep,
                        style: FilledButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_currentStep == 2 ? "Create Habit" : "Next"),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showCustomCategoryDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Custom Habit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Habit Name", hintText: "e.g. Learn Guitar"),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Minimal color picker
            Wrap(
              spacing: 8,
              children: Colors.primaries.take(5).map((c) => GestureDetector(
                 onTap: () {
                    setState(() => _color = c);
                    Navigator.pop(context, true);
                 },
                 child: CircleAvatar(backgroundColor: c, radius: 16),
              )).toList(),
            )
          ],
        ),
      ),
    );
    
    if (nameController.text.isNotEmpty) {
      setState(() => _name = nameController.text);
      _nextStep();
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    
    try {
      final auth = context.read<AuthController>();
      final habitService = context.read<HabitService>();
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final habit = Habit(
        id: '',
        name: _name,
        color: _color,
        category: _category ?? 'Custom',
        type: _type,
        targetValue: _target,
        unit: _unit,
        frequencyType: _freq,
        weekDays: _weekDays,
        intervalDays: _interval,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: DateTime.now(),
      );
      
      await habitService.createHabit(uid, habit);
      
      if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Habit Created!")));
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    } finally {
       if (mounted) setState(() => _isSaving = false);
    }
  }
}
