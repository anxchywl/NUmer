import 'package:flutter/material.dart';

class CategoryColorRow extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onSelected;

  const CategoryColorRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: Colors.primaries.map(_swatch).toList(),
      ),
    );
  }

  Widget _swatch(MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => onSelected(color),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected == color ? Colors.black87 : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected == color
                ? [
                    BoxShadow(
                      color: color.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected == color
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }
}
