import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'habit_input_decoration.dart';
import 'next_button_style.dart';
import 'slide_size_transition.dart';

class AddHabitNameStep extends StatelessWidget {
  final Key leadKey;
  final String habitName;
  final FocusNode nameFocus;
  final bool isNameFocused;
  final bool isCreatingCategory;
  final bool isEditing;
  final ValueChanged<String> onNameChanged;
  final Widget category;
  final VoidCallback? onNext;

  const AddHabitNameStep({
    super.key,
    required this.leadKey,
    required this.habitName,
    required this.nameFocus,
    required this.isNameFocused,
    required this.isCreatingCategory,
    required this.isEditing,
    required this.onNameChanged,
    required this.category,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          key: leadKey,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isCreatingCategory
              ? const SizedBox.shrink()
              : _nameSection(theme, l10n),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isNameFocused
              ? const SizedBox.shrink()
              : _categorySection(theme, l10n),
        ),

        const SizedBox(height: 16),
        FilledButton(
          style: nextButtonStyle(theme),
          onPressed: onNext,
          child: Text(l10n.habitNext),
        ),
      ],
    );
  }

  Widget _nameSection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.habitExplainHabit,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          focusNode: nameFocus,
          initialValue: habitName.isNotEmpty ? habitName : null,
          decoration: habitInputDecoration(
            theme,
            radius: 16,
            labelText: l10n.habitNameLabel,
            hintText: l10n.habitNameHint,
          ),
          onChanged: onNameChanged,
          inputFormatters: [
            LengthLimitingTextInputFormatter(32),
            FilteringTextInputFormatter.allow(
              RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _categorySection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isCreatingCategory ? l10n.habitCategoryNew : l10n.habitCategoryLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: isEditing,
          child: Opacity(
            opacity: isEditing ? 0.72 : 1.0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: slideSizeTransition,
              child: category,
            ),
          ),
        ),
      ],
    );
  }
}
