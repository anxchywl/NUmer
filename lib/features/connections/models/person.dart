import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single interaction/contact log entry
class InteractionEntry {
  final String id;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  InteractionEntry({
    required this.id,
    required this.date,
    required this.note,
    required this.createdAt,
  });

  factory InteractionEntry.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
      return DateTime.now();
    }

    return InteractionEntry(
      id: data['i'] ?? data['id'] ?? '',
      date: parseDate(data['d'] ?? data['date']),
      note: data['n'] ?? data['note'] ?? '',
      createdAt: parseDate(data['c'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'i': id,
      'd': date.millisecondsSinceEpoch,
      'n': note,
      'c': createdAt.millisecondsSinceEpoch,
    };
  }

  InteractionEntry copyWith({
    String? id,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return InteractionEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a person/contact in the Connections feature
class Person {
  final String id;
  final String name;
  final List<String> groupIds;
  final List<String> tags;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime? lastContactedAt;
  final DateTime? birthday;
  final bool remindToReachOut;
  final List<InteractionEntry> interactionLog;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  Person({
    required this.id,
    required this.name,
    this.groupIds = const [],
    this.tags = const [],
    this.phone,
    this.email,
    this.notes,
    this.lastContactedAt,
    this.birthday,
    this.remindToReachOut = false,
    this.interactionLog = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  factory Person.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Person.fromMap(doc.id, data);
  }

  factory Person.fromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return Person.fromMap(data['id'] ?? '', data);
  }

  String toJson() {
    final map = toFirestore();
    map['id'] = id;
    return jsonEncode(map);
  }

  factory Person.fromMap(String id, Map<String, dynamic> data) {
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

    DateTime? parseDateNullable(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
      return null;
    }

    // Parse interaction log
    final rawLog = get<List>('il', 'interactionLog');
    final interactionLog = <InteractionEntry>[];
    if (rawLog != null) {
      for (final item in rawLog) {
        if (item is Map<String, dynamic>) {
          interactionLog.add(InteractionEntry.fromMap(item));
        }
      }
    }

    // Parse group IDs
    final rawGroups = get<List>('g', 'groupIds');
    final groupIds = <String>[];
    if (rawGroups != null) {
      for (final g in rawGroups) {
        if (g is String) groupIds.add(g);
      }
    }

    // Parse tags
    final rawTags = get<List>('t', 'tags');
    final tags = <String>[];
    if (rawTags != null) {
      for (final t in rawTags) {
        if (t is String) tags.add(t);
      }
    }

    return Person(
      id: id,
      name: get<String>('n', 'name') ?? 'Unknown',
      groupIds: groupIds,
      tags: tags,
      phone: get<String>('ph', 'phone'),
      email: get<String>('em', 'email'),
      notes: get<String>('nt', 'notes'),
      lastContactedAt: parseDateNullable(get('lc', 'lastContactedAt')),
      birthday: parseDateNullable(get('bd', 'birthday')),
      remindToReachOut: get<bool>('rm', 'remindToReachOut') ?? false,
      interactionLog: interactionLog,
      sortOrder: (get<num>('so', 'sortOrder'))?.toInt() ?? 0,
      createdAt: parseDate(get('ca', 'createdAt')),
      updatedAt: parseDate(get('ua', 'updatedAt')),
      deleted: get<bool>('d', 'deleted') ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'n': name,
      'g': groupIds,
      'so': sortOrder,
      'ca': Timestamp.fromDate(createdAt),
      'ua': Timestamp.fromDate(updatedAt),
    };

    if (tags.isNotEmpty) map['t'] = tags;
    if (phone != null && phone!.isNotEmpty) map['ph'] = phone;
    if (email != null && email!.isNotEmpty) map['em'] = email;
    if (notes != null && notes!.isNotEmpty) map['nt'] = notes;
    if (lastContactedAt != null)
      map['lc'] = Timestamp.fromDate(lastContactedAt!);
    if (birthday != null) map['bd'] = Timestamp.fromDate(birthday!);
    if (remindToReachOut) map['rm'] = true;
    if (interactionLog.isNotEmpty) {
      map['il'] = interactionLog.map((e) => e.toMap()).toList();
    }
    map['d'] = deleted;

    return map;
  }

  Person copyWith({
    String? id,
    String? name,
    List<String>? groupIds,
    List<String>? tags,
    String? phone,
    String? email,
    String? notes,
    DateTime? lastContactedAt,
    DateTime? birthday,
    bool? remindToReachOut,
    List<InteractionEntry>? interactionLog,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      groupIds: groupIds ?? this.groupIds,
      tags: tags ?? this.tags,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      birthday: birthday ?? this.birthday,
      remindToReachOut: remindToReachOut ?? this.remindToReachOut,
      interactionLog: interactionLog ?? this.interactionLog,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Returns true if this person hasn't been contacted in 30+ days
  bool get needsFollowUp {
    if (lastContactedAt == null) return true;
    final daysSinceContact = DateTime.now().difference(lastContactedAt!).inDays;
    return daysSinceContact >= 30;
  }

  /// Returns true if this person was contacted in the last 7 days
  bool get recentlyContacted {
    if (lastContactedAt == null) return false;
    final daysSinceContact = DateTime.now().difference(lastContactedAt!).inDays;
    return daysSinceContact <= 7;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
