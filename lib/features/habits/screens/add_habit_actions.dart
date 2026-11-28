part of 'add_habit_sheet.dart';

mixin _AddHabitActions on _AddHabitSheetBase {
  bool get _isTrackingNextEnabled {
    return switch (_type) {
      HabitType.yesNo => true,
      HabitType.numeric => _target >= 0,
      HabitType.time => _target >= 0,
    };
  }

  bool get _isFrequencyNextEnabled {
    return switch (_freq) {
      HabitFrequencyType.daily => true,
      HabitFrequencyType.specificDays => _weekDays.isNotEmpty,
      HabitFrequencyType.repeatsInPeriod =>
        _frequencyGoalCtrl.text.trim().isNotEmpty,
      HabitFrequencyType.interval =>
        _workDaysCtrl.text.trim().isNotEmpty &&
            _restDaysCtrl.text.trim().isNotEmpty,
    };
  }

  void _navigateToStep(int nextScreen) {
    _focus.release();
    setState(() => _screen = nextScreen);
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

  // Helper to get current category color/icon
  Map<String, dynamic> get _currentCatData {
    // Check custom
    try {
      final custom = _customCategories.firstWhere(
        (c) => c.name == _categoryName,
      );
      return {
        'name': custom.name,
        'icon': custom.icon,
        'color': custom.color,
        'isCustom': true,
        'id': custom.id,
      };
    } catch (_) {}

    // Check default
    return _defaultCategories.firstWhere(
      (c) => c['name'] == _categoryName,
      orElse: () => _defaultCategories.last,
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthController>();
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception("User not signed in");

      final old = widget.habit;
      final habit = old != null ? _editedHabit(old) : _newHabit();

      await context.read<HabitService>().createHabit(uid, habit);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showAppMessage(
          context,
          l10n.habitsListError(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Detect Retroactive Change (Target or Comparator)
  List<HabitRule> _updatedRules(Habit old) {
    List<HabitRule> rules = List.from(old.previousRules);

    // Note: We don't track Unit changes as they are cosmetic?
    // Or if unit changes, the value might be different?
    // Assuming unit changes require value update usually.
    // We only care if meaningful logic changes.

    final targetChanged = (old.targetValue - _target).abs() > 0.001;
    final comparatorChanged = old.comparator != _comparator;
    // Tracking Type change IS comparator change usually.

    if (targetChanged || comparatorChanged) {
      rules.add(
        HabitRule(
          endDate: DateTime.now(), // Rules ends NOW
          targetValue: old.targetValue,
          comparator: old.comparator,
        ),
      );
    }
    return rules;
  }

  // Update existing habit
  Habit _editedHabit(Habit old) {
    final rules = _updatedRules(old);
    final name = _habitName;
    final color = _currentCatData['color'] as Color;
    final category = _currentCatData['name'] as String;

    return old.copyWith(
      name: name,
      color: color,
      iconCodePoint: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).codePoint
          : 0xe156,
      iconFamily: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).fontFamily
          : null,
      iconPackage: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).fontPackage
          : null,
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
      previousRules: rules,
    );
  }

  // Create new habit
  Habit _newHabit() {
    final name = _habitName;
    final color = _currentCatData['color'] as Color;
    final category = _currentCatData['name'] as String;

    return Habit(
      id: '',
      name: name,
      color: color,
      iconCodePoint: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).codePoint
          : 0xe156,
      iconFamily: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).fontFamily
          : null,
      iconPackage: _currentCatData['icon'] is IconData
          ? (_currentCatData['icon'] as IconData).fontPackage
          : null,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
}
