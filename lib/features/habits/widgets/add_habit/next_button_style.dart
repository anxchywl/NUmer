import 'package:flutter/material.dart';

ButtonStyle nextButtonStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
    disabledForegroundColor: theme.colorScheme.outline,
  );
}
