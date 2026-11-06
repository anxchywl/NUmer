import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fake_auth_code_api.dart';

class _FakeUser implements User {
  final List<bool> tokenRefreshes = [];
  int reloads = 0;
  FirebaseAuthException? tokenError;

  @override
  String get email => 'a.student@nu.edu.kz';

  @override
  bool get emailVerified => false;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    final error = tokenError;
    if (error != null) throw error;
    tokenRefreshes.add(forceRefresh);
    return 'token';
  }

  @override
  Future<void> reload() async => reloads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements FirebaseAuth {
  final user = _FakeUser();
  int signOuts = 0;

  @override
  User get currentUser => user;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthController _controller(_FakeAuth auth, FakeAuthCodeApi api) =>
    AuthController(auth: auth, firestore: _FakeFirestore(), codeApi: api);

Future<void> _pumpScreen(
  WidgetTester tester,
  AuthController controller, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EmailCodeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sends one code in the app locale on mount', (tester) async {
    final api = FakeAuthCodeApi();
    final controller = _controller(_FakeAuth(), api);

    await _pumpScreen(tester, controller, locale: const Locale('ru'));
    await tester.pump(const Duration(seconds: 1));

    expect(api.sentLocales, ['ru']);
  });

  testWidgets('shows no error for a cooldown', (tester) async {
    final api = FakeAuthCodeApi()
      ..sendResult = CodeOk({
        'status': 'cooldown',
        'resendAvailableAt': DateTime.now()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch,
      });

    await _pumpScreen(tester, _controller(_FakeAuth(), api));

    expect(find.textContaining('Could not'), findsNothing);
    expect(find.text('Resend code in 30 s'), findsOneWidget);
  });

  testWidgets('signs out from the app bar', (tester) async {
    final auth = _FakeAuth();
    await _pumpScreen(tester, _controller(auth, FakeAuthCodeApi()));

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(auth.signOuts, 1);
  });

  testWidgets('refreshes the session for an already verified address', (
    tester,
  ) async {
    final auth = _FakeAuth();
    final api = FakeAuthCodeApi()
      ..sendResult = const CodeOk({'status': 'already-verified'});

    await _pumpScreen(tester, _controller(auth, api));

    expect(auth.user.tokenRefreshes, [true]);
    expect(auth.user.reloads, 1);
  });

  test('refreshes the session after an accepted code', () async {
    final auth = _FakeAuth();

    await _controller(auth, FakeAuthCodeApi()).verifyEmailCode('123456');

    expect(auth.user.tokenRefreshes, [true]);
    expect(auth.user.reloads, 1);
  });

  test('leaves the session alone after a refused code', () async {
    final auth = _FakeAuth();
    const refused = CodeFailure(CodeFailureReason.invalidCode);
    final api = FakeAuthCodeApi()..verifyResult = refused;

    final result = await _controller(auth, api).verifyEmailCode('123456');

    expect(result, refused);
    expect(auth.user.tokenRefreshes, isEmpty);
  });

  test('reports offline when the session cannot be refreshed', () async {
    final auth = _FakeAuth()
      ..user.tokenError = FirebaseAuthException(code: 'network-request-failed');

    final result = await _controller(
      auth,
      FakeAuthCodeApi(),
    ).verifyEmailCode('123456');

    expect((result as CodeFailure).reason, CodeFailureReason.offline);
  });
}
