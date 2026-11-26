import 'package:flutter/material.dart';

import '../tokens/numer_text.dart';

// the app_ui names, each mapped to the style of its size and weight
final class AppTextStyles {
  const AppTextStyles._(this._theme, this._text);

  static AppTextStyles of(BuildContext context) {
    return AppTextStyles._(Theme.of(context), context.text);
  }

  final ThemeData _theme;
  final NumerText _text;

  TextStyle get displayLarge => _text.display;
  TextStyle get displayMedium => _text.display;
  TextStyle get displaySmall => _text.display;
  TextStyle get headlineLarge => _text.screenTitle;
  TextStyle get headlineMedium => _text.screenTitle;
  TextStyle get headlineSmall => _text.screenTitle;
  TextStyle get titleLarge => _text.screenTitle;
  TextStyle get titleMedium => _text.sectionTitle;
  TextStyle get titleSmall => _text.body;
  TextStyle get bodyLarge => _text.rowTitle;
  TextStyle get bodyMedium => _text.body;
  TextStyle get bodySmall => _text.meta;
  TextStyle get labelLarge => _text.body;
  TextStyle get labelMedium => _text.meta;
  TextStyle get labelSmall => _text.meta;
  TextStyle get button => _theme.textTheme.labelLarge!;
  TextStyle get buttonSmall => _theme.textTheme.labelLarge!;
  TextStyle get amount => _text.display;
  TextStyle get amountSmall => _text.sectionTitle;
  TextStyle get code => _text.screenTitle;
  TextStyle get tab => _theme.textTheme.labelLarge!;
  TextStyle get tabSelected => _theme.textTheme.labelLarge!;
  TextStyle get chip => _text.meta;
  TextStyle get badge => _text.meta;
  TextStyle get link => _text.body.copyWith(color: _theme.colorScheme.primary);
  TextStyle get hint => _text.body;
  TextStyle get error => _text.meta.copyWith(color: _theme.colorScheme.error);
  TextStyle get appBarTitle => _text.sectionTitle;
  TextStyle get sectionHeader => _text.sectionTitle;
  TextStyle get statNumber => _text.display;
  TextStyle get statLabel => _text.meta;
  TextStyle get username => _text.body;
  TextStyle get timestamp => _text.meta;
}
