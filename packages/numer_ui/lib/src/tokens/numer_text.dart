import 'package:flutter/material.dart';

extension NumerTextContext on BuildContext {
  NumerText get text => NumerText._(Theme.of(this));
}

class NumerText {
  const NumerText._(this._theme);

  final ThemeData _theme;

  TextStyle get display => _theme.textTheme.displayMedium!.copyWith(
    fontWeight: FontWeight.w400,
    color: _theme.colorScheme.onSurface,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get screenTitle => _theme.textTheme.titleLarge!.copyWith(
    fontWeight: FontWeight.w700,
    color: _theme.colorScheme.primary,
  );

  TextStyle get sectionTitle => _theme.textTheme.titleMedium!.copyWith(
    fontWeight: FontWeight.w700,
    color: _theme.colorScheme.onSurface,
  );

  TextStyle get rowTitle => _theme.textTheme.bodyLarge!.copyWith(
    fontWeight: FontWeight.w400,
    color: _theme.colorScheme.onSurface,
  );

  TextStyle get body => _theme.textTheme.bodyMedium!.copyWith(
    fontWeight: FontWeight.w400,
    color: _theme.colorScheme.onSurface,
  );

  TextStyle get meta => _theme.textTheme.bodySmall!.copyWith(
    fontWeight: FontWeight.w400,
    color: _theme.colorScheme.onSurfaceVariant,
  );

  TextStyle status([Color? color]) => _theme.textTheme.labelMedium!.copyWith(
    fontWeight: FontWeight.w500,
    color: color ?? _theme.colorScheme.onSurfaceVariant,
  );
}
