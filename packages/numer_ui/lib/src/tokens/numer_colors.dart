import 'package:flutter/material.dart';

class NumerColors extends ThemeExtension<NumerColors> {
  const NumerColors({required this.success, required this.warning});

  static const NumerColors light = NumerColors(
    success: Color(0xFF0F6B2E),
    warning: Color(0xFF8A4B00),
  );

  static const NumerColors dark = NumerColors(
    success: Color(0xFF81C995),
    warning: Color(0xFFFDD663),
  );

  final Color success;
  final Color warning;

  @override
  NumerColors copyWith({Color? success, Color? warning}) {
    return NumerColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  NumerColors lerp(NumerColors? other, double t) {
    if (other == null) return this;
    return NumerColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
