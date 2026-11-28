import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import 'habit_input_decoration.dart';
import 'next_button_style.dart';
import 'slide_size_transition.dart';

class AddHabitNameStep extends StatelessWidget {
  final Key leadKey;
  final String habitName;
  final NumerSheetFocusMode focus;
  final bool isCreatingCategory;
  final bool isEditing;
  final ValueChanged<String> onNameChanged;
  final Widget category;
  final VoidCallback? onNext;

  const AddHabitNameStep({
    super.key,
    required this.leadKey,
    required this.habitName,
    required this.focus,
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
              : NumerFocusFold(
                  hidden: focus.hides('name'),
                  animateSize: false,
                  child: _nameSection(theme, l10n),
                ),
        ),

        NumerFocusFold(
          hidden: focus.hides('category'),
          animateSize: false,
          child: _categorySection(theme, l10n),
        ),

        const SizedBox(height: 16),
        SheetDoneActions(
          focus: focus,
          actions: FilledButton(
            style: nextButtonStyle(theme),
            onPressed: onNext,
            child: Text(l10n.habitNext),
          ),
        ),
      ],
    );
  }

  Widget _nameSection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _folded(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.habitExplainHabit,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        TextFormField(
          focusNode: focus.nodeFor('name'),
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
        _folded(const SizedBox(height: 32)),
      ],
    );
  }

  Widget _folded(Widget child) => NumerFocusFold(
    hidden: focus.hidesChrome,
    animateSize: false,
    child: child,
  );

  Widget _categorySection(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _folded(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              isCreatingCategory
                  ? l10n.habitCategoryNew
                  : l10n.habitCategoryLabel,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
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
