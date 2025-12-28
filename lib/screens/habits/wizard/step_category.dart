import 'package:flutter/material.dart';

class HabitCategoryStep extends StatelessWidget {
  final ValueChanged<String> onCategorySelected;
  final String? selectedCategory;

  const HabitCategoryStep({
    super.key, 
    required this.onCategorySelected,
    this.selectedCategory,
  });

  final List<Map<String, dynamic>> categories = const [
    {'name': 'Quit a bad habit', 'icon': Icons.block, 'color': Colors.red},
    {'name': 'Art', 'icon': Icons.palette, 'color': Colors.purple},
    {'name': 'Meditation', 'icon': Icons.self_improvement, 'color': Colors.indigo},
    {'name': 'Study', 'icon': Icons.school, 'color': Colors.blue},
    {'name': 'Sports', 'icon': Icons.directions_run, 'color': Colors.orange},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.pink},
    {'name': 'Social', 'icon': Icons.people, 'color': Colors.teal},
    {'name': 'Finance', 'icon': Icons.attach_money, 'color': Colors.green},
    {'name': 'Health', 'icon': Icons.favorite, 'color': Colors.redAccent},
    {'name': 'Work', 'icon': Icons.work, 'color': Colors.brown},
    {'name': 'Nutrition', 'icon': Icons.restaurant, 'color': Colors.deepOrange},
    {'name': 'Outdoor', 'icon': Icons.forest, 'color': Colors.greenAccent},
    {'name': 'Home', 'icon': Icons.home, 'color': Colors.blueGrey},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return _buildCustomCategoryTile(context);
              }
              final cat = categories[index];
              return _CategoryTile(
                name: cat['name'],
                icon: cat['icon'],
                color: cat['color'],
                isSelected: selectedCategory == cat['name'],
                onTap: () => onCategorySelected(cat['name']),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomCategoryTile(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedCategory == 'Custom';
    return InkWell(
      onTap: () => onCategorySelected('Custom'), // Real implementation would show dialog
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
        ),
        child: Row(
          children: [
             Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Create custom",
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
