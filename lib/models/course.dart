import 'package:flutter/material.dart';

class Course {
  final String id;
  final String name;
  final String day;
  final String start;
  final String end;
  final int colorValue;

  final double? credits;
  final int? expLevel;
  final int? sortOrder;

  const Course({
    required this.id,
    required this.name,
    required this.day,
    required this.start,
    required this.end,
    required this.colorValue,
    this.credits,
    this.expLevel,
    this.sortOrder,
  });

  Color get color => Color(colorValue);

  bool get hasCredits => credits != null && credits! > 0 && expLevel != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'day': day,
        'start': start,
        'end': end,
        'colorValue': colorValue,
        'credits': credits,
        'expLevel': expLevel,
        'sortOrder': sortOrder,
      };

  static Course fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: j['name'] as String,
        day: j['day'] as String,
        start: j['start'] as String,
        end: j['end'] as String,
        colorValue:
            (j['colorValue'] as num?)?.toInt() ?? const Color(0xFF3B82F6).toARGB32(),
        credits: (j['credits'] as num?)?.toDouble(),
        expLevel: j['expLevel'] as int?,
        sortOrder: (j['sortOrder'] as num?)?.toInt(),
      );

  Course copyWith({
    String? id,
    String? name,
    String? day,
    String? start,
    String? end,
    int? colorValue,
    double? credits,
    int? expLevel,
    int? sortOrder,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      day: day ?? this.day,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
      credits: credits ?? this.credits,
      expLevel: expLevel ?? this.expLevel,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
