import 'package:flutter/material.dart';

import '../tokens/numer_colors.dart';
import '../tokens/numer_radius.dart';

const Size _buttonMinimumSize = Size(64, 48);
const double _focusBorderWidth = 2;

abstract final class NumerTheme {
  static ThemeData build({
    required Color seed,
    required Brightness brightness,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NumerRadius.md),
    );

    return base.copyWith(
      extensions: [
        brightness == Brightness.dark ? NumerColors.dark : NumerColors.light,
      ],
      switchTheme: _switchTheme(seed),
      appBarTheme: _appBarTheme(base),
      inputDecorationTheme: _inputTheme(scheme),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: shape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: shape),
      ),
      bottomSheetTheme: _bottomSheetTheme(scheme),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
    );
  }

  static SwitchThemeData _switchTheme(Color seed) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return seed;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return seed.withValues(alpha: 0.5);
        }
        return null;
      }),
    );
  }

  static AppBarTheme _appBarTheme(ThemeData base) {
    final scheme = base.colorScheme;
    return AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge!.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    );
  }

  static InputDecorationThemeData _inputTheme(ColorScheme scheme) {
    OutlineInputBorder border([Color? color]) {
      return _FilledInputBorder(
        borderRadius: BorderRadius.circular(NumerRadius.md),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: _focusBorderWidth),
      );
    }

    return InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(scheme.primary),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) {
    return BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NumerRadius.xl),
        ),
      ),
    );
  }
}

// material centres a floating label on an outline's top edge, half outside the fill
class _FilledInputBorder extends OutlineInputBorder {
  const _FilledInputBorder({super.borderSide, super.borderRadius});

  static ShapeBorder? _keep(ShapeBorder? border) {
    if (border is! OutlineInputBorder) return border;
    return _FilledInputBorder(
      borderSide: border.borderSide,
      borderRadius: border.borderRadius,
    );
  }

  @override
  bool get isOutline => false;

  @override
  OutlineInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) {
    return _FilledInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  OutlineInputBorder scale(double t) => _FilledInputBorder(
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      _keep(super.lerpFrom(a, t));

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => _keep(super.lerpTo(b, t));

  // the label sits inside, so the stroke must not open a gap for it
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    super.paint(canvas, rect, textDirection: textDirection);
  }
}
