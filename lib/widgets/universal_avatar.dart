import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:numer_app/models/profile_avatar.dart';

class UniversalAvatar extends StatelessWidget {
  final String? userId;
  final String? name; // For initials fallback
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

        // Fallback to initial data while loading or if no data
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
    // 1. Force Silhouette if requested
    if (forceSilhouette) {
      return _buildSilhouette(context);
    }

    // 2. Try Image (Memory)
    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      return _wrapImage(Image.memory(avatarBytes, fit: BoxFit.cover));
    }

    // 2. Try Image (Base64)
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        return _wrapImage(Image.memory(base64Decode(avatarBase64), fit: BoxFit.cover));
      } catch (_) {}
    }

    // 3. Try Icon
    final option = profileAvatarOptionFor(avatarIndex);
    if (option != null) {
      final Color bgColor = avatarColorValue != null ? Color(avatarColorValue) : option.background;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          option.icon,
          size: size * 0.6,
          color: avatarColorValue != null 
            ? (ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark ? Colors.white : Colors.black87)
            : profileAvatarForeground(option),
        ),
      );
    }

    // 4. Fallback to Silhouette
    return _buildSilhouette(context);
  }

  Widget _buildSilhouette(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
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
    return data['profileAvatarImageBase64'] as String? ?? data['avatarImageBase64'] as String?;
  }

  Uint8List? _readAvatarBytes(Map<String, dynamic> data) {
    final v = data['profileAvatarImage'] ?? data['avatarImage'];
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return null;
  }
}
