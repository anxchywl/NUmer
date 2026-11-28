import 'package:flutter/material.dart';

const groupColorChoices = <Color>[
  Color(0xFF4285F4),
  Color(0xFF34A853),
  Color(0xFFEA4335),
  Color(0xFFFBBC04),
  Color(0xFF9C27B0),
  Color(0xFFFF5722),
  Color(0xFF00BCD4),
  Color(0xFF795548),
  Color(0xFF607D8B),
  Color(0xFFE91E63),
];

const groupIconChoices = <IconData>[
  Icons.group,
  Icons.work,
  Icons.school,
  Icons.home,
  Icons.favorite,
  Icons.star,
  Icons.sports,
  Icons.music_note,
  Icons.restaurant,
  Icons.flight,
  Icons.local_cafe,
  Icons.fitness_center,
  Icons.code,
  Icons.brush,
  Icons.camera,
];

class GroupColorPicker extends StatelessWidget {
  const GroupColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: groupColorChoices.length,
        itemBuilder: (context, index) {
          final color = groupColorChoices[index];
          final isSelected = selected.toARGB32() == color.toARGB32();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(color),
              child: CircleAvatar(
                backgroundColor: color,
                radius: 16,
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class GroupIconPicker extends StatelessWidget {
  const GroupIconPicker({
    super.key,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final IconData selected;
  final Color color;
  final ValueChanged<IconData> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: groupIconChoices.length,
        itemBuilder: (context, index) {
          final icon = groupIconChoices[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(icon),
              child: _option(context, icon, selected == icon),
            ),
          );
        },
      ),
    );
  }

  Widget _option(BuildContext context, IconData icon, bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(51) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? color : scheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Icon(
        icon,
        color: isSelected ? color : scheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
