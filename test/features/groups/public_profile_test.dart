import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/groups.dart';

void main() {
  final start = Timestamp.fromMillisecondsSinceEpoch(1000);
  final end = Timestamp.fromMillisecondsSinceEpoch(2000);
  final session = <String, dynamic>{
    'courseId': 'c1',
    'kind': 'pomodoro',
    'startUtc': start,
    'expectedEndUtc': end,
  };
  final data = <String, dynamic>{
    'profileName': 'Aru',
    'major': 'Maths',
    'profileGoal': 'Pass',
    'profileContact': '@aru',
    'avatarIndex': 3,
    'avatarColorValue': 0xFF000000,
    'avatarImageBase64': 'aGk=',
    'isStudying': true,
    'activeSession': session,
    'allowNudges': false,
    'fcmEnabled': true,
    'updatedAt': end,
  };

  test('fromMap reads every field and keeps the session as received', () {
    final profile = PublicProfile.fromMap('u1', data);

    expect(profile.uid, 'u1');
    expect(profile.profileName, 'Aru');
    expect(profile.major, 'Maths');
    expect(profile.profileGoal, 'Pass');
    expect(profile.profileContact, '@aru');
    expect(profile.avatarIndex, 3);
    expect(profile.avatarColorValue, 0xFF000000);
    expect(profile.avatarImageBase64, 'aGk=');
    expect(profile.isStudying, isTrue);
    expect(profile.activeSession, same(session));
    expect(profile.allowNudges, isFalse);
    expect(profile.fcmEnabled, isTrue);
    expect(profile.updatedAt, end);
  });

  test('toLegacyProfileMap has the keys existing readers expect', () {
    final map = PublicProfile.fromMap('u1', data).toLegacyProfileMap();

    expect(map, {
      'profileName': 'Aru',
      'major': 'Maths',
      'profileGoal': 'Pass',
      'profileContact': '@aru',
      'profileAvatarIndex': 3,
      'avatarIndex': 3,
      'profileAvatarImageBase64': 'aGk=',
      'avatarColorValue': 0xFF000000,
      'profileAvatarColorValue': 0xFF000000,
      'isStudying': true,
      'activeSession': session,
      'allowNudges': false,
      'fcmEnabled': true,
    });
    expect((map['activeSession'] as Map)['startUtc'], same(start));
  });

  test('an empty name counts as missing', () {
    final map = PublicProfile.fromMap('u1', {
      'profileName': '',
    }).toLegacyProfileMap();

    expect(map['profileName'], isNull);
  });

  group('withProfile', () {
    final member = MemberStudyData(
      userId: 'u1',
      name: 'Old',
      avatarBase64: 'aGk=',
      avatarColorValue: 1,
      studyTimeSeconds: 60,
      todayStudyTimeSeconds: 60,
      monthStudyTimeSeconds: 60,
      isLeader: false,
      isCurrentUser: false,
      dailyBreakdown: const [],
    );

    test('drops an image the profile no longer has', () {
      final updated = member.withProfile(
        PublicProfile.fromMap('u1', {'avatarIndex': 2}).toLegacyProfileMap(),
      );

      expect(updated.avatarBase64, isEmpty);
      expect(updated.avatarIndex, 2);
      expect(updated.name, 'Old');
      expect(updated.studyTimeSeconds, 60);
    });

    test('applies presence', () {
      final updated = member.withProfile(
        PublicProfile.fromMap('u1', data).toLegacyProfileMap(),
      );

      expect(updated.isStudying, isTrue);
      expect(updated.sessionRunUntil, end.toDate());
      expect(updated.allowsNudges, isFalse);
      expect(updated.canReceiveNudges, isTrue);
    });
  });
}
