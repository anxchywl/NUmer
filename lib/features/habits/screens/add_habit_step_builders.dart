part of 'add_habit_sheet.dart';

mixin _AddHabitSteps
    on _AddHabitSheetBase, _AddHabitActions, _AddHabitInputActions {
  // -- Step 1: Details --
  Widget _nameStep() {
    return AddHabitNameStep(
      leadKey: _leadKey,
      habitName: _habitName,
      nameFocus: _habitNameFocus,
      isNameFocused: _isHabitNameFocused,
      isCreatingCategory: _isCreatingCategory,
      isEditing: _isEditingHabit,
      onNameChanged: (v) => _habitName = v,
      category: _isCreatingCategory ? _categoryForm() : _categorySelector(),
      onNext: _habitName.trim().isEmpty ? null : () => _navigateToStep(1),
    );
  }

  Widget _categoryForm() {
    return CategoryCreationForm(
      key: const ValueKey('creation_form'),
      color: _newCatColor,
      icon: _newCatIcon,
      onNameChanged: (v) => _newCatName = v,
      onColorChanged: (color) => setState(() => _newCatColor = color),
      onIconChanged: (icon) => setState(() => _newCatIcon = icon),
      onBack: () => setState(() => _isCreatingCategory = false),
      onSave: _saveNewCategory,
    );
  }

  Widget _categorySelector() {
    return CategorySelector(
      key: const ValueKey('selector_view'),
      customCategories: _customCategories,
      defaultCategories: _defaultCategories,
      selectedName: _categoryName,
      onSelected: (val) => setState(() => _categoryName = val),
      onDelete: _confirmDeleteCategory,
      onCreate: () => setState(() => _isCreatingCategory = true),
    );
  }

  // -- Step 2: Tracking Type --
  Widget _goalStep() {
    return AddHabitGoalStep(
      leadKey: _leadKey,
      navKey: _navKey,
      type: _type,
      isInputFocused: _isTrackingInputFocused,
      typePicker: TrackingTypePicker(
        key: const ValueKey('tracking_visible'),
        type: _type,
        isEditing: _isEditingHabit,
        onSelected: _selectType,
      ),
      comparator: _comparator,
      onComparatorChanged: (v) => setState(() => _comparator = v),
      numericFields: _numericFields(),
      target: _target,
      onTargetChanged: (v) => setState(() => _target = v),
      courseSelector: CourseSelector(
        courses: context.watch<AppState>().courses,
        type: _type,
        connectedIds: _connectedCourseIds,
        onSelected: _toggleCourse,
      ),
      onBack: () => _navigateToStep(0),
      onNext: _isTrackingNextEnabled ? () => _navigateToStep(2) : null,
    );
  }

  Widget _numericFields() {
    return NumericTargetFields(
      targetFocus: _targetFocus,
      unitFocus: _unitFocus,
      targetController: _targetCtrl,
      unitController: _unitCtrl,
      onTargetChanged: _onTargetTextChanged,
      onUnitChanged: (v) => setState(() => _unit = v),
    );
  }

  Widget _scheduleStep() {
    return AddHabitScheduleStep(
      navKey: _navKey,
      frequency: _freq,
      isEditing: _isEditingHabit,
      isFreqGoalFocused: _isFreqGoalFocused,
      isWorkRestFocused: _isWorkRestFocused,
      onFrequencySelected: (type) => setState(() => _freq = type),
      specificDays: _specificDays(),
      perPeriod: PerPeriodContent(
        period: _period,
        focusNode: _freqGoalFocus,
        controller: _frequencyGoalCtrl,
        onChanged: _onFrequencyGoalChanged,
        onTogglePeriod: _cyclePeriod,
      ),
      workRest: _workRest(),
      onBack: () => _navigateToStep(1),
      onNext: _isFrequencyNextEnabled ? () => _navigateToStep(3) : null,
    );
  }

  Widget _specificDays() {
    return SpecificDaysContent(
      period: _period,
      weekStart: context.read<AppState>().weekStart,
      selectedDays: _weekDays,
      onPeriodSelected: _selectPeriod,
      onDayChanged: _setWeekDay,
      onDateRemoved: (encoded) => setState(() => _weekDays.remove(encoded)),
      onAddDate: _pickYearDate,
    );
  }

  Widget _workRest() {
    return WorkRestContent(
      workFocus: _workDaysFocus,
      restFocus: _restDaysFocus,
      workController: _workDaysCtrl,
      restController: _restDaysCtrl,
      onWorkChanged: _onWorkDaysChanged,
      onRestChanged: _onRestDaysChanged,
    );
  }

  Widget _extrasStep() {
    return AddHabitExtrasStep(
      navKey: _navKey,
      startDate: _startDate,
      endDate: _endDate,
      isEditing: _isEditingHabit,
      isSaving: _isSaving,
      onPickStart: _pickStartDate,
      onToggleEnd: _toggleEndDate,
      onBack: () => _navigateToStep(2),
      onSubmit: _submit,
    );
  }
}
