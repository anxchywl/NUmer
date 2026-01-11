import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/habit.dart';
import '../../../models/habit_category.dart';
import '../../../services/auth_service.dart';
import '../../../services/habit_service.dart';
import 'swipe_selector.dart';
import '../../../app_state.dart';
import '../../../l10n/app_localizations.dart';

class AddHabitSheet extends StatefulWidget {
  final HabitCategory? initialCategory;
  final Habit? habit;

  const AddHabitSheet({super.key, this.initialCategory, this.habit});

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> with SingleTickerProviderStateMixin {
  int _screen = 0; // 0 = Create new habit, 1 = Tracking type, 2 = Frequency, 3 = When?
  
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
  double _target = 1.0; 
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
  final _timeCtrl = TextEditingController(text: "00:00:00");
  late TextEditingController _targetCtrl;
  late TextEditingController _unitCtrl;
  // Persistent controllers for numeric inputs to avoid recreating each build
  late TextEditingController _frequencyGoalCtrl;
  late TextEditingController _workDaysCtrl;
  late TextEditingController _restDaysCtrl;
  
  String _normalizeHms(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    String hh = '00', mm = '00', ss = '00';
    if (d.isEmpty) return '00:00:00';
    if (d.length <= 2) {
      hh = d.padLeft(2, '0');
    } else if (d.length <= 4) {
      hh = d.substring(0, d.length - 2).padLeft(2, '0');
      mm = d.substring(d.length - 2);
    } else {
      final takeLast6 = d.length > 6 ? d.substring(d.length - 6) : d.padLeft(6, '0');
      hh = takeLast6.substring(0, 2);
      mm = takeLast6.substring(2, 4);
      ss = takeLast6.substring(4, 6);
    }
    int H = int.tryParse(hh) ?? 0;
    int M = int.tryParse(mm) ?? 0;
    int S = int.tryParse(ss) ?? 0;
    if (H > 23) H = 23; 
    if (M > 59) M = 59;
    if (S > 59) S = 59;
    return '${H.toString().padLeft(2, '0')}:${M.toString().padLeft(2, '0')}:${S.toString().padLeft(2, '0')}';
  }

  void _onTimeChanged() {
    final raw = _timeCtrl.text;
    final norm = _normalizeHms(raw);
    if (raw != norm) {
        _timeCtrl.value = TextEditingValue(
            text: norm,
            selection: TextSelection.collapsed(offset: norm.length),
        );
    }
    // Update target value in seconds
    final parts = norm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    setState(() => _target = (h * 3600 + m * 60 + s).toDouble());
  }

  @override
  void initState() {
    super.initState();
    _timeCtrl.addListener(_onTimeChanged);
    
    // Initial State for Editing
    if (widget.initialCategory != null) {
      _categoryName = widget.initialCategory!.name;
    } else {
      _categoryName = _defaultCategories[0]['name'];
    }
    // Initialize numeric controllers. If editing an existing habit, show values,
    // otherwise keep inputs empty as requested.
    final isEditing = widget.habit != null;
    _frequencyGoalCtrl = TextEditingController(text: isEditing && _frequencyGoal > 0 ? "$_frequencyGoal" : "");
    _workDaysCtrl = TextEditingController(text: isEditing && _interval > 0 ? "$_interval" : "");
    _restDaysCtrl = TextEditingController(text: isEditing && _frequencyGoal > 0 ? "$_frequencyGoal" : "");
    _targetCtrl = TextEditingController(text: isEditing && _target > 0 ? "$_target" : "");
    _unitCtrl = TextEditingController(text: _unit);
    
    if (widget.habit != null) {
      _connectedCourseIds = List.from(widget.habit!.connectedCourseIds);
    }

  // Focus Listeners
  _habitNameFocus.addListener(_onFocusChanged);
  _freqGoalFocus.addListener(_onFocusChanged);
  _workDaysFocus.addListener(_onFocusChanged);
  _restDaysFocus.addListener(_onFocusChanged);
  _targetFocus.addListener(_onFocusChanged);
  _unitFocus.addListener(_onFocusChanged);
  _timeFocus.addListener(_onFocusChanged);
  }
  
  @override 
  void dispose() {
    _timeCtrl.removeListener(_onTimeChanged);
    _timeCtrl.dispose();
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
  _timeFocus.removeListener(_onFocusChanged);
    
    _habitNameFocus.dispose();
    _freqGoalFocus.dispose();
  _workDaysFocus.dispose();
  _restDaysFocus.dispose();
  _targetFocus.dispose();
  _unitFocus.dispose();
  _timeFocus.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCustomCategories();
  }
  
  // -- Focus Nodes --
  final FocusNode _habitNameFocus = FocusNode();
  final FocusNode _freqGoalFocus = FocusNode();
final FocusNode _workDaysFocus = FocusNode();
final FocusNode _restDaysFocus = FocusNode();
final FocusNode _targetFocus = FocusNode();
final FocusNode _unitFocus = FocusNode();
final FocusNode _timeFocus = FocusNode();

  // -- Focus State --
  bool _isHabitNameFocused = false;
  bool _isFreqGoalFocused = false;
  bool _isWorkRestFocused = false;
  bool _isTrackingInputFocused = false;

  void _onFocusChanged() {
    setState(() {
  _isHabitNameFocused = _habitNameFocus.hasFocus;
  _isFreqGoalFocused = _freqGoalFocus.hasFocus;
  _isWorkRestFocused = _workDaysFocus.hasFocus || _restDaysFocus.hasFocus;
  _isTrackingInputFocused = _targetFocus.hasFocus || _unitFocus.hasFocus || _timeFocus.hasFocus;
});
  }

  int _currentTimeSeconds() {
    final parts = _timeCtrl.text.split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  bool get _isNumericValid {
    final valueText = _targetCtrl.text.trim();
    if (valueText.isEmpty) return false;
    final value = double.tryParse(valueText);
    if (value == null || value <= 0) return false;
    return _unitCtrl.text.trim().isNotEmpty;
  }

  bool get _isTrackingNextEnabled {
    return switch (_type) {
      HabitType.yesNo => true,
      HabitType.numeric => _isNumericValid,
      HabitType.time => _currentTimeSeconds() > 0,
    };
  }

  bool get _isFrequencyNextEnabled {
    return switch (_freq) {
      HabitFrequencyType.daily => true,
      HabitFrequencyType.specificDays => _weekDays.isNotEmpty,
      HabitFrequencyType.repeatsInPeriod => _frequencyGoalCtrl.text.trim().isNotEmpty,
      HabitFrequencyType.interval => _workDaysCtrl.text.trim().isNotEmpty && _restDaysCtrl.text.trim().isNotEmpty,
    };
  }

  ButtonStyle _nextButtonStyle(ThemeData theme) {
    return FilledButton.styleFrom(
      disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      disabledForegroundColor: theme.colorScheme.outline,
    );
  }

  void _resetFocusModeState() {
    _isHabitNameFocused = false;
    _isFreqGoalFocused = false;
    _isWorkRestFocused = false;
    _isTrackingInputFocused = false;
  }

  void _navigateToStep(int nextScreen) {
    FocusScope.of(context).unfocus();
    setState(() {
      _resetFocusModeState();
      _screen = nextScreen;
    });
  }

  void _exitFocusMode() {
    FocusScope.of(context).unfocus();
    setState(_resetFocusModeState);
  }

  void _loadCustomCategories() {
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      context.read<HabitService>().getCategories(uid).listen((cats) {
        if (mounted) {
           setState(() => _customCategories = cats);
        }
      });
    }
  }

  // Combined list for logic
  List<dynamic> get _allCategories {
     // Custom first
     return [..._customCategories, ..._defaultCategories];
  }
  
  // Helper to get current category color/icon
  Map<String, dynamic> get _currentCatData {
    // Check custom
    try {
      final custom = _customCategories.firstWhere((c) => c.name == _categoryName);
      return {'name': custom.name, 'icon': custom.icon, 'color': custom.color, 'isCustom': true, 'id': custom.id};
    } catch (_) {}
    
    // Check default
    return _defaultCategories.firstWhere((c) => c['name'] == _categoryName, orElse: () => _defaultCategories.last);
  }

  String _localizedCategoryName(String name, AppLocalizations l10n) {
    switch (name) {
      case 'Study':
        return l10n.habitCategoryStudy;
      case 'Sports':
        return l10n.habitCategorySports;
      case 'Quit a bad habit':
        return l10n.habitCategoryQuitBadHabit;
      case 'Home':
        return l10n.habitCategoryHome;
      case 'Health':
        return l10n.habitCategoryHealth;
      case 'Work':
        return l10n.habitCategoryWork;
      default:
        return name;
    }
  }

  String _periodLabel(HabitPeriod period, AppLocalizations l10n) {
    switch (period) {
      case HabitPeriod.week:
        return l10n.habitPeriodWeek;
      case HabitPeriod.month:
        return l10n.habitPeriodMonth;
      case HabitPeriod.year:
        return l10n.habitPeriodYear;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final localeName = l10n.localeName;
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _exitFocusMode();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, l10n),
                const SizedBox(height: 24),
               
                 if (_screen == 0) ...[
                    // -- Step 1: Details --
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _isCreatingCategory
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                               Text(l10n.habitExplainHabit, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                               const SizedBox(height: 16),
                               TextFormField(
                                 focusNode: _habitNameFocus,
                                 initialValue: _habitName.isNotEmpty ? _habitName : null, 
                                 decoration: InputDecoration(
                                   labelText: l10n.habitNameLabel,
                                   hintText: l10n.habitNameHint,
                                   filled: true,
                                   fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                   border: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(16),
                                     borderSide: BorderSide.none,
                                   ),
                                   enabledBorder: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(16),
                                     borderSide: BorderSide.none,
                                   ),
                                   focusedBorder: OutlineInputBorder(
                                     borderRadius: BorderRadius.circular(16),
                                     borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                   ),
                                 ),
                                 onChanged: (v) => _habitName = v,
                                 inputFormatters: [
                                   LengthLimitingTextInputFormatter(32),
                                   FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
                                 ],
                               ),
                               const SizedBox(height: 32),
                            ],
                          ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _isHabitNameFocused 
                        ? const SizedBox.shrink() 
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(_isCreatingCategory ? l10n.habitCategoryNew : l10n.habitCategoryLabel, style: theme.textTheme.labelLarge),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                switchInCurve: Curves.easeInOutCubic,
                                switchOutCurve: Curves.easeInOutCubic,
                                transitionBuilder: (child, animation) {
                                  final offsetAnimation = animation.drive(Tween<Offset>(
                                    begin: const Offset(0.0, 0.05),
                                    end: Offset.zero,
                                  ).chain(CurveTween(curve: Curves.easeOutCubic)));

                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: offsetAnimation,
                                      child: SizeTransition(
                                        sizeFactor: animation,
                                        axisAlignment: -1.0,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: _isCreatingCategory
                                ? Column(
                                    key: const ValueKey('creation_form'),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        decoration: InputDecoration(labelText: l10n.habitCategoryNameLabel, hintText: l10n.habitCategoryNameHint),
                                        onChanged: (v) => _newCatName = v,
                                        autofocus: true,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(32),
                                          FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                         height: 48,
                                         child: ListView(
                                           scrollDirection: Axis.horizontal,
                                           children: Colors.primaries.map((color) => Padding(
                                             padding: const EdgeInsets.only(right: 12),
                                             child: GestureDetector(
                                               onTap: () => setState(() => _newCatColor = color),
                                               child: Container(
                                                 width: 34,
                                                 height: 34,
                                                 decoration: BoxDecoration(
                                                   color: color,
                                                   shape: BoxShape.circle,
                                                   border: Border.all(
                                                     color: _newCatColor == color ? Colors.black87 : Colors.transparent,
                                                     width: 2.5,
                                                   ),
                                                   boxShadow: _newCatColor == color 
                                                     ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 1)]
                                                     : null,
                                                 ),
                                                 child: _newCatColor == color ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                               ),
                                             ),
                                           )).toList(),
                                         ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      SizedBox(
                                         height: 48,
                                         child: ListView(
                                           scrollDirection: Axis.horizontal,
                                           children: [
                                             Icons.local_fire_department, Icons.check_circle, Icons.calendar_today, Icons.access_time, 
                                             Icons.track_changes, Icons.star, Icons.bolt, Icons.favorite_border, Icons.psychology, 
                                             Icons.fitness_center, Icons.menu_book, Icons.eco, Icons.water_drop, Icons.nightlight_round, 
                                             Icons.wb_sunny, Icons.directions_walk, Icons.emoji_events, Icons.notifications, 
                                             Icons.edit, Icons.trending_up, Icons.shield, Icons.battery_charging_full, 
                                             Icons.sentiment_satisfied, Icons.rocket_launch, Icons.coffee, Icons.apple,
                                             Icons.lunch_dining, Icons.bakery_dining, Icons.wine_bar, Icons.medication,
                                             Icons.medical_services, Icons.health_and_safety, Icons.self_improvement, Icons.directions_bike,
                                             Icons.pool, Icons.accessibility_new, Icons.spa, Icons.music_note,
                                             Icons.headphones, Icons.palette, Icons.camera_alt, Icons.code,
                                             Icons.laptop, Icons.account_balance_wallet, Icons.savings, Icons.shopping_cart,
                                             Icons.bed,
                                           ].map((icon) {
                                             final selected = _newCatIcon == icon;
                                             return Padding(
                                               padding: const EdgeInsets.only(right: 12),
                                               child: GestureDetector(
                                                 onTap: () => setState(() => _newCatIcon = icon),
                                                 child: Container(
                                                   width: 34,
                                                   height: 34,
                                                   decoration: BoxDecoration(
                                                     color: selected ? _newCatColor.withAlpha((0.15 * 255).round()) : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                                     shape: BoxShape.circle,
                                                     border: Border.all(
                                                       color: selected ? _newCatColor : Colors.transparent,
                                                       width: 2.5,
                                                     ),
                                                     boxShadow: selected
                                                       ? [BoxShadow(color: _newCatColor.withAlpha(80), blurRadius: 6, spreadRadius: 0)]
                                                       : null,
                                                   ),
                                                   child: Icon(
                                                     icon, 
                                                     color: selected ? _newCatColor : theme.colorScheme.onSurfaceVariant,
                                                     size: 18,
                                                   ),
                                                 ),
                                               ),
                                             );
                                           }).toList(),
                                         ),
                                      ),

                                      const SizedBox(height: 24),
                                      Row(
                                         children: [
                                           TextButton(
                                              onPressed: () => setState(() => _isCreatingCategory = false), 
                                              child: Text(l10n.habitBack)
                                           ),
                                           const Spacer(),
                                           FilledButton(
                                              onPressed: _saveNewCategory, 
                                              child: Text(l10n.save)
                                           ),
                                         ],
                                      )
                                    ],
                                  )
                                : Column(
                                    key: const ValueKey('selector_view'),
                                    children: [
                                      SwipeSelector<String>(
                                        items: _allCategories.map((c) => c is HabitCategory ? c.name : c['name'] as String).toList(),
                                        selectedValue: _categoryName,
                                        onChanged: (val) {
                                          setState(() {
                                            _categoryName = val;
                                          });
                                        },
                                        builder: (context, item) {
                                          dynamic cat; 
                                          try {
                                             cat = _customCategories.firstWhere((c) => c.name == item);
                                          } catch (_) {
                                             cat = _defaultCategories.firstWhere((c) => c['name'] == item, orElse: () => _defaultCategories.first);
                                          }
                                          
                                          final isCustom = cat is HabitCategory;
                                          final icon = isCustom ? cat.icon : cat['icon'];
                                          final color = isCustom ? cat.color : cat['color'];
                                          
                                          return Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(_localizedCategoryName(item, l10n), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                                  const SizedBox(width: 8),
                                                  Icon(icon, color: color, size: 20),
                                                ],
                                              ),
                                              if (isCustom)
                                                Positioned(
                                                  right: 0,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                                    onPressed: () => _confirmDeleteCategory(cat),
                                                    tooltip: l10n.habitCategoryDeleteTitle,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: () {
                                             setState(() => _isCreatingCategory = true);
                                          },
                                          icon: const Icon(Icons.add, size: 16),
                                          label: Text(l10n.habitCategoryCreateAction),
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ),
                            ],
                          ),
                    ),

                    const SizedBox(height: 16),
                    FilledButton(
                      style: _nextButtonStyle(theme),
                      onPressed: _habitName.trim().isEmpty ? null : () => _navigateToStep(1),
                      child: Text(l10n.habitNext),
                    ),
                  ] else if (_screen == 1) ...[
                  // -- Step 2: Tracking Type --
                  
                  // Tracking Type
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, animation) {
                        final offsetAnimation = animation.drive(
                          Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutCubic)),
                        );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1.0,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _isTrackingInputFocused
                          ? const SizedBox.shrink(key: ValueKey('tracking_hidden'))
                          : Column(
                              key: const ValueKey('tracking_visible'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                      child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: Text(l10n.habitYesNo),
                                        selected: _type == HabitType.yesNo,
                                        onSelected: (b) => setState(() => _type = HabitType.yesNo),
                                      ),
                                      ChoiceChip(
                                        label: Text(l10n.habitNumeric),
                                        selected: _type == HabitType.numeric,
                                        onSelected: (b) => setState(() => _type = HabitType.numeric),
                                      ),
                                      ChoiceChip(
                                        label: Text(l10n.habitTime),
                                        selected: _type == HabitType.time,
                                        onSelected: (b) => setState(() => _type = HabitType.time),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  switch(_type) {
                                    HabitType.yesNo => l10n.habitTrackingYesNoDescription,
                                    HabitType.numeric => l10n.habitTrackingNumericDescription,
                                    HabitType.time => l10n.habitTrackingTimeDescription,
                                  },
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                    ),
                  ),
                  
                  // Comparator & Goal
                  if (_type != HabitType.yesNo) ...[
                     Align(
                       alignment: Alignment.center,
                       child: SwipeSelector<HabitComparator>(
                          items: HabitComparator.values.where((c) => c != HabitComparator.any).toList(),
                          selectedValue: _comparator,
                          onChanged: (v) => setState(() => _comparator = v),
                          builder: (context, item) {
                             String label = switch(item) {
                                HabitComparator.atLeast => l10n.habitComparatorAtLeast,
                                HabitComparator.lessThan => l10n.habitComparatorLessThan,
                                HabitComparator.exactly => l10n.habitComparatorExactly,
                                HabitComparator.any => l10n.habitComparatorAny, // Should not happen with filter
                             };
                              return Center(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              );
                          },
                       ),
                     ),
                     const SizedBox(height: 20),
                     
                     if (_type == HabitType.numeric) ...[
                        Row(children: [
                           Expanded(
                              child: TextFormField(
                                focusNode: _targetFocus,
                                controller: _targetCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.habitValueLabel,
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                ),
                                  onChanged: (v) {
                                    final trimmed = v.trim();
                                    if (trimmed.isEmpty) {
                                      setState(() => _target = 0.0);
                                      return;
                                    }
                                    
                                    double val = double.tryParse(trimmed) ?? 0.0;
                                    if (val > 10000) {
                                      val = 10000;
                                      _targetCtrl.value = TextEditingValue(
                                        text: "10000",
                                        selection: TextSelection.collapsed(offset: 5),
                                      );
                                    }
                                    setState(() => _target = val);
                                  },
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(5),
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                              child: TextFormField(
                                focusNode: _unitFocus,
                                controller: _unitCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.habitUnitLabel,
                                   hintText: l10n.habitUnitHint,                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                ),
                                onChanged: (v) => setState(() => _unit = v),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(16),
                                  FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
                                ],
                              ),
                           ),
                        ]),
                        const SizedBox(height: 16),
                        Center(child: Text(l10n.habitPerDay, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
                        
                     ] else if (_type == HabitType.time) ...[
                        
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: TextFormField(
                              controller: _timeCtrl,
                              focusNode: _timeFocus,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                              decoration: InputDecoration(
                                hintText: l10n.habitTimePlaceholder,
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              inputFormatters: [],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: Text(l10n.habitPerDay, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
                     ],
                  ],

                   const SizedBox(height: 16),
                   AnimatedSize(
                     duration: const Duration(milliseconds: 300),
                     curve: Curves.easeOutCubic,
                     child: _timeFocus.hasFocus
                       ? const SizedBox.shrink()
                       : _buildCourseSelector(theme),
                   ),
                   const SizedBox(height: 16),
                  
                  // Navigation
                  Row(
                    children: [
                      TextButton(onPressed: () => _navigateToStep(0), child: Text(l10n.habitBack)),
                      const Spacer(),
                      FilledButton(
                        style: _nextButtonStyle(theme),
                        onPressed: _isTrackingNextEnabled ? () => _navigateToStep(2) : null,
                        child: Text(l10n.habitNext),
                      ),
                    ],
                  ),
                ] else if (_screen == 2) ...[
                  // -- Step 3: Frequency --
                  // -- Step 3: Frequency --
                  Text(l10n.habitFrequencyPrompt, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  
                  Column(
                    children: [
                       AnimatedSize(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeOutCubic,
                         child: _isFreqGoalFocused || _isWorkRestFocused
                           ? const SizedBox.shrink()
                           : Column(
                               children: [
                                 _buildFreqOption(
                                    theme,
                                    type: HabitFrequencyType.daily,
                                    title: l10n.habitFrequencyEveryDay,
                                    child: Text(l10n.habitFrequencyDailyDescription, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                 ),
                                 const SizedBox(height: 12),
                                 
                                 _buildFreqOption(
                                    theme,
                                    type: HabitFrequencyType.specificDays,
                                    title: l10n.habitFrequencySpecificTitle,
                                    child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                          Text(l10n.habitFrequencySpecificDescription, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                          const SizedBox(height: 12),
                                          // Sub-selector
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: Row(
                                              children: [
                                                 _buildPeriodTab(theme, l10n.habitFrequencyPeriodWeekLabel, HabitPeriod.week),
                                                 _buildPeriodTab(theme, l10n.habitFrequencyPeriodMonthLabel, HabitPeriod.month),
                                                 _buildPeriodTab(theme, l10n.habitFrequencyPeriodYearLabel, HabitPeriod.year),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (_period == HabitPeriod.week) 
                                             _buildDaySelector(theme)
                                          else if (_period == HabitPeriod.month)
                                             _buildMonthDaySelector(theme) // New method
                                          else if (_period == HabitPeriod.year)
                                             _buildYearSelector(theme), // New method
                                       ],
                                    ),
                                 ),
                                 const SizedBox(height: 8),
                               ],
                             ),
                       ),

                       AnimatedSize(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeOutCubic,
                         child: _isWorkRestFocused 
                           ? const SizedBox.shrink()
                           : Column(
                             children: [
                               _buildFreqOption(
                                  theme,
                                  type: HabitFrequencyType.repeatsInPeriod,
                                  title: l10n.habitFrequencyTimesPerPeriodTitle,
                                  child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                        Text(l10n.habitFrequencyTimesPerPeriodDescription, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                        const SizedBox(height: 12),
                                        Row(
                                           mainAxisAlignment: MainAxisAlignment.start,
                                           children: [
                                             SizedBox(width: 80, child: Builder(
                                               builder: (context) {
                                                 return TextFormField(
                                                   key: const ValueKey('frequency_goal_input'),
                                                   focusNode: _freqGoalFocus,
                                                   controller: _frequencyGoalCtrl,
                                                       keyboardType: TextInputType.number,
                                                       textAlign: TextAlign.center,
                                                       inputFormatters: [
                                                          FilteringTextInputFormatter.digitsOnly,
                                                          FilteringTextInputFormatter.deny(RegExp(r'^0')),
                                                          LengthLimitingTextInputFormatter(3),
                                                       ],
                                                       decoration: InputDecoration(
                                                         isDense: true,
                                                         filled: true,
                                                         fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                         enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                                       ),
                                        onChanged: (v) {
                                                  final trimmed = v.trim();
                                                  if (trimmed.isEmpty) {
                                                    setState(() => _frequencyGoal = 1);
                                                    return;
                                                  }
                                                  int val = int.tryParse(trimmed) ?? 1;
                                                  if (val < 1) {
                                                    val = 1;
                                                    _frequencyGoalCtrl.text = "$val";
                                                    _frequencyGoalCtrl.selection = TextSelection.fromPosition(TextPosition(offset: 1));
                                                  }
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
                                                  setState(() => _frequencyGoal = val);
                                                },
                                             );
                                          }
                                       )),
                                              const SizedBox(width: 12),
                                              Text(l10n.habitTimesPerLabel),
                                              const SizedBox(width: 12),
                                              
                                              // Tap to toggle period
                                              GestureDetector(
                                                onTap: () {
                                                   setState(() {
                                                      final nextIndex = (_period.index + 1) % HabitPeriod.values.length;
                                                      _period = HabitPeriod.values[nextIndex];
                                                      // Clamp
                                                      final maxVal = switch(_period) {
                                                         HabitPeriod.week => 7,
                                                         HabitPeriod.month => 31,
                                                         HabitPeriod.year => 365,
                                                      };
                                                      if (_frequencyGoal > maxVal) _frequencyGoal = maxVal;
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
                             ],
                           ),
                       ),

                        AnimatedSize(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeOutCubic,
                          child: _isFreqGoalFocused 
                           ? const SizedBox.shrink()
                          : _buildFreqOption(
                            theme,
                            type: HabitFrequencyType.interval,
                            title: l10n.habitFrequencyWorkRestTitle,
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Text(l10n.habitFrequencyWorkRestDescription, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                   const SizedBox(height: 12),
                                   Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                         Text("${l10n.habitWorkLabel} "),
                                        SizedBox(width: 60, child: Builder(
                                          builder: (context) {
                                            return TextFormField(
                                              key: const ValueKey('work_days_input'),
                                              focusNode: _workDaysFocus,
                                              controller: _workDaysCtrl,
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  inputFormatters: [
                                                     FilteringTextInputFormatter.digitsOnly,
                                                     FilteringTextInputFormatter.deny(RegExp(r'^0')),
                                                     LengthLimitingTextInputFormatter(3),
                                                  ],
                                                   decoration: InputDecoration(
                                                     isDense: true, 
                                                     filled: true,
                                                     fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                     enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                     focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                                     hintText: "0",
                                                   ),
                                                onChanged: (v) {
                                                  final trimmed = v.trim();
                                                  if (trimmed.isEmpty) {
                                                    setState(() => _interval = 1);
                                                    return;
                                                  }
                                                  int val = int.tryParse(trimmed) ?? 1;
                                                  if (val < 1) {
                                                    val = 1;
                                                    _workDaysCtrl.text = "$val";
                                                    _workDaysCtrl.selection = TextSelection.fromPosition(TextPosition(offset: 1));
                                                  }
                                                  if (val > 365) {
                                                    val = 365;
                                                    _workDaysCtrl.text = "$val";
                                                    _workDaysCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _workDaysCtrl.text.length));
                                                  }
                                                  setState(() => _interval = val);
                                                },
                                             );
                                          }
                                       )),
                                         const SizedBox(width: 12),
                                         const Text("×"),
                                         const SizedBox(width: 12),
                                        SizedBox(width: 60, child: Builder(
                                          builder: (context) {
                                            return TextFormField(
                                              key: const ValueKey('rest_days_input'),
                                              focusNode: _restDaysFocus,
                                              controller: _restDaysCtrl,
                                                  keyboardType: TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  inputFormatters: [
                                                     FilteringTextInputFormatter.digitsOnly,
                                                     FilteringTextInputFormatter.deny(RegExp(r'^0')),
                                                     LengthLimitingTextInputFormatter(3),
                                                  ],
                                                   decoration: InputDecoration(
                                                     isDense: true, 
                                                     filled: true,
                                                     fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                     enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                     focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                                     hintText: "0",
                                                   ),
                                                onChanged: (v) {
                                                  final trimmed = v.trim();
                                                  if (trimmed.isEmpty) {
                                                    setState(() => _frequencyGoal = 1);
                                                    return;
                                                  }
                                                  int val = int.tryParse(trimmed) ?? 1;
                                                  if (val < 1) {
                                                    val = 1;
                                                    _restDaysCtrl.text = "$val";
                                                    _restDaysCtrl.selection = TextSelection.fromPosition(TextPosition(offset: 1));
                                                  }
                                                  if (val > 365) {
                                                    val = 365;
                                                    _restDaysCtrl.text = "$val";
                                                    _restDaysCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _restDaysCtrl.text.length));
                                                  }
                                                   setState(() => _frequencyGoal = val);
                                                 },
                                              );
                                          }
                                       )),
                                         Text(" ${l10n.habitRestLabel}"),
                                      ],
                                   ),
                                ],
                             ),
                          ),
                       ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  
                  // Navigation
                  Row(
                    children: [
                      TextButton(onPressed: () => _navigateToStep(1), child: Text(l10n.habitBack)),
                      const Spacer(),
                      FilledButton(
                        style: _nextButtonStyle(theme),
                        onPressed: _isFrequencyNextEnabled ? () => _navigateToStep(3) : null,
                        child: Text(l10n.habitNext),
                      ),
                    ],
                  ),
                ] else if (_screen == 3) ...[
                  // -- Step 4: When? --
                  Text(l10n.habitChooseTimeRangeTitle, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    title: Text(l10n.habitStartDateLabel),
                    subtitle: Text(DateFormat.yMMMd(localeName).format(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(l10n.habitEndDateLabel),
                    subtitle: Text(_endDate == null ? l10n.habitNoEndDate : DateFormat.yMMMd(localeName).format(_endDate!)),
                    trailing: _endDate == null ? const Icon(Icons.add) : const Icon(Icons.close),
                    onTap: () async {
                      if (_endDate != null) {
                        setState(() => _endDate = null);
                        return;
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate.add(const Duration(days: 30)),
                        firstDate: _startDate.isAfter(DateTime(2025, 1, 1)) ? _startDate : DateTime(2025, 1, 1),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),

                  const SizedBox(height: 32),
                  
                  // Navigation & Create
                  Row(
                    children: [
                      TextButton(onPressed: () => _navigateToStep(2), child: Text(l10n.habitBack)),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l10n.habitCreateAction),
                      )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreqOption(ThemeData theme, {required HabitFrequencyType type, required String title, required Widget child}) {
     final selected = _freq == type;
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         GestureDetector(
           onTap: () => setState(() => _freq = type),
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
                  // Clear weekDays when switching periods to avoid incompatible data
                  // Week uses 1-7, Month uses 1-31, Year uses MMDD encoding
                  _weekDays.clear();
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

  Widget _buildPeriodToggle(ThemeData theme, HabitPeriod p) {
       final l10n = AppLocalizations.of(context)!;
       final label = _periodLabel(p, l10n);
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
               label.toUpperCase(),
               key: ValueKey(p),
               style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
            ),
          ),
       );
  }

  Widget _buildMonthDaySelector(ThemeData theme) {
     // Display 1-31 in rows of 6, centered
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
      final localeName = AppLocalizations.of(context)!.localeName;
      final months = List.generate(12, (i) => DateFormat.MMM(localeName).format(DateTime(2024, i + 1, 1)));
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Wrap(
             spacing: 8, runSpacing: 8,
             children: _weekDays.where((encoded) {
                 // Validate: month should be 1-12, day should be 1-31
                 final m = encoded ~/ 100;
                 final d = encoded % 100;
                 return m >= 1 && m <= 12 && d >= 1 && d <= 31;
             }).map((encoded) {
                 final m = encoded ~/ 100;
                 final d = encoded % 100;
                 return Chip(
                   label: Text("${months[m-1]} $d"),
                   onDeleted: () => setState(() => _weekDays.remove(encoded)),
                 );
             }).toList(),
           ),
           const SizedBox(height: 12),
           OutlinedButton.icon(
             onPressed: () async {
                 // Custom picker or standard? Standard supports one date.
                 final now = DateTime.now();
                 final picked = await showDatePicker(
                    context: context, 
                    initialDate: now, 
                    firstDate: DateTime(now.year, 1, 1), 
                    lastDate: DateTime(now.year, 12, 31)
                 );
                 if (picked != null) {
                    final encoded = picked.month * 100 + picked.day;
                 setState(() => _weekDays.add(encoded));
               }
             }, 
             icon: const Icon(Icons.add), 
             label: Text(AppLocalizations.of(context)!.habitAddDateAction),
           ),
        ],
      );
  }


  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        const SizedBox(width: 48),
        Expanded(
            child: Text(
            switch(_screen) {
              0 => l10n.habitCreateTitle,
              1 => l10n.habitTrackingTitle,
              2 => l10n.habitFrequencySectionTitle,
              3 => l10n.habitSchedulingTitle,
              _ => l10n.habitCreateTitle,
            },
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48), // Balance close button
      ],
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    final narrowWeekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final days = [...narrowWeekdays.skip(1), narrowWeekdays.first];
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

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    
    try {
      final auth = context.read<AuthController>();
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception("User not signed in");

      final name = _habitName;
      final color = _currentCatData['color'] as Color;
      final category = _currentCatData['name'] as String;

      Habit habit;
      if (widget.habit != null) {
        // Update existing habit, preserving ID/stats/sortOrder/history
        habit = widget.habit!.copyWith(
           name: name,
           color: color,
           iconCodePoint: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).codePoint : 0xe156,
           iconFamily: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).fontFamily : null,
           iconPackage: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).fontPackage : null,
           category: category,
           type: _type,
           targetValue: _target,
           unit: _unit,
           comparator: _comparator,
           frequencyType: _freq,
           weekDays: _weekDays,
           intervalDays: _interval,
           frequencyPeriod: _period,
           frequencyGoal: _frequencyGoal,
           startDate: _startDate,
           endDate: _endDate,
           connectedCourseIds: _connectedCourseIds,
        );
      } else {
        // Create new habit
        habit = Habit(
           id: '',
           name: name,
           color: color,
           iconCodePoint: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).codePoint : 0xe156,
           iconFamily: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).fontFamily : null,
           iconPackage: _currentCatData['icon'] is IconData ? (_currentCatData['icon'] as IconData).fontPackage : null,
           category: category,
           type: _type,
           targetValue: _target,
           unit: _unit,
           comparator: _comparator,
           frequencyType: _freq,
           weekDays: _weekDays,
           intervalDays: _interval,
           frequencyPeriod: _period,
           frequencyGoal: _frequencyGoal,
           startDate: _startDate,
           endDate: _endDate,
           createdAt: DateTime.now(),
           connectedCourseIds: _connectedCourseIds,
        );
      }

      await context.read<HabitService>().createHabit(uid, habit);
      if (mounted) {
         // Trigger explicit sync
         context.read<AppState>().triggerSync();
         Navigator.pop(context);
      }
      
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.habitsListError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _saveNewCategory() async {
    if (_newCatName.trim().isEmpty) return;
    
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    
    final cat = HabitCategory(
       id: DateTime.now().millisecondsSinceEpoch.toString(), 
       name: _newCatName.trim(), 
       color: _newCatColor, 
       iconCodePoint: _newCatIcon.codePoint,
       isCustom: true,
    );
    
    await context.read<HabitService>().createCategory(uid, cat);
    // After load, switch validation
    if (mounted) {
       setState(() {
          _isCreatingCategory = false;
          _categoryName = _newCatName.trim();
       });
    }
  }

  Future<void> _confirmDeleteCategory(HabitCategory cat) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
          title: Text(l10n.habitCategoryDeleteTitle),
          content: Text(l10n.habitCategoryDeleteMessage(cat.name)),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
             FilledButton(
               onPressed: () => Navigator.pop(ctx, true), 
               style: FilledButton.styleFrom(backgroundColor: Colors.red),
               child: Text(l10n.delete)
             ),
          ],
       )
    );
    
    if (ok == true && mounted) {
       final auth = context.read<AuthController>();
       final uid = auth.currentUser?.uid;
       if (uid != null) {
          await context.read<HabitService>().deleteCategory(uid, cat.id);
          if (mounted) {
             setState(() {
                _categoryName = _defaultCategories[0]['name'];
             });
          }
       }
    }
  }

  Widget _buildCourseSelector(ThemeData theme) {
     final courses = context.watch<AppState>().courses;
     if (courses.isEmpty) return const SizedBox.shrink();
     
     // Only show for Yes/No and Time
     if (_type != HabitType.yesNo && _type != HabitType.time) return const SizedBox.shrink();
     
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(AppLocalizations.of(context)!.habitConnectCourse, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
           const SizedBox(height: 8),
           Text(
             AppLocalizations.of(context)!.habitCourseSyncHint,
             style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
           ),
           const SizedBox(height: 12),
           SizedBox(
             height: 40,
             child: ListView.separated(
               scrollDirection: Axis.horizontal,
               itemCount: courses.length,
               separatorBuilder: (_, __) => const SizedBox(width: 8),
               itemBuilder: (context, index) {
                  final c = courses[index];
                  final isSelected = _connectedCourseIds.contains(c.id);
                  return FilterChip(
                     label: Text(c.name),
                     selected: isSelected,
                     onSelected: (selected) {
                        setState(() {
                           if (selected) {
                             _connectedCourseIds.add(c.id);
                           } else {
                             _connectedCourseIds.remove(c.id);
                           }
                        });
                     },
                     avatar: CircleAvatar(
                        backgroundColor: c.color,
                        radius: 8,
                     ),
                     showCheckmark: false,
                     labelStyle: TextStyle(
                        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                     ),
                     selectedColor: theme.colorScheme.primary,
                     backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant)),
                     padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
               },
             ),
           ),
        ],
     );
  }
}
