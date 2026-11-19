import 'package:flutter/material.dart';

const _categoryIcons = [
  Icons.local_fire_department,
  Icons.check_circle,
  Icons.calendar_today,
  Icons.access_time,
  Icons.track_changes,
  Icons.star,
  Icons.bolt,
  Icons.favorite_border,
  Icons.psychology,
  Icons.fitness_center,
  Icons.menu_book,
  Icons.eco,
  Icons.water_drop,
  Icons.nightlight_round,
  Icons.wb_sunny,
  Icons.directions_walk,
  Icons.emoji_events,
  Icons.notifications,
  Icons.edit,
  Icons.trending_up,
  Icons.shield,
  Icons.battery_charging_full,
  Icons.sentiment_satisfied,
  Icons.rocket_launch,
  Icons.coffee,
  Icons.apple,
  Icons.lunch_dining,
  Icons.bakery_dining,
  Icons.wine_bar,
  Icons.medication,
  Icons.medical_services,
  Icons.health_and_safety,
  Icons.self_improvement,
  Icons.directions_bike,
  Icons.pool,
  Icons.accessibility_new,
  Icons.spa,
  Icons.music_note,
  Icons.headphones,
  Icons.palette,
  Icons.camera_alt,
  Icons.code,
  Icons.laptop,
  Icons.account_balance_wallet,
  Icons.savings,
  Icons.shopping_cart,
  Icons.bed,
];

class CategoryIconRow extends StatelessWidget {
  final IconData selected;
  final Color color;
  final ValueChanged<IconData> onSelected;

  const CategoryIconRow({
    super.key,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categoryIcons.map((icon) => _option(theme, icon)).toList(),
      ),
    );
  }

  Widget _option(ThemeData theme, IconData icon) {
    final isSelected = selected == icon;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => onSelected(icon),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withAlpha((0.15 * 255).round())
                : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withAlpha(80),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ),
      ),
    );
  }
}
