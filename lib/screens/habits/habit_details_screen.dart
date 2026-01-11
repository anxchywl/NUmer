import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../models/habit_category.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';

import 'widgets/habit_schedule_editor.dart';
import '../../app_state.dart';
import 'swipe_selector.dart';
import '../../l10n/app_localizations.dart';

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

  // Time Helpers
  final _timeCtrl = TextEditingController(text: "00:00:00");
  late TextEditingController _targetCtrl;
  late TextEditingController _unitCtrl;

  bool _isDirty = false;
  // Scroll tracking for header fade
  late ScrollController _scrollController;

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
    _scrollController = ScrollController();
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

  @override
  void dispose() {
    _timeCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
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
    );

    await context.read<HabitService>().createHabit(uid, updatedHabit);
    
    if (mounted) {
      context.read<AppState>().triggerSync();
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
       context.read<AppState>().triggerSync();
       setState(() {
          _isCreatingCategory = false;
          _categoryName = _newCatName.trim();
          _markDirty();
       });
    }
  }

  Future<void> _deleteHabit() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.habitDeleteTitle),
        content: Text(l10n.habitDeleteMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = context.read<AuthController>().currentUser?.uid;
      if (uid != null) {
        await context.read<HabitService>().deleteHabit(uid, widget.habit.id);
        if (mounted) {
           context.read<AppState>().triggerSync();
           Navigator.pop(context);
        }
      }
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
                _markDirty();
             });
          }
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: Text(l10n.habitEditTitle),
            actions: [
               if (_isDirty)
                TextButton(
                  onPressed: _save,
                  child: Text(l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                _sectionHeader(l10n.habitGeneralSection),
                TextFormField(
                  initialValue: _habitName,
              decoration: InputDecoration(
                labelText: l10n.habitNameLabel,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (v) { _habitName = v; _markDirty(); },
              inputFormatters: [
                LengthLimitingTextInputFormatter(32),
                FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Category Selector
            Text(l10n.habitCategoryLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            _buildCategorySelector(theme),
            
            const SizedBox(height: 32),

             // -- TRACKING SECTION --
            _sectionHeader(l10n.habitTrackingTitle),
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
            _sectionHeader(l10n.habitAdvancedSection),
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
    final l10n = AppLocalizations.of(context)!;
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
                 Text(l10n.habitCategoryCreateAction, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
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
          decoration: InputDecoration(labelText: AppLocalizations.of(context)!.habitCategoryNameLabel, hintText: AppLocalizations.of(context)!.habitCategoryNameHint),
          onChanged: (v) => _newCatName = v,
          autofocus: true,
          inputFormatters: [
            LengthLimitingTextInputFormatter(32),
            FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
          ],
        ),
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
                       border: Border.all(color: selected ? _newCatColor : Colors.transparent, width: 2.5),
                       boxShadow: selected
                         ? [BoxShadow(color: _newCatColor.withAlpha(80), blurRadius: 6, spreadRadius: 0)]
                         : null,
                     ),
                     child: Icon(icon, color: selected ? _newCatColor : theme.colorScheme.onSurfaceVariant, size: 18),
                   ),
                 ),
               );
             }).toList(),
           ),
        ),
        const SizedBox(height: 24),
        Row(
           children: [
             TextButton(onPressed: () => setState(() => _isCreatingCategory = false), child: Text(AppLocalizations.of(context)!.cancel)),
             const Spacer(),
             FilledButton(onPressed: _saveNewCategory, child: Text(AppLocalizations.of(context)!.save)),
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
                 _buildTypeChip(AppLocalizations.of(context)!.habitYesNo, HabitType.yesNo),
                _buildTypeChip(AppLocalizations.of(context)!.habitNumeric, HabitType.numeric),
                _buildTypeChip(AppLocalizations.of(context)!.habitTime, HabitType.time),
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
                      HabitComparator.atLeast => AppLocalizations.of(context)!.habitComparatorAtLeast,
                      HabitComparator.lessThan => AppLocalizations.of(context)!.habitComparatorLessThan,
                      HabitComparator.exactly => AppLocalizations.of(context)!.habitComparatorExactly,
                      HabitComparator.any => AppLocalizations.of(context)!.habitComparatorAny,
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
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)!.habitValueLabel, filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    onChanged: (v) {
                      final trimmed = v.trim();
                      if (trimmed.isEmpty) {
                        if (_target != 0) { _target = 0; _markDirty(); }
                        return;
                      }
                      
                      double val = double.tryParse(trimmed) ?? 0;
                      if (val > 10000) {
                        val = 10000;
                        _targetCtrl.value = TextEditingValue(
                           text: "10000",
                           selection: TextSelection.collapsed(offset: 5),
                        );
                      }
                      
                      if (_target != val) { _target = val; _markDirty(); }
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
                    controller: _unitCtrl,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)!.habitUnitLabel, hintText: AppLocalizations.of(context)!.habitUnitHint, filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    onChanged: (v) { _unit = v; _markDirty(); },
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(16),
                      FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true)),
                    ],
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
                     hintText: AppLocalizations.of(context)!.habitTimePlaceholder, filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
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
               child: Text(AppLocalizations.of(context)!.habitCourseNumericWarning, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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
              Icons.notifications_off_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(AppLocalizations.of(context)!.habitReminderDisabledTitle),
            subtitle: Text(AppLocalizations.of(context)!.habitReminderDisabledSubtitle),
            trailing: const Icon(Icons.chevron_right),
            enabled: false,
            onTap: null, // _showRemindMeModal,
         ),
         
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.archive),
            title: Text(AppLocalizations.of(context)!.habitArchiveTitle),
            trailing: Switch(value: _archived, onChanged: (v) { setState(() { _archived = v; _markDirty(); }); }),
         ),
         
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restart_alt, color: Colors.red),
            title: Text(
               AppLocalizations.of(context)!.habitResetProgressTitle, 
               style: const TextStyle(color: Colors.red, fontSize: 13),
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ), 
            subtitle: Text(AppLocalizations.of(context)!.habitResetProgressSubtitle),
            trailing: OutlinedButton(
               style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
               onPressed: () async {
                   final habitService = context.read<HabitService>();
                   final uid = context.read<AuthController>().currentUser?.uid;

                   final ok = await showDialog<bool>(
                      context: context, 
                      builder: (c) => AlertDialog(
                        title: Text(AppLocalizations.of(context)!.habitResetProgressConfirmTitle), 
                        content: Text(AppLocalizations.of(context)!.habitResetProgressConfirmMessage),
                        actions: [
                           TextButton(onPressed: () => Navigator.pop(c, false), child: Text(AppLocalizations.of(context)!.cancel)), 
                           TextButton(
                             onPressed: () => Navigator.pop(c, true), 
                             style: TextButton.styleFrom(foregroundColor: Colors.red), 
                             child: Text(
                               AppLocalizations.of(context)!.reset,
                               textAlign: TextAlign.center,
                             ),
                           )
                         ]
                      )
                    );
                    
                    if (ok != true) return;

                    if (uid != null) {
                       await habitService.resetHabitProgress(uid, widget.habit.id);
                       if (mounted) {
                         context.read<AppState>().triggerSync();
                         // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Habit progress reset"))); // Removed per request
                        setState(() {});
                       }
                   }
               },
               child: Text(AppLocalizations.of(context)!.reset),
            ),
         ),
      ],
     );
  }


}

// Extension for string capitalize
extension StringCamelCase on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
