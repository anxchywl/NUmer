import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupVisibility { public, private }

extension GroupVisibilityX on GroupVisibility {
  String get label => switch (this) {
    GroupVisibility.public => 'public',
    GroupVisibility.private => 'private',
  };

  static GroupVisibility fromRaw(String? value) {
    if (value == GroupVisibility.private.label) {
      return GroupVisibility.private;
    }
    return GroupVisibility.public;
  }
}

enum GroupRole { member, admin }

extension GroupRoleX on GroupRole {
  String get label => switch (this) {
    GroupRole.member => 'member',
    GroupRole.admin => 'admin',
  };

  static GroupRole fromRaw(String? value) {
    if (value == GroupRole.admin.label) {
      return GroupRole.admin;
    }
    return GroupRole.member;
  }
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String description;
  final GroupVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int memberCount;

  bool get isPublic => visibility == GroupVisibility.public;

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? createdAt;
    return Group(
      id: doc.id,
      name: (data['name'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      visibility: GroupVisibilityX.fromRaw(data['visibility'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupMembership {
  const GroupMembership({
    required this.groupId,
    required this.role,
    required this.joinedAt,
  });

  final String groupId;
  final GroupRole role;
  final DateTime joinedAt;

  bool get isAdmin => role == GroupRole.admin;

  factory GroupMembership.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GroupMembership(
      groupId: doc.id,
      role: GroupRoleX.fromRaw(data['role'] as String?),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final GroupRole role;
  final DateTime joinedAt;

  factory GroupMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GroupMember(
      userId: doc.id,
      role: GroupRoleX.fromRaw(data['role'] as String?),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
