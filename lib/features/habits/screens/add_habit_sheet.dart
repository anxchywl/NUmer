import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../data/habit_service.dart';
import '../models/habit.dart';
import '../models/habit_category.dart';
import '../models/habit_rule.dart';
import '../widgets/add_habit/add_habit_extras_step.dart';
import '../widgets/add_habit/add_habit_goal_step.dart';
import '../widgets/add_habit/add_habit_header.dart';
import '../widgets/add_habit/add_habit_name_step.dart';
import '../widgets/add_habit/add_habit_schedule_step.dart';
import '../widgets/add_habit/category_creation_form.dart';
import '../widgets/add_habit/category_selector.dart';
import '../widgets/add_habit/course_selector.dart';
import '../widgets/add_habit/numeric_target_fields.dart';
import '../widgets/add_habit/per_period_content.dart';
import '../widgets/add_habit/specific_days_content.dart';
import '../widgets/add_habit/tracking_type_picker.dart';
import '../widgets/add_habit/work_rest_content.dart';

part 'add_habit_actions.dart';
part 'add_habit_input_actions.dart';
part 'add_habit_step_builders.dart';

class AddHabitSheet extends StatefulWidget {
  final HabitCategory? initialCategory;
  final Habit? habit;

  const AddHabitSheet({super.key, this.initialCategory, this.habit});

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

abstract class _AddHabitSheetBase extends State<AddHabitSheet>
    with SingleTickerProviderStateMixin {
  int _screen =
      0; // 0 = Create new habit, 1 = Tracking type, 2 = Frequency, 3 = When?

  // -- Data --
  final List<Map<String, dynamic>> _defaultCategories = const [
    {'name': 'Study', 'icon': Icons.school, 'color': Colors.blue},
    {'name': 'Sports', 'icon': Icons.directions_run, 'color': Colors.orange},
    {'name': 'Quit a bad habit', 'icon': Icons.block, 'color': Colors.red},
    {'name': 'Home', 'icon': Icons.home, 'color': Colors.blueGrey},
    {'name': 'Health', 'icon': Icons.favorite, 'color': Colors.redAccent},
    {'name': 'Work', 'icon': Icons.work, 'color': Colors.brown},
  ];

  List<HabitCategory> _customCategories = [];

  late String _categoryName;
  bool _isCreatingCategory = false; // Mode switch

  // Custom Category Creation Form
  String _habitName = ""; // Added
  String _newCatName = "";
  Color _newCatColor = Colors.blue;
  IconData _newCatIcon = Icons.star;

  HabitType _type = HabitType.yesNo;
  HabitFrequencyType _freq = HabitFrequencyType.daily;
  final Set<int> _weekDays = {};
  int _interval = 2; // Every 2 days

  // Numeric/Time targets
  double _target = 1.0; // Default to 1.0 for Yes/No
  String _unit = "";
  HabitComparator _comparator = HabitComparator.atLeast;

  // Sync Period
  HabitPeriod _period = HabitPeriod.week;
  int _frequencyGoal = 3;

  // Schedule
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Connected Courses
  List<String> _connectedCourseIds = [];

  bool _isSaving = false;

  // Time Input Helpers
  late TextEditingController _targetCtrl;
  late TextEditingController _unitCtrl;
  // Persistent controllers for numeric inputs to avoid recreating each build
  late TextEditingController _frequencyGoalCtrl;
  late TextEditingController _workDaysCtrl;
  late TextEditingController _restDaysCtrl;

  // -- Focus Nodes --
  final FocusNode _habitNameFocus = FocusNode();
  final FocusNode _freqGoalFocus = FocusNode();
  final FocusNode _workDaysFocus = FocusNode();
  final FocusNode _restDaysFocus = FocusNode();
  final FocusNode _targetFocus = FocusNode();
  final FocusNode _unitFocus = FocusNode();

  // -- Focus State --
  bool _isHabitNameFocused = false;
  bool _isFreqGoalFocused = false;
  bool _isWorkRestFocused = false;
  bool _isTrackingInputFocused = false;
  bool get _isEditingHabit => widget.habit != null;

  // keys carry these elements and their running animations from step to step
  final GlobalKey _leadKey = GlobalKey();
  final GlobalKey _navKey = GlobalKey();
}

class _AddHabitSheetState extends _AddHabitSheetBase
    with _AddHabitActions, _AddHabitInputActions, _AddHabitSteps {
  @override
  void initState() {
    super.initState();

    // Initial State for Editing
    if (widget.initialCategory != null) {
      _categoryName = widget.initialCategory!.name;
    } else if (widget.habit != null) {
      _categoryName = widget.habit!.category;
    } else {
      _categoryName = _defaultCategories[0]['name'];
    }

    if (widget.habit != null) {
      final h = widget.habit!;
      _habitName = h.name;
      _type = h.type;
      _freq = h.frequencyType;
      _weekDays.addAll(h.weekDays);
      _interval = h.intervalDays;
      _target = h.targetValue;
      _unit = h.unit ?? "";
      _comparator = h.comparator;
      _period = h.frequencyPeriod ?? HabitPeriod.week;
      _frequencyGoal = h.frequencyGoal ?? 3;
      _startDate = h.startDate;
      _endDate = h.endDate;
      _connectedCourseIds = List.from(h.connectedCourseIds);
    }

    // Initialize numeric controllers. If editing an existing habit, show values,
    // otherwise keep inputs empty as requested.
    final isEditing = widget.habit != null;
    _frequencyGoalCtrl = TextEditingController(
      text: isEditing && _frequencyGoal > 0 ? "$_frequencyGoal" : "",
    );
    _workDaysCtrl = TextEditingController(
      text: isEditing && _interval > 0 ? "$_interval" : "",
    );
    _restDaysCtrl = TextEditingController(
      text: isEditing && _frequencyGoal > 0 ? "$_frequencyGoal" : "",
    );
    _targetCtrl = TextEditingController(
      text: isEditing && _target > 0 ? "$_target" : "",
    );
    _unitCtrl = TextEditingController(text: _unit);

    // Focus Listeners
    _habitNameFocus.addListener(_onFocusChanged);
    _freqGoalFocus.addListener(_onFocusChanged);
    _workDaysFocus.addListener(_onFocusChanged);
    _restDaysFocus.addListener(_onFocusChanged);
    _targetFocus.addListener(_onFocusChanged);
    _unitFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _frequencyGoalCtrl.dispose();
    _workDaysCtrl.dispose();
    _restDaysCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();

    _habitNameFocus.removeListener(_onFocusChanged);
    _freqGoalFocus.removeListener(_onFocusChanged);
    _workDaysFocus.removeListener(_onFocusChanged);
    _restDaysFocus.removeListener(_onFocusChanged);
    _targetFocus.removeListener(_onFocusChanged);
    _unitFocus.removeListener(_onFocusChanged);

    _habitNameFocus.dispose();
    _freqGoalFocus.dispose();
    _workDaysFocus.dispose();
    _restDaysFocus.dispose();
    _targetFocus.dispose();
    _unitFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCustomCategories();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _exitFocusMode();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AddHabitHeader(screen: _screen),
                const SizedBox(height: 24),
                if (_screen == 0)
                  _nameStep()
                else if (_screen == 1)
                  _goalStep()
                else if (_screen == 2)
                  _scheduleStep()
                else if (_screen == 3)
                  _extrasStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
