import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit_category.dart';
import '../../screens/swipe_selector.dart';

class CategorySelector extends StatelessWidget {
  final List<HabitCategory> customCategories;
  final List<Map<String, dynamic>> defaultCategories;
  final String selectedName;
  final ValueChanged<String> onSelected;
  final ValueChanged<HabitCategory> onDelete;
  final VoidCallback onCreate;

  const CategorySelector({
    super.key,
    required this.customCategories,
    required this.defaultCategories,
    required this.selectedName,
    required this.onSelected,
    required this.onDelete,
    required this.onCreate,
  });

  // Combined list for logic
  List<dynamic> get _allCategories {
    // Custom first
    return [...customCategories, ...defaultCategories];
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SwipeSelector<String>(
          items: _allCategories
              .map((c) => c is HabitCategory ? c.name : c['name'] as String)
              .toList(),
          selectedValue: selectedName,
          onChanged: onSelected,
          builder: (context, item) => _item(theme, l10n, item),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.habitCategoryCreateAction),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(ThemeData theme, AppLocalizations l10n, String item) {
    dynamic cat;
    try {
      cat = customCategories.firstWhere((c) => c.name == item);
    } catch (_) {
      cat = defaultCategories.firstWhere(
        (c) => c['name'] == item,
        orElse: () => defaultCategories.first,
      );
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
            Text(
              _localizedCategoryName(item, l10n),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 20),
          ],
        ),
        if (isCustom)
          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.grey,
              ),
              onPressed: () => onDelete(cat as HabitCategory),
              tooltip: l10n.habitCategoryDeleteTitle,
            ),
          ),
      ],
    );
  }
}
