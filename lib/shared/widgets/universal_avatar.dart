import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:numer_app/features/account/models/profile_avatar.dart';

// avatar that resolves, in order, a live firestore image, a base64 image, an icon
// option, or a silhouette; falls back to passed-in initial values while loading
class UniversalAvatar extends StatelessWidget {
  final String? userId;
  final String? name;
  final int? initialAvatarIndex;
  final int? initialAvatarColorValue;
  final String? initialAvatarBase64;
  final bool alwaysShowSilhouette;
  final double size;
  final double? fontSize;

  const UniversalAvatar({
    super.key,
    this.userId,
    this.name,
    this.initialAvatarIndex,
    this.initialAvatarColorValue,
    this.initialAvatarBase64,
    this.alwaysShowSilhouette = false,
    required this.size,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (alwaysShowSilhouette) {
      return _buildContent(
        context,
        avatarColorValue: initialAvatarColorValue,
        forceSilhouette: true,
      );
    }
    if (userId == null || userId!.isEmpty) {
      return _buildContent(
        context,
        avatarIndex: initialAvatarIndex,
        avatarColorValue: initialAvatarColorValue,
        avatarBase64: initialAvatarBase64,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          return _buildContent(
            context,
            avatarIndex: _readAvatarIndex(data),
            avatarColorValue: _readAvatarColorValue(data),
            avatarBase64: _readAvatarBase64(data),
            avatarBytes: _readAvatarBytes(data),
          );
        }

        // fall back to initial data while loading or when the doc is missing
        return _buildContent(
          context,
          avatarIndex: initialAvatarIndex,
          avatarColorValue: initialAvatarColorValue,
          avatarBase64: initialAvatarBase64,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    int? avatarIndex,
    int? avatarColorValue,
    String? avatarBase64,
    Uint8List? avatarBytes,
    bool forceSilhouette = false,
  }) {
    // resolve the richest available source, silhouette being the last resort
    if (forceSilhouette) {
      return _buildSilhouette(context);
    }

    // decoded image bytes
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      return _wrapImage(Image.memory(avatarBytes, fit: BoxFit.cover));
    }

    // base64-encoded image
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        return _wrapImage(
          Image.memory(base64Decode(avatarBase64), fit: BoxFit.cover),
        );
      } catch (_) {}
    }

    // preset icon option
    final option = profileAvatarOptionFor(avatarIndex);
    if (option != null) {
      final Color bgColor = avatarColorValue != null
          ? Color(avatarColorValue)
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

  int? _readAvatarIndex(Map<String, dynamic> data) {
    final candidates = [data['profileAvatarIndex'], data['avatarIndex']];
    for (final v in candidates) {
      if (v is num) return v.toInt();
    }
    return null;
  }

  int? _readAvatarColorValue(Map<String, dynamic> data) {
    final v = data['avatarColorValue'] ?? data['profileAvatarColorValue'];
    if (v is num) return v.toInt();
    return null;
  }

  String? _readAvatarBase64(Map<String, dynamic> data) {
    return data['profileAvatarImageBase64'] as String? ??
        data['avatarImageBase64'] as String?;
  }

  Uint8List? _readAvatarBytes(Map<String, dynamic> data) {
    final v = data['profileAvatarImage'] ?? data['avatarImage'];
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return null;
  }
}
