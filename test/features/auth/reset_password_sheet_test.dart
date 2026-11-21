import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fake_auth_code_api.dart';

const _email = 'a.student@nu.edu.kz';
const _password = 'correct-horse-1';

class _SignedOutAuth implements FirebaseAuth {
  int signOuts = 0;

  @override
  User? get currentUser => null;

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

FakeAuthCodeApi _api() => FakeAuthCodeApi()
  ..sendResult = const CodeOk({'status': 'accepted'})
  ..verifyResult = const CodeOk({'resetTicket': 'ticket'});

Future<void> _openSheet(
  WidgetTester tester,
  FakeAuthCodeApi api, {
  _SignedOutAuth? auth,
  Locale locale = const Locale('en'),
  double textScale = 1,
  String? initialEmail = _email,
}) async {
  final controller = AuthController(
    auth: auth ?? _SignedOutAuth(),
    firestore: _FakeFirestore(),
    codeApi: api,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showResetPasswordSheet(context, initialEmail: initialEmail),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _sendCode(WidgetTester tester) =>
    _tap(tester, find.byType(FilledButton));

Future<void> _enterCode(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '123456');
  await tester.pumpAndSettle();
}

Future<void> _reachPasswordStep(WidgetTester tester) async {
  await _sendCode(tester);
  await _enterCode(tester);
}

Future<void> _savePassword(
  WidgetTester tester, {
  String password = _password,
  String? repeated,
}) async {
  await tester.enterText(find.byType(TextField).first, password);
  await tester.enterText(find.byType(TextField).last, repeated ?? password);
  await _tap(tester, find.byType(FilledButton));
}

FilledButton _button(WidgetTester tester) =>
    tester.widget(find.byType(FilledButton));

List<bool> _finishedAutofill(WidgetTester tester) => [
  for (final call in tester.testTextInput.log)
    if (call.method == 'TextInput.finishAutofillContext')
      call.arguments as bool,
];

List<String> _visibleTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? '',
];

void main() {
  testWidgets('changes the password in three steps without a sign out', (
    tester,
  ) async {
    final api = _api();
    final auth = _SignedOutAuth();
    await _openSheet(tester, api, auth: auth);

    await _sendCode(tester);
    expect(
      find.text('If an account exists for $_email, a code is on its way.'),
      findsOneWidget,
    );
    await _enterCode(tester);
    expect(find.text('Set a new password'), findsOneWidget);
    await _savePassword(tester);

    expect(api.resetRequests, [(_email, 'en')]);
    expect(api.checkedResetCodes, [(_email, '123456')]);
    expect(api.confirmations, [(_email, 'ticket', _password)]);
    expect(find.byType(ResetPasswordSheet), findsNothing);
    expect(
      find.text('Password changed. Sign in with the new password.'),
      findsOneWidget,
    );
    expect(auth.signOuts, 0);
  });

  testWidgets('treats an unknown email like a known one', (tester) async {
    final seen = <List<String>>[];
    for (final email in [_email, 'nobody@nu.edu.kz']) {
      await tester.pumpWidget(const SizedBox());
      await _openSheet(tester, _api(), initialEmail: email);
      await _sendCode(tester);
      seen.add([
        for (final text in _visibleTexts(tester))
          text.replaceAll(email, '{email}'),
      ]);
    }

    expect(seen.first, seen.last);
    expect(seen.first, contains('Enter the code'));
  });

  testWidgets('sends a trimmed lowercase email in the app locale', (
    tester,
  ) async {
    final api = _api();
    await _openSheet(tester, api, locale: const Locale('ru'), initialEmail: '');

    await tester.enterText(find.byType(TextField), 'A.Student@NU.edu.kz');
    await _sendCode(tester);

    expect(api.resetRequests, [(_email, 'ru')]);
  });

  testWidgets('refuses a malformed email without a call', (tester) async {
    final api = _api();
    await _openSheet(tester, api, initialEmail: 'student@nu');

    await _sendCode(tester);

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(api.resetRequests, isEmpty);
  });

  const emailStepErrors = {
    CodeFailureReason.invalidEmail: 'Enter a valid email address.',
    CodeFailureReason.offline:
        'No connection. Check the network and try again.',
    CodeFailureReason.unknown: 'Could not send the request. Try again.',
  };
  for (final MapEntry(key: reason, value: text) in emailStepErrors.entries) {
    testWidgets('stays on the email step for ${reason.name}', (tester) async {
      final api = _api()..sendResult = CodeFailure(reason);
      await _openSheet(tester, api);

      await _sendCode(tester);

      expect(find.text(text), findsOneWidget);
      expect(find.text('Reset password'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
    });
  }

  testWidgets('counts down a rate limit on the email step', (tester) async {
    final api = _api()
      ..sendResult = const CodeFailure(
        CodeFailureReason.rateLimited,
        retryAfterSeconds: 2,
      );
    await _openSheet(tester, api);

    await _sendCode(tester);
    expect(find.text('Too many requests. Try again in 2 s.'), findsOneWidget);
    expect(_button(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Too many requests. Try again in 1 s.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Too many requests'), findsNothing);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('keeps the floating label inside a 56 high field', (
    tester,
  ) async {
    await _openSheet(tester, _api());

    final field = tester.getRect(find.byType(TextField));
    final label = tester.getRect(find.text('Email address'));

    expect(field.height, 56);
    expect(label.top, greaterThan(field.top));
  });

  testWidgets('offers the email and both passwords for autofill', (
    tester,
  ) async {
    await _openSheet(tester, _api());
    await _reachPasswordStep(tester);
    tester.testTextInput.log.clear();

    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    final client = tester.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    final config = (client.arguments as List<dynamic>)[1] as Map;
    final fields = [
      for (final field in config['fields'] as List<dynamic>)
        (field as Map)['autofill'] as Map,
    ];
    expect([
      for (final field in fields) (field['hints'] as List<dynamic>).single,
    ], unorderedEquals(['email', 'newPassword', 'newPassword']));
    expect([
      for (final field in fields) (field['editingValue'] as Map)['text'],
    ], contains(_email));
  });

  testWidgets('keeps the keyboard moving between the visible fields', (
    tester,
  ) async {
    await _openSheet(tester, _api());
    await _reachPasswordStep(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final confirmation = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(confirmation.focusNode.hasFocus, isTrue);
  });

  testWidgets('saves the autofill context only after a success', (
    tester,
  ) async {
    await _openSheet(tester, _api());
    await _reachPasswordStep(tester);
    tester.testTextInput.log.clear();

    await _savePassword(tester);

    expect(_finishedAutofill(tester).first, isTrue);
  });

  testWidgets('drops the autofill context when starting again', (tester) async {
    await _openSheet(tester, _api());
    await _reachPasswordStep(tester);
    await tester.enterText(find.byType(TextField).first, _password);
    tester.testTextInput.log.clear();

    await _tap(tester, find.text('Start again'));

    expect(_finishedAutofill(tester), [false]);
  });

  testWidgets('does not call for mismatched passwords', (tester) async {
    final api = _api();
    await _openSheet(tester, api);
    await _reachPasswordStep(tester);

    await _savePassword(tester, repeated: 'correct-horse-2');

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(api.confirmations, isEmpty);
  });

  testWidgets('does not call for a short password', (tester) async {
    final api = _api();
    await _openSheet(tester, api);
    await _reachPasswordStep(tester);

    await _savePassword(tester, password: 'short');

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(api.confirmations, isEmpty);
  });

  const passwordStepErrors = {
    CodeFailureReason.weakPassword: 'Password must be at least 8 characters.',
    CodeFailureReason.offline:
        'No connection. Check the network and try again.',
    CodeFailureReason.unknown: 'Could not save the password. Try again.',
  };
  for (final MapEntry(key: reason, value: text) in passwordStepErrors.entries) {
    testWidgets('stays on the password step for ${reason.name}', (
      tester,
    ) async {
      final api = _api()..confirmResult = CodeFailure(reason);
      await _openSheet(tester, api);
      await _reachPasswordStep(tester);

      await _savePassword(tester);

      expect(find.text(text), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
    });
  }

  testWidgets('disables saving while rate limited', (tester) async {
    final api = _api()
      ..confirmResult = const CodeFailure(
        CodeFailureReason.rateLimited,
        retryAfterSeconds: 30,
      );
    await _openSheet(tester, api);
    await _reachPasswordStep(tester);

    await _savePassword(tester);

    expect(find.text('Too many requests. Try again in 30 s.'), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
  });

  const deadTickets = [
    CodeFailureReason.invalidOrExpiredTicket,
    CodeFailureReason.malformedInput,
  ];
  for (final reason in deadTickets) {
    testWidgets('returns to the email step for ${reason.name}', (tester) async {
      final api = _api()..confirmResult = CodeFailure(reason);
      await _openSheet(tester, api);
      await _reachPasswordStep(tester);

      await _savePassword(tester);

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('This reset expired. Start again.'), findsOneWidget);
    });
  }

  testWidgets('starts again from the code step', (tester) async {
    await _openSheet(tester, _api());
    await _sendCode(tester);

    await _tap(tester, find.text('Start again'));

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text(_email), findsOneWidget);
  });

  testWidgets('starts again from the password step', (tester) async {
    await _openSheet(tester, _api());
    await _reachPasswordStep(tester);

    await _tap(tester, find.text('Start again'));

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.textContaining('expired'), findsNothing);
  });

  testWidgets('survives a keyboard inset below zero', (tester) async {
    addTearDown(tester.view.reset);
    await _openSheet(tester, _api());

    tester.view.viewInsets = const FakeViewPadding(bottom: -1);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ru', 'kk']) {
    testWidgets('fits a narrow screen with large $language text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final api = _api()
        ..confirmResult = const CodeFailure(CodeFailureReason.offline);
      await _openSheet(tester, api, locale: Locale(language), textScale: 1.3);
      expect(tester.takeException(), isNull);

      await _sendCode(tester);
      expect(tester.takeException(), isNull);

      await _enterCode(tester);
      expect(tester.takeException(), isNull);

      await _savePassword(tester);
      expect(api.confirmations, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
