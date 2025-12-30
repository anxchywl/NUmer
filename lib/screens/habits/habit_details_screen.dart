import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../models/habit_category.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import '../../services/habit_scheduler.dart';
import 'widgets/habit_schedule_editor.dart';
import '../../app_state.dart';
import 'swipe_selector.dart';

class HabitDetailsScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailsScreen({super.key, required this.habit});

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> with TickerProviderStateMixin {
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
  
  // -- State --
  late String _habitName;
  late String _categoryName;
  
  // Custom Category Creation Form
  bool _isCreatingCategory = false;
  String _newCatName = "";
  Color _newCatColor = Colors.blue;
  IconData _newCatIcon = Icons.star;

  // Tracking
  late HabitType _type;
  late double _target;
  late String _unit;
  late HabitComparator _comparator;

  // Frequency & Schedule
  late HabitFrequencyType _freq;
  late Set<int> _weekDays;
  late int _interval;
  late HabitPeriod _period;
  late int _frequencyGoal;
  
  // Course Integration
  List<String> _connectedCourseIds = [];

  // Schedule
  late DateTime _startDate;
  late DateTime? _endDate;
  late bool _archived;

  // Reminder Settings
  bool _hasReminder = false;
  int? _reminderHour;
  int? _reminderMinute;

  // Time Helpers
  final _timeCtrl = TextEditingController(text: "00:00:00");
  late TextEditingController _targetCtrl;
  late TextEditingController _unitCtrl;

  bool _isDirty = false;
  // Scroll tracking for header fade
  late ScrollController _scrollController;
  double _lastScrollOffset = 0.0;
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    
    _habitName = h.name;
    _categoryName = h.category;
    _type = h.type;
    _target = h.targetValue;
    _unit = h.unit ?? "";
    _comparator = h.comparator;
    _freq = h.frequencyType;
    _weekDays = Set.from(h.weekDays);
    _interval = h.intervalDays;
    _period = h.frequencyPeriod ?? HabitPeriod.week;
    _frequencyGoal = h.frequencyGoal ?? 3;
    _startDate = h.startDate;
    _endDate = h.endDate;
    _archived = h.archived;
    _connectedCourseIds = List.from(h.connectedCourseIds);

    // Reminder Settings
    _hasReminder = h.hasReminder;
    _reminderHour = h.reminderHour;
    _reminderMinute = h.reminderMinute;

    // Time Control Init
    if (_type == HabitType.time) {
      final totalSeconds = _target.toInt();
      final hh = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
      final mm = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final ss = (totalSeconds % 60).toString().padLeft(2, '0');
      _timeCtrl.text = "$hh:$mm:$ss";
    }

    _timeCtrl.addListener(_onTimeChanged);
    
    // Initialize Controllers
    _targetCtrl = TextEditingController(text: _type == HabitType.numeric ? "$_target" : "");
    _unitCtrl = TextEditingController(text: _unit);
    // Removed old frequency controllers as they are now handled by HabitScheduleEditor

    _loadCustomCategories();

    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final delta = offset - _lastScrollOffset;
    if (delta > 2 && _showHeader) {
      setState(() => _showHeader = false);
    } else if (delta < -2 && !_showHeader) {
      setState(() => _showHeader = true);
    }
    _lastScrollOffset = offset.clamp(0.0, double.infinity);
  }

  void _markDirty() {
    setState(() => _isDirty = true);
  }

  String _normalizeHms(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return '00:00:00';
    String hh = '00', mm = '00', ss = '00';
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
    final parts = norm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    final newTarget = (h * 3600 + m * 60 + s).toDouble();
    if (_target != newTarget) {
      _target = newTarget;
      _markDirty();
    }
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

  List<dynamic> get _allCategories => [..._customCategories, ..._defaultCategories];

  Map<String, dynamic> get _currentCatData {
    try {
      final custom = _customCategories.firstWhere((c) => c.name == _categoryName);
      return {'name': custom.name, 'icon': custom.icon, 'color': custom.color, 'isCustom': true, 'id': custom.id};
    } catch (_) {}
    return _defaultCategories.firstWhere((c) => c['name'] == _categoryName, orElse: () => _defaultCategories.last);
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = context.read<AuthController>().currentUser?.uid;
    if (uid == null) return;

    // Get current category data (Icon & Color)
    final catData = _currentCatData;
    final color = catData['color'] as Color;
    // CRITICAL FIX: Ensure icon is saved
    final iconData = catData['icon'] as IconData;

    final updatedHabit = Habit(
      id: widget.habit.id,
      name: _habitName,
      color: color,
      iconCodePoint: iconData.codePoint,
      iconFamily: iconData.fontFamily,
      iconPackage: iconData.fontPackage,
      category: _categoryName,
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
      totalCompletions: widget.habit.totalCompletions,
      currentStreak: widget.habit.currentStreak,
      longestStreak: widget.habit.longestStreak,
      last7: widget.habit.last7,
      archived: _archived,
      createdAt: widget.habit.createdAt,
      connectedCourseIds: _connectedCourseIds,
      hasReminder: _hasReminder,
      reminderHour: _reminderHour,
      reminderMinute: _reminderMinute,
    );

    await context.read<HabitService>().createHabit(uid, updatedHabit);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changes saved"), duration: Duration(seconds: 1)));
      setState(() => _isDirty = false);
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
    if (mounted) {
       setState(() {
          _isCreatingCategory = false;
          _categoryName = _newCatName.trim();
          _markDirty();
       });
    }
  }

  Future<void> _deleteHabit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete habit?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = context.read<AuthController>().currentUser?.uid;
      if (uid != null) {
        await context.read<HabitService>().deleteHabit(uid, widget.habit.id);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: const Text("Edit Habit"),
            floating: true,
            pinned: false,
            snap: true,
            actions: [
               if (_isDirty)
                TextButton(
                  onPressed: _save,
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
               IconButton(
                 icon: const Icon(Icons.delete_outline, color: Colors.red),
                 onPressed: _deleteHabit,
               ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // -- GENERAL SECTION --
                _sectionHeader("General"),
                TextFormField(
                  initialValue: _habitName,
              decoration: InputDecoration(
                labelText: "Habit Name",
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (v) { _habitName = v; _markDirty(); },
            ),
            const SizedBox(height: 24),
            
            // Category Selector
            Text("Category", style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            _buildCategorySelector(theme),
            
            const SizedBox(height: 32),

             // -- TRACKING SECTION --
            _sectionHeader("Tracking"),
            _buildTrackingSection(theme),
            const SizedBox(height: 32),

            // -- SCHEDULE SECTION --
            // Replaces Frequency and Schedule sections
            HabitScheduleEditor(
               frequencyType: _freq,
               weekDays: _weekDays,
               intervalDays: _interval,
               period: _period,
               frequencyGoal: _frequencyGoal,
               startDate: _startDate,
               endDate: _endDate,
               onChanged: (data) {
                  setState(() {
                     _freq = data.frequencyType;
                     _weekDays = data.weekDays;
                     _interval = data.intervalDays;
                     _period = data.period;
                     _frequencyGoal = data.frequencyGoal;
                     _startDate = data.startDate;
                     _endDate = data.endDate;
                     _markDirty();
                  });
               },
            ),

            const SizedBox(height: 32),
            
            // -- ADVANCED --
            _sectionHeader("Advanced"),
            _buildAdvancedSection(theme),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return Column(
      children: [
        SwipeSelector<String>(
          items: _allCategories.map((c) => c is HabitCategory ? c.name : c['name'] as String).toList(),
          selectedValue: _categoryName,
          onChanged: (val) {
            setState(() {
              _categoryName = val;
              _markDirty();
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
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 20),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Custom Category Toggle
        GestureDetector(
           onTap: () {
              setState(() { 
                 _isCreatingCategory = !_isCreatingCategory;
              });
           },
           child: Row(
              children: [
                 Icon(_isCreatingCategory ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, color: theme.colorScheme.primary),
                 const SizedBox(width: 8),
                 Text("Create Custom", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
           ),
        ),
        
        AnimatedSize(
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeInOut,
           child: _isCreatingCategory ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildCategoryCreationForm(theme),
           ) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCategoryCreationForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(labelText: "Category Name", hintText: "e.g. Reading"),
          onChanged: (v) => _newCatName = v,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        SizedBox(
           height: 40,
           child: ListView(
             scrollDirection: Axis.horizontal,
             children: Colors.primaries.map((c) => Padding(
               padding: const EdgeInsets.only(right: 8),
               child: GestureDetector(
                 onTap: () => setState(() => _newCatColor = c),
                 child: CircleAvatar(
                   backgroundColor: c,
                   radius: 16,
                   child: _newCatColor == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                 ),
               ),
             )).toList(),
           ),
        ),
        const SizedBox(height: 12),
        SizedBox(
           height: 50,
           child: ListView(
             scrollDirection: Axis.horizontal,
             children: [
               Icons.local_fire_department, Icons.check_circle, Icons.calendar_today, Icons.access_time, 
               Icons.track_changes, Icons.star, Icons.bolt, Icons.favorite, Icons.psychology, 
               Icons.fitness_center, Icons.menu_book, Icons.eco, Icons.water_drop, Icons.nightlight_round, 
               Icons.wb_sunny, Icons.directions_walk, Icons.emoji_events, Icons.auto_awesome, 
             ].map((icon) {
               final selected = _newCatIcon == icon;
               return Padding(
                 padding: const EdgeInsets.only(right: 12),
                 child: GestureDetector(
                   onTap: () => setState(() => _newCatIcon = icon),
                   child: Container(
                     width: 48,
                     height: 48,
                     decoration: BoxDecoration(
                       color: selected ? _newCatColor.withAlpha(50) : Colors.transparent,
                       shape: BoxShape.circle,
                       border: Border.all(color: selected ? _newCatColor : theme.colorScheme.outlineVariant, width: selected ? 2 : 1),
                     ),
                     child: Icon(icon, color: selected ? _newCatColor : theme.colorScheme.onSurfaceVariant, size: 24),
                   ),
                 ),
               );
             }).toList(),
           ),
        ),
        const SizedBox(height: 24),
        Row(
           children: [
             TextButton(onPressed: () => setState(() => _isCreatingCategory = false), child: const Text("Cancel")),
             const Spacer(),
             FilledButton(onPressed: _saveNewCategory, child: const Text("Save Category")),
           ],
        )
      ],
    );
  }

  Widget _buildTrackingSection(ThemeData theme) {
     return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Wrap(
             spacing: 8, runSpacing: 8,
             children: [
                _buildTypeChip("Yes / No", HabitType.yesNo),
                _buildTypeChip("Numeric", HabitType.numeric),
                _buildTypeChip("Time", HabitType.time),
             ],
           ),
           const SizedBox(height: 16),
           
           if (_type != HabitType.yesNo) ...[
              SwipeSelector<HabitComparator>(
                items: HabitComparator.values.where((c) => c != HabitComparator.any).toList(),
                selectedValue: _comparator,
                onChanged: (v) => setState(() { _comparator = v; _markDirty(); }),
                builder: (context, item) {
                   String label = switch(item) {
                      HabitComparator.atLeast => "At least",
                      HabitComparator.lessThan => "Less than",
                      HabitComparator.exactly => "Exactly",
                      HabitComparator.any => "Any value",
                   };
                    return Container(alignment: Alignment.center, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)));
                },
             ),
             const SizedBox(height: 16),
           ],
           
           if (_type == HabitType.numeric)
            Row(children: [
               Expanded(
                  child: TextFormField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Value", filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      if (_target != val) { _target = val; _markDirty(); }
                    },
                  ),
               ),
               const SizedBox(width: 12),
               Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: InputDecoration(labelText: "Unit", hintText: "e.g. pages", filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    onChanged: (v) { _unit = v; _markDirty(); },
                  ),
               ),
            ]),
           if (_type == HabitType.time)
             Center(
               child: SizedBox(
                 width: 200,
                 child: TextFormField(
                   controller: _timeCtrl,
                   keyboardType: TextInputType.number,
                   textAlign: TextAlign.center,
                   style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                   decoration: InputDecoration(
                     hintText: "00:00:00", filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                   ),
                   onChanged: (v) => _markDirty(),
                 ),
               ),
             ),
           const SizedBox(height: 24),
           
           _buildCourseSelector(theme),
        ],
     );
  }

  Widget _buildTypeChip(String label, HabitType type) {
     final isSelected = _type == type;
     // Disable Numeric if courses connected
     final isDisabled = type == HabitType.numeric && _connectedCourseIds.isNotEmpty;
     
     return FilterChip(
       label: Text(label),
       selected: isSelected,
       onSelected: isDisabled ? null : (b) {
          setState(() { _type = type; _markDirty(); });
       },
       backgroundColor: isDisabled ? Colors.grey.withValues(alpha: 0.1) : null,
     );
  }

   Widget _buildCourseSelector(ThemeData theme) {
     final courses = context.watch<AppState>().courses;
     if (courses.isEmpty) return const SizedBox.shrink();
     
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Icon(Icons.link, size: 20, color: theme.colorScheme.primary),
               const SizedBox(width: 8),
               Text("Connect Course", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
             ],
           ),
           const SizedBox(height: 8),
           Text(
             "Syncs progress when you study for these courses.",
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
                  final isDisabled = _type == HabitType.numeric;
                  
                  return FilterChip(
                     label: Text(c.name),
                     selected: isSelected,
                     onSelected: isDisabled ? null : (selected) {
                        setState(() {
                           if (selected) {
                             _connectedCourseIds.add(c.id);
                           } else {
                             _connectedCourseIds.remove(c.id);
                           }
                           _markDirty();
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
           if (_type == HabitType.numeric && courses.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: Text("Switch to Yes/No or Time to connect courses.", style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
             ),
        ],
     );
  }



  // To be called from build body
  Widget _buildAdvancedSection(ThemeData theme) {
     return Column(
       children: [
          // Remind Me Button
          ListTile(
             contentPadding: EdgeInsets.zero,
             leading: Icon(
               _hasReminder ? Icons.notifications_active : Icons.notifications_active_outlined,
               color: _hasReminder ? theme.colorScheme.primary : null,
             ),
             title: const Text("Remind Me"),
             subtitle: _hasReminder && _reminderHour != null && _reminderMinute != null
               ? Text("${_reminderHour!.toString().padLeft(2, '0')}:${_reminderMinute!.toString().padLeft(2, '0')}")
               : const Text("Off"),
             trailing: const Icon(Icons.chevron_right),
             onTap: _showRemindMeModal,
          ),
          
          ListTile(
             contentPadding: EdgeInsets.zero,
             leading: const Icon(Icons.archive),
             title: const Text("Archive Habit"),
             trailing: Switch(value: _archived, onChanged: (v) { setState(() { _archived = v; _markDirty(); }); }),
          ),
          
          ListTile(
             contentPadding: EdgeInsets.zero,
             leading: const Icon(Icons.restart_alt, color: Colors.red),
             title: const Text("Reset Habit Progress", style: TextStyle(color: Colors.red)), 
             subtitle: const Text("Clears all history"),
             trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                    final habitService = context.read<HabitService>();
                    final uid = context.read<AuthController>().currentUser?.uid;

                    final ok = await showDialog<bool>(
                       context: context, 
                       builder: (c) => AlertDialog(
                         title: const Text("Reset Habit Progress?"), 
                         content: const Text("This will delete all completion history for this habit. It cannot be undone."),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")), 
                           TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Reset"))
                         ]
                      )
                    );
                    
                    if (ok != true) return;
                    
                    if (uid != null) {
                       await habitService.resetHabitProgress(uid, widget.habit.id);
                       if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Habit progress reset")));
                         setState(() {});
                       }
                    }
                },
                child: const Text("Reset"),
             ),
          ),
       ],
     );
  }

  void _showRemindMeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
         return HabitReminderSheet(
           hasReminder: _hasReminder,
           hour: _reminderHour ?? 12,
           minute: _reminderMinute ?? 0,
           frequencyType: _freq,
           weekDays: _weekDays,
           intervalDays: _interval,
           frequencyPeriod: _period,
           frequencyGoal: _frequencyGoal,
           startDate: _startDate,
           endDate: _endDate,
           onSave: (hasReminder, hour, minute) {
             setState(() {
               _hasReminder = hasReminder;
               _reminderHour = hour;
               _reminderMinute = minute;
               _markDirty();
             });
           },
         );
      },
    );
  }
}

