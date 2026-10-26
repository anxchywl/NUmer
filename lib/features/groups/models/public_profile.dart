import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.profileName,
    this.major,
    this.profileGoal,
    this.profileContact,
    this.avatarIndex,
    this.avatarColorValue,
    this.avatarImageBase64,
    this.isStudying = false,
    this.activeSession,
    this.allowNudges = true,
    this.fcmEnabled = false,
    this.updatedAt,
  });

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> data) {
    return PublicProfile(
      uid: uid,
      profileName: data['profileName'] as String? ?? '',
      major: data['major'] as String?,
      profileGoal: data['profileGoal'] as String?,
      profileContact: data['profileContact'] as String?,
      avatarIndex: (data['avatarIndex'] as num?)?.toInt(),
      avatarColorValue: (data['avatarColorValue'] as num?)?.toInt(),
      avatarImageBase64: data['avatarImageBase64'] as String?,
      isStudying: data['isStudying'] == true,
      activeSession: data['activeSession'] as Map<String, dynamic>?,
      allowNudges: data['allowNudges'] != false,
      fcmEnabled: data['fcmEnabled'] == true,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  final String uid;
  final String profileName;
  final String? major;
  final String? profileGoal;
  final String? profileContact;
  final int? avatarIndex;
  final int? avatarColorValue;
  final String? avatarImageBase64;
  final bool isStudying;
  final Map<String, dynamic>? activeSession;
  final bool allowNudges;
  final bool fcmEnabled;
  final Timestamp? updatedAt;

  // the keys that code written against the user document reads
  Map<String, dynamic> toLegacyProfileMap() => {
    'profileName': profileName.isEmpty ? null : profileName,
    'major': major,
    'profileGoal': profileGoal,
    'profileContact': profileContact,
    'profileAvatarIndex': avatarIndex,
    'avatarIndex': avatarIndex,
    'profileAvatarImageBase64': avatarImageBase64,
    'avatarColorValue': avatarColorValue,
    'profileAvatarColorValue': avatarColorValue,
    'isStudying': isStudying,
    'activeSession': activeSession,
    'allowNudges': allowNudges,
    'fcmEnabled': fcmEnabled,
  };
}
