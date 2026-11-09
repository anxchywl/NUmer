import 'package:flutter/material.dart';

InputDecoration habitInputDecoration(
  ThemeData theme, {
  required double radius,
  String? labelText,
  String? hintText,
  bool? isDense,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: isDense,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    ),
  );
}
