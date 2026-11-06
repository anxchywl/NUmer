import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';

class _FakeUser implements User {
  _FakeUser({this.email = 'a@x.test'});

  @override
  final String? email;

  AuthCredential? credential;

  @override
  String get uid => 'deleting-user';

  @override
  bool get emailVerified => false;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    this.credential = credential;
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  final users = StreamController<User?>();
  int signOuts = 0;

  @override
  Stream<User?> authStateChanges() => users.stream;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctions implements FirebaseFunctions {
  final called = <String>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    called.add(name);
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('deleteAccountFailureFor', () {
    test('maps every wrong password code', () {
      for (final code in [
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
      ]) {
        expect(
          deleteAccountFailureFor(code),
          DeleteAccountFailure.wrongPassword,
        );
      }
    });

    test('maps a network failure and anything else', () {
      expect(
        deleteAccountFailureFor('network-request-failed'),
        DeleteAccountFailure.network,
      );
      expect(
        deleteAccountFailureFor('too-many-requests'),
        DeleteAccountFailure.failed,
      );
    });
  });

  group('deleteAccount', () {
    late _FakeAuth auth;
    late _FakeFunctions functions;
    late AuthController controller;

    Future<void> signIn(User user) async {
      auth.users.add(user);
      await pumpEventQueue();
    }

    setUp(() {
      auth = _FakeAuth();
      functions = _FakeFunctions();
      controller = AuthController(
        auth: auth,
        firestore: _FakeFirestore(),
        functions: functions,
      );
    });

    test('a wrong password stops before any preparation or callable', () async {
      final user = _FakeUser();
      await signIn(user);
      var prepared = false;

      final failure = await controller.deleteAccount(
        password: 'wrong',
        beforeDelete: () async => prepared = true,
      );

      expect(failure, DeleteAccountFailure.wrongPassword);
      expect(user.credential, isA<EmailAuthCredential>());
      expect(prepared, isFalse);
      expect(functions.called, isEmpty);
      expect(auth.signOuts, 0);
      expect(controller.currentUser, same(user));
      expect(controller.isBusy, isFalse);
    });

    test('an account without an email cannot re-authenticate', () async {
      await signIn(_FakeUser(email: null));

      final failure = await controller.deleteAccount(password: 'secret');

      expect(failure, DeleteAccountFailure.failed);
      expect(functions.called, isEmpty);
    });
  });
}
