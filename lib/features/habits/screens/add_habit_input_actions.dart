part of 'add_habit_sheet.dart';

mixin _AddHabitInputActions on _AddHabitSheetBase {
  void _selectType(HabitType type) {
    setState(() {
      _type = type;
      if (type == HabitType.yesNo) {
        if (_target == 0.0) {
          _target = 1.0;
        }
      } else if (_target == 1.0) {
        _target = 0.0;
      }
    });
  }

  void _onTargetTextChanged(String v) {
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
  }

  void _selectPeriod(HabitPeriod p) {
    if (_period != p) {
      setState(() {
        _period = p;
        // Clear weekDays when switching periods to avoid incompatible data
        // Week uses 1-7, Month uses 1-31, Year uses MMDD encoding
        _weekDays.clear();
      });
    }
  }

  int get _maxFrequencyGoal => switch (_period) {
    HabitPeriod.week => 7,
    HabitPeriod.month => 31,
    HabitPeriod.year => 365,
  };

  void _cyclePeriod() {
    setState(() {
      final nextIndex = (_period.index + 1) % HabitPeriod.values.length;
      _period = HabitPeriod.values[nextIndex];
      // Clamp
      final maxVal = _maxFrequencyGoal;
      if (_frequencyGoal > maxVal) {
        _frequencyGoal = maxVal;
      }
    });
  }

  int _clampedInput(TextEditingController ctrl, String trimmed, int maxVal) {
    int val = int.tryParse(trimmed) ?? 1;
    if (val < 1) {
      val = 1;
      ctrl.text = "$val";
      ctrl.selection = TextSelection.fromPosition(TextPosition(offset: 1));
    }
    if (val > maxVal) {
      val = maxVal;
      ctrl.text = "$val";
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
    }
    return val;
  }

  void _onFrequencyGoalChanged(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() => _frequencyGoal = 1);
      return;
    }
    final val = _clampedInput(_frequencyGoalCtrl, trimmed, _maxFrequencyGoal);
    setState(() => _frequencyGoal = val);
  }

  void _onWorkDaysChanged(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() => _interval = 1);
      return;
    }
    final val = _clampedInput(_workDaysCtrl, trimmed, 365);
    setState(() => _interval = val);
  }

  void _onRestDaysChanged(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() => _frequencyGoal = 1);
      return;
    }
    final val = _clampedInput(_restDaysCtrl, trimmed, 365);
    setState(() => _frequencyGoal = val);
  }

  void _setWeekDay(int day, bool selected) {
    setState(() {
      if (selected) {
        _weekDays.add(day);
      } else {
        _weekDays.remove(day);
      }
    });
  }

  Future<void> _pickYearDate() async {
    // Custom picker or standard? Standard supports one date.
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, 1, 1),
      lastDate: DateTime(now.year, 12, 31),
    );
    if (picked != null) {
      final encoded = picked.month * 100 + picked.day;
      setState(() => _weekDays.add(encoded));
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year + 5, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isAfter(maxDate) ? maxDate : _startDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _toggleEndDate() async {
    if (_endDate != null) {
      setState(() => _endDate = null);
      return;
    }
    final now = DateTime.now();
    final maxDate = DateTime(now.year + 5, 12, 31);
    final initialEnd = _startDate.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialEnd.isAfter(maxDate) ? maxDate : initialEnd,
      firstDate: _startDate.isAfter(DateTime(2025, 1, 1))
          ? _startDate
          : DateTime(2025, 1, 1),
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _toggleCourse(String courseId, bool selected) {
    setState(() {
      if (selected) {
        _connectedCourseIds.add(courseId);
      } else {
        _connectedCourseIds.remove(courseId);
      }
    });
  }
}
