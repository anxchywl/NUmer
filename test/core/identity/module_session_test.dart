import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/identity/id_token_provider.dart';
import 'package:numer_app/core/identity/module_session.dart';

class _Tokens {
  _Tokens(this.next);

  Future<String> Function() next;
  int refreshes = 0;

  Future<String> call({bool forceRefresh = false}) {
    if (forceRefresh) refreshes++;
    return next();
  }
}

void main() {
  late int signOuts;
  ModuleSession session(_Tokens tokens) =>
      ModuleSession(idToken: tokens.call, signOut: () async => signOuts++);

  setUp(() => signOuts = 0);

  test('a successful refresh returns the new token', () async {
    final tokens = _Tokens(() async => 'fresh');
    expect(await session(tokens).handleSessionExpired(), 'fresh');
    expect(tokens.refreshes, 1);
    expect(signOuts, 0);
  });

  test('an expired token signs out once', () async {
    final tokens = _Tokens(
      () => throw FirebaseAuthException(code: 'user-token-expired'),
    );
    expect(await session(tokens).handleSessionExpired(), isNull);
    expect(signOuts, 1);
  });

  test('a signed out user signs out once', () async {
    final tokens = _Tokens(() => throw const SignedOutException());
    expect(await session(tokens).handleSessionExpired(), isNull);
    expect(signOuts, 1);
  });

  test('concurrent calls share one refresh', () async {
    final gate = Completer<String>();
    final tokens = _Tokens(() => gate.future);
    final subject = session(tokens);
    final first = subject.handleSessionExpired();
    final second = subject.handleSessionExpired();
    gate.complete('fresh');
    expect(await Future.wait([first, second]), ['fresh', 'fresh']);
    expect(tokens.refreshes, 1);
  });

  test('a call after the first completed refreshes again', () async {
    final tokens = _Tokens(() async => 'fresh');
    final subject = session(tokens);
    await subject.handleSessionExpired();
    await subject.handleSessionExpired();
    expect(tokens.refreshes, 2);
  });
}