// Extension for string capitalize
extension StringCamelCase on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class HabitReminderSheet extends StatefulWidget {
  final bool hasReminder;
  final int hour;
  final int minute;
  final void Function(bool hasReminder, int hour, int minute) onSave;
  final HabitFrequencyType frequencyType;
  final Set<int> weekDays;
  final int intervalDays;
  final HabitPeriod? frequencyPeriod;
  final int? frequencyGoal;
  final DateTime startDate;
  final DateTime? endDate;

  const HabitReminderSheet({
    super.key,
    required this.hasReminder,
    required this.hour,
    required this.minute,
    required this.onSave,
    required this.frequencyType,
    required this.weekDays,
    required this.intervalDays,
    required this.frequencyPeriod,
    required this.frequencyGoal,
    required this.startDate,
    this.endDate,
  });

  @override
  State<HabitReminderSheet> createState() => _HabitReminderSheetState();
}

class _HabitReminderSheetState extends State<HabitReminderSheet> {
  late bool _enabled;
  int _focusedIndex = 0; // 0: hour, 1: min
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;
  DateTime? _nextTrigger;

  @override
  void initState() {
    super.initState();
    _enabled = widget.hasReminder;
    _hourCtrl = FixedExtentScrollController(initialItem: widget.hour);
    _minCtrl = FixedExtentScrollController(initialItem: widget.minute);
    
    _hourCtrl.addListener(_updateNextTrigger);
    _minCtrl.addListener(_updateNextTrigger);
    _updateNextTrigger();
  }

