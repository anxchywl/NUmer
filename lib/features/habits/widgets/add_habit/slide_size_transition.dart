import 'package:flutter/material.dart';

Widget slideSizeTransition(Widget child, Animation<double> animation) {
  final offsetAnimation = animation.drive(
    Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)),
  );

  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: offsetAnimation,
      child: SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: child,
      ),
    ),
  );
}
