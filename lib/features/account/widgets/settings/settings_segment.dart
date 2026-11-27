import 'package:flutter/material.dart';

ButtonSegment<T> settingsSegment<T>(
  T value,
  String label, {
  IconData? icon,
  bool singleLine = false,
}) {
  return ButtonSegment(
    value: value,
    icon: icon == null ? null : Icon(icon),
    label: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: singleLine ? 1 : null,
        softWrap: singleLine ? false : null,
        style: const TextStyle(fontSize: 12),
      ),
    ),
  );
}

class SettingsSegments<T> extends StatelessWidget {
  const SettingsSegments({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
        segments: segments,
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }
}
