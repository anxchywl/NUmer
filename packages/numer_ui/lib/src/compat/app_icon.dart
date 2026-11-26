import 'package:flutter/material.dart';

import 'app_icons.dart';

const double _defaultSize = 24;

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AppIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon.asIconData,
      size: size ?? _defaultSize,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
