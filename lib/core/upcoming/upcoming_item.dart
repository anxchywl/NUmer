import 'package:flutter/foundation.dart';

enum UpcomingKind { pianoBooking, eventReminder }

@immutable
class UpcomingItem {
  const UpcomingItem({
    required this.id,
    required this.moduleId,
    required this.kind,
    required this.title,
    required this.startsAt,
    required this.route,
  });

  final String id;
  final String moduleId;
  final UpcomingKind kind;
  final String title;
  final DateTime startsAt;
  final String route;

  // null for an entry this build cannot read
  static UpcomingItem? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'moduleId': final String moduleId,
      'kind': final String kindName,
      'title': final String title,
      'startsAt': final int startsAt,
      'route': final String route,
    }) {
      final kind = UpcomingKind.values.asNameMap()[kindName];
      if (kind == null) return null;
      return UpcomingItem(
        id: id,
        moduleId: moduleId,
        kind: kind,
        title: title,
        startsAt: DateTime.fromMillisecondsSinceEpoch(startsAt, isUtc: true),
        route: route,
      );
    }
    return null;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'moduleId': moduleId,
    'kind': kind.name,
    'title': title,
    'startsAt': startsAt.millisecondsSinceEpoch,
    'route': route,
  };
}
