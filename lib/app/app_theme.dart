import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

final ThemeData lightFallbackTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
);

final ThemeData darkFallbackTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  ),
);

ThemeData buildAppTheme(Color accent, Brightness brightness) {
  return NumerTheme.build(seed: accent, brightness: brightness);
}
