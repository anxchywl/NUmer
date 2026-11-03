import 'package:flutter/widgets.dart';

abstract final class NumerMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 250);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static Duration of(BuildContext context, Duration token) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : token;
  }
}