  void _updateNextTrigger() {
    // Safely get selection, falling back to widget defaults if not yet attached
    final currentHour = _hourCtrl.hasClients ? _hourCtrl.selectedItem : widget.hour;
    final currentMin = _minCtrl.hasClients ? _minCtrl.selectedItem : widget.minute;

    // Create a temporary habit for calculation
    final tempHabit = Habit(
      id: "temp",
      name: "temp",
      color: Colors.blue,
      startDate: widget.startDate,
      endDate: widget.endDate,
      createdAt: DateTime.now(),
      frequencyType: widget.frequencyType,
      weekDays: widget.weekDays,
      intervalDays: widget.intervalDays,
      frequencyPeriod: widget.frequencyPeriod,
      frequencyGoal: widget.frequencyGoal,
      hasReminder: true,
      reminderHour: currentHour,
      reminderMinute: currentMin,
    );

    final next = HabitScheduler.getNextTriggerDateTime(
      now: DateTime.now(),
      habit: tempHabit,
      history: [], // We don't have history in this sheet easily, acceptable for MVP feedback
    );

    if (_nextTrigger != next) {
      if (mounted) setState(() => _nextTrigger = next);
    }
  }
  
  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
       padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
       width: double.infinity,
       child: SingleChildScrollView(
         child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text("Set Reminder", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
               const SizedBox(height: 24),
               
               // Time Selector (HH:MM)
               Text("Time", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               SizedBox(
                 height: 150,
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                     // Interaction Indicators
                     Container(
                       height: 50,
                       decoration: BoxDecoration(
                         color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                         borderRadius: BorderRadius.circular(12),
                       ),
                     ),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          _buildPicker(0, _hourCtrl, 24, "h"),
                          const Text(" : ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                          _buildPicker(1, _minCtrl, 60, "m"),
                       ],
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 16),
  
               // Next Reminder Feedback
               if (_nextTrigger != null)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   decoration: BoxDecoration(
                     color: theme.colorScheme.primary.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Row(
                     children: [
                       Icon(Icons.event_available, size: 20, color: theme.colorScheme.primary),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           "Next reminder: ${_formatNextTrigger(_nextTrigger!)}",
                           style: theme.textTheme.bodyMedium?.copyWith(
                             color: theme.colorScheme.onSurface,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ),
                     ],
                   ),
                 )
               else
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   decoration: BoxDecoration(
                     color: theme.colorScheme.error.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Row(
                     children: [
                       Icon(Icons.event_busy, size: 20, color: theme.colorScheme.error),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           "No upcoming reminder found",
                           style: theme.textTheme.bodyMedium?.copyWith(
                             color: theme.colorScheme.error,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
  
               const SizedBox(height: 16),
               Row(
                 children: [
                   if (_enabled) 
                     Expanded(
                       child: OutlinedButton(
                         onPressed: () {
                           widget.onSave(false, 0, 0);
                           Navigator.pop(context);
                         },
                         child: const Text("Turn Off"),
                       ),
                     ),
                   if (_enabled) const SizedBox(width: 12),
  
                   Expanded(
                     child: FilledButton(
                       onPressed: () {
                          widget.onSave(
                            true,
                            _hourCtrl.selectedItem,
                            _minCtrl.selectedItem,
                          );
                          Navigator.pop(context);
                       }, 
                       child: const Text("Save")
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 8), // Minimal bottom padding
            ],
         ),
       ),
    );
  }

  Widget _buildPicker(int index, FixedExtentScrollController ctrl, int count, String label) {
    final isFocused = _focusedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _focusedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  if (_focusedIndex != index) {
                    setState(() => _focusedIndex = index);
                  }
                }
                return false;
              },
              child: ListWheelScrollView.useDelegate(
                controller: ctrl,
                itemExtent: 50,
                perspective: 0.005,
                diameterRatio: 1.2,
                overAndUnderCenterOpacity: 0.2, // Tint/Dim non-selected items
                physics: const FixedExtentScrollPhysics(),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: count,
                  builder: (context, itemIndex) {
                    return Center(
                      child: AnimatedDefaultTextStyle(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeOutCubic,
                         style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            fontWeight: isFocused ? FontWeight.w900 : FontWeight.normal,
                            color: isFocused ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            fontSize: isFocused ? 32 : 24,
                         ),
                         child: Text(itemIndex.toString().padLeft(2, '0')),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNextTrigger(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final triggerDay = DateTime(dt.year, dt.month, dt.day);

    String dayStr;
    if (triggerDay == today) {
      dayStr = "Today";
    } else if (triggerDay == tomorrow) {
      dayStr = "Tomorrow";
    } else {
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      dayStr = "${dt.day} ${months[dt.month - 1]}";
    }

    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return "$dayStr at $hour:$min";
  }
}
