import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/data/auth_write_gates.dart';

void main() {
  final savedAt = DateTime(2026, 1, 1).millisecondsSinceEpoch;
  final weekLater = savedAt + const Duration(days: 7).inMilliseconds;

  group('shouldSaveFcmToken', () {
    test('skips the same token within 7 days', () {
      expect(shouldSaveFcmToken('a', 'a', savedAt, weekLater - 1), isFalse);
    });

    test('saves the same token at 7 days', () {
      expect(shouldSaveFcmToken('a', 'a', savedAt, weekLater), isTrue);
    });

    test('saves when the saved time is in the future', () {
      expect(shouldSaveFcmToken('a', 'a', savedAt, savedAt - 1), isTrue);
    });

    test('saves a new token', () {
      expect(shouldSaveFcmToken('b', 'a', savedAt, savedAt), isTrue);
    });

    test('saves when no token was saved', () {
      expect(shouldSaveFcmToken('a', null, null, savedAt), isTrue);
    });
  });

  group('shouldUpsertEmailIndex', () {
    test('skips the same email', () {
      expect(shouldUpsertEmailIndex('a@x.test', 'a@x.test'), isFalse);
    });

    test('writes a different or missing email', () {
      expect(shouldUpsertEmailIndex('b@x.test', 'a@x.test'), isTrue);
      expect(shouldUpsertEmailIndex('a@x.test', null), isTrue);
    });
  });
}
