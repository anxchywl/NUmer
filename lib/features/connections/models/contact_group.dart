import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents a contact group for organizing people
class ContactGroup {
  final String id;
  final String name;
  final int? colorValue;
  final int? iconCodePoint;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  ContactGroup({
    required this.id,
    required this.name,
    this.colorValue,
    this.iconCodePoint,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// Get the color for this group, with fallback
  Color get color => colorValue != null ? Color(colorValue!) : Colors.blue;

  /// Get the icon for this group, with fallback
  IconData get icon => iconCodePoint != null
      ? IconData(iconCodePoint!, fontFamily: 'MaterialIcons')
      : Icons.group;

  factory ContactGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ContactGroup.fromMap(doc.id, data);
  }

  factory ContactGroup.fromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return ContactGroup.fromMap(data['id'] ?? '', data);
  }

  String toJson() {
    final map = toFirestore();
    map['id'] = id;
    return jsonEncode(map);
  }

  factory ContactGroup.fromMap(String id, Map<String, dynamic> data) {
    // Helper to get from compact key OR legacy key
    T? get<T>(String compactKey, String legacyKey) {
      if (data.containsKey(compactKey)) return data[compactKey] as T?;
      if (data.containsKey(legacyKey)) return data[legacyKey] as T?;
      return null;
    }

    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
      return DateTime.now();
    }

    return ContactGroup(
      id: id,
      name: get<String>('n', 'name') ?? 'Unknown',
      colorValue: (get<num>('cl', 'colorValue'))?.toInt(),
      iconCodePoint: (get<num>('ic', 'iconCodePoint'))?.toInt(),
      isDefault: get<bool>('df', 'isDefault') ?? false,
      createdAt: parseDate(get('ca', 'createdAt')),
      updatedAt: parseDate(get('ua', 'updatedAt')),
      deleted: get<bool>('d', 'deleted') ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'n': name,
      'ca': Timestamp.fromDate(createdAt),
      'ua': Timestamp.fromDate(updatedAt),
    };

    if (colorValue != null) map['cl'] = colorValue;
    if (iconCodePoint != null) map['ic'] = iconCodePoint;
    if (isDefault) map['df'] = true;
    map['d'] = deleted;

    return map;
  }

  ContactGroup copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? iconCodePoint,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return ContactGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactGroup &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Default groups that are created for new users
  static List<ContactGroup> get defaultGroups {
    final now = DateTime.now();
    return [
      ContactGroup(
        id: 'default_coworkers',
        name: 'Coworkers',
        colorValue: 0xFF4285F4, // Google Blue
        iconCodePoint: Icons.work.codePoint,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      ContactGroup(
        id: 'default_college_friends',
        name: 'College friends',
        colorValue: 0xFF34A853, // Google Green
        iconCodePoint: Icons.school.codePoint,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
