import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/profile_avatar.dart';

// avatar that resolves, in order, a base64 image, an icon option, or a silhouette
class UniversalAvatar extends StatelessWidget {
  final String? name;
  final int? avatarIndex;
  final int? avatarColorValue;
  final String? avatarImageBase64;
  final bool alwaysShowSilhouette;
  final double size;
  final double? fontSize;

  const UniversalAvatar({
    super.key,
    this.name,
    this.avatarIndex,
    this.avatarColorValue,
    this.avatarImageBase64,
    this.alwaysShowSilhouette = false,
    required this.size,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    // resolve the richest available source, silhouette being the last resort
    if (alwaysShowSilhouette) {
      return _buildSilhouette(context);
    }

    // base64-encoded image
    final image = avatarImageBase64;
    if (image != null && image.isNotEmpty) {
      try {
        return _wrapImage(Image.memory(base64Decode(image), fit: BoxFit.cover));
      } on FormatException {
        return _buildFallback(context);
      }
    }

    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    // preset icon option
    final option = profileAvatarOptionFor(avatarIndex);
    if (option != null) {
      final colorValue = avatarColorValue;
      final Color bgColor = colorValue != null
          ? Color(colorValue)
          : option.background;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(
          option.icon,
          size: size * 0.6,
          color: avatarColorValue != null
              ? (ThemeData.estimateBrightnessForColor(bgColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87)
              : profileAvatarForeground(option),
        ),
      );
    }

    return _buildSilhouette(context);
  }

  Widget _buildSilhouette(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.85,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _wrapImage(Widget image) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: image),
    );
  }
}
