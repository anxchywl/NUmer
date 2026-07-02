import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HabitCategory {
  final String id;
  final String name;
  final Color color;
  final int iconCodePoint;
  final bool isCustom;

  const HabitCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.iconCodePoint,
    this.isCustom = true,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'iconCodePoint': iconCodePoint,
      'isCustom': isCustom,
    };
  }

  factory HabitCategory.fromJson(Map<String, dynamic> json) {
    return HabitCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      color: Color(json['color'] as int? ?? 0xFF000000),
      iconCodePoint: json['iconCodePoint'] as int? ?? Icons.error.codePoint,
      isCustom: json['isCustom'] ?? true,
    );
  }

  factory HabitCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HabitCategory(
      id: doc.id,
      name: data['name'] ?? '',
      color: Color(data['color'] as int? ?? 0xFF000000),
      iconCodePoint: data['iconCodePoint'] as int? ?? Icons.error.codePoint,
      isCustom: data['isCustom'] ?? true,
    );
  }
}
