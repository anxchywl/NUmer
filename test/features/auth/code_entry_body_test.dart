import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/auth/widgets/code_entry_body.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

const _expired = 'Code expired. Request a new one.';
const _wrongOrExpired = 'Wrong or expired code. Request a new one.';
const _tooMany = 'Too many wrong attempts. Request a new code.';
const _undelivered = 'Could not send the email. Try again.';
const _offline = 'No connection. Check the network and try again.';
const _checkFailed = 'Could not check the code. Try again.';

class _Calls {
  final List<String> submitted = [];
  final List<CodeOk> verified = [];
  int resends = 0;
  Future<CodeResult> submitResult = Future.value(
    const CodeOk({'verified': true}),
  );
  CodeResult resendResult = const CodeOk({'status': 'sent'});
}

CodeOk _sent({Duration cooldown = Duration.zero}) => CodeOk({
  'status': 'sent',
  'resendAvailableAt': DateTime.now().add(cooldown).millisecondsSinceEpoch,
});

Widget _app(
  _Calls calls, {
  CodeResult? initialResult,
  String? initialMessage,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) {
  return MaterialApp(
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
      body: CodeEntryBody(
        subtitle: 'We sent a 6-digit code to a.student@nu.edu.kz',
        initialResult: initialResult,
        initialMessage: initialMessage,
        onSubmit: (code) {
          calls.submitted.add(code);
          return calls.submitResult;
        },
        onResend: () async {
          calls.resends++;
          return calls.resendResult;
        },
        onVerified: calls.verified.add,
      ),
    ),
  );
}

bool _fieldEnabled(WidgetTester tester) =>
    tester.widget<NumerOtpField>(find.byType(NumerOtpField)).enabled;

bool _fieldHasError(WidgetTester tester) =>
    tester.widget<NumerOtpField>(find.byType(NumerOtpField)).hasError;

String _typed(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

bool _verifyEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton)).enabled;

bool _resendEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(find.byType(TextButton)).enabled;

Future<void> _type(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tester.pump();
}

Future<_Calls> _submitFailing(WidgetTester tester, CodeFailure failure) async {
  final calls = _Calls()..submitResult = Future.value(failure);
  await tester.pumpWidget(_app(calls, initialResult: _sent()));
  await _type(tester, '123456');
  return calls;
}

void main() {
  testWidgets('shows the attempts left and clears the field', (tester) async {
    await _submitFailing(
      tester,
      const CodeFailure(CodeFailureReason.invalidCode, attemptsLeft: 4),
    );

    expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    expect(_fieldHasError(tester), isTrue);
    expect(_typed(tester), isEmpty);
    expect(_fieldEnabled(tester), isTrue);
    expect(_verifyEnabled(tester), isFalse);
    expect(_resendEnabled(tester), isTrue);
  });

  testWidgets('uses the singular for the last attempt', (tester) async {
    await _submitFailing(
      tester,
      const CodeFailure(CodeFailureReason.invalidCode, attemptsLeft: 1),
    );

    expect(find.text('Wrong code. 1 attempt left.'), findsOneWidget);
  });

  const rejected = [
    CodeFailureReason.invalidCode,
    CodeFailureReason.malformedCode,
    CodeFailureReason.malformedInput,
    CodeFailureReason.invalidOrExpiredCode,
  ];
  for (final reason in rejected) {
    testWidgets('marks the field for ${reason.name}', (tester) async {
      await _submitFailing(tester, CodeFailure(reason));

      expect(find.text(_wrongOrExpired), findsOneWidget);
      expect(_fieldHasError(tester), isTrue);
      expect(_typed(tester), isEmpty);
      expect(_fieldEnabled(tester), isTrue);
      expect(_verifyEnabled(tester), isFalse);
      expect(_resendEnabled(tester), isTrue);
    });
  }

  const keptCode = {
    CodeFailureReason.codeExpired: _expired,
    CodeFailureReason.noActiveCode: _expired,
    CodeFailureReason.deliveryFailed: _undelivered,
    CodeFailureReason.noEmail: _undelivered,
    CodeFailureReason.offline: _offline,
    CodeFailureReason.unknown: _checkFailed,
  };
  for (final MapEntry(key: reason, value: text) in keptCode.entries) {
    testWidgets('keeps the code for ${reason.name}', (tester) async {
      await _submitFailing(tester, CodeFailure(reason));

      expect(find.text(text), findsOneWidget);
      expect(_fieldHasError(tester), isFalse);
      expect(_typed(tester), '123456');
      expect(_fieldEnabled(tester), isTrue);
      expect(_verifyEnabled(tester), isTrue);
      expect(_resendEnabled(tester), isTrue);
    });
  }

  testWidgets('locks after too many attempts until a new code', (tester) async {
    final calls = await _submitFailing(
      tester,
      const CodeFailure(CodeFailureReason.tooManyAttempts),
    );

    expect(find.text(_tooMany), findsOneWidget);
    expect(_fieldEnabled(tester), isFalse);
    expect(_verifyEnabled(tester), isFalse);
    expect(_resendEnabled(tester), isTrue);

    calls.resendResult = const CodeOk({'status': 'cooldown'});
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(_fieldEnabled(tester), isFalse);

    calls.resendResult = const CodeOk({'status': 'sent'});
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(_fieldEnabled(tester), isTrue);
    expect(find.text(_tooMany), findsNothing);
  });

  testWidgets('counts a rate limit down and releases the buttons', (
    tester,
  ) async {
    await _submitFailing(
      tester,
      const CodeFailure(CodeFailureReason.rateLimited, retryAfterSeconds: 2),
    );

    expect(find.text('Too many requests. Try again in 2 s.'), findsOneWidget);
    expect(_fieldEnabled(tester), isTrue);
    expect(_verifyEnabled(tester), isFalse);
    expect(_resendEnabled(tester), isFalse);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Too many requests. Try again in 1 s.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Too many requests'), findsNothing);
    expect(_verifyEnabled(tester), isTrue);
    expect(_resendEnabled(tester), isTrue);
  });

  testWidgets('waits 60 seconds for a rate limit without a delay', (
    tester,
  ) async {
    await _submitFailing(
      tester,
      const CodeFailure(CodeFailureReason.rateLimited),
    );

    expect(find.text('Too many requests. Try again in 60 s.'), findsOneWidget);
  });

  testWidgets('disables verify with five digits', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls, initialResult: _sent()));

    await _type(tester, '12345');

    expect(_verifyEnabled(tester), isFalse);
    expect(calls.submitted, isEmpty);
  });

  testWidgets('submits six digits once and reports success', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls, initialResult: _sent()));

    await _type(tester, '123456');

    expect(calls.submitted, ['123456']);
    expect(calls.verified, hasLength(1));
  });

  testWidgets('shows loading and disables input while checking', (
    tester,
  ) async {
    final answer = Completer<CodeResult>();
    final calls = _Calls()..submitResult = answer.future;
    await tester.pumpWidget(_app(calls, initialResult: _sent()));

    await _type(tester, '123456');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_fieldEnabled(tester), isFalse);
    expect(_verifyEnabled(tester), isFalse);
    expect(_resendEnabled(tester), isFalse);

    answer.complete(const CodeFailure(CodeFailureReason.offline));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(calls.submitted, ['123456', '123456']);
  });

  testWidgets('counts the cooldown down and enables resend', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _app(calls, initialResult: _sent(cooldown: const Duration(seconds: 3))),
    );

    expect(find.text('Resend code in 3 s'), findsOneWidget);
    expect(_resendEnabled(tester), isFalse);

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Resend code'), findsOneWidget);
    expect(_resendEnabled(tester), isTrue);
  });

  testWidgets('clamps a far resend time to 60 seconds', (tester) async {
    await tester.pumpWidget(
      _app(_Calls(), initialResult: _sent(cooldown: const Duration(days: 1))),
    );

    expect(find.text('Resend code in 60 s'), findsOneWidget);
  });

  testWidgets('clears the field after a resend', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls, initialResult: _sent()));
    await _type(tester, '123');

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump();

    expect(calls.resends, 1);
    expect(_typed(tester), isEmpty);
    expect(find.text('New code sent.'), findsOneWidget);
  });

  testWidgets('keeps the field when the resend is still cooling down', (
    tester,
  ) async {
    final calls = _Calls()..resendResult = const CodeOk({'status': 'cooldown'});
    await tester.pumpWidget(_app(calls, initialResult: _sent()));
    await _type(tester, '123');

    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(_typed(tester), '123');
    expect(find.text('New code sent.'), findsNothing);
  });

  testWidgets('waits for the first send and then shows its failure', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_app(calls, initialMessage: 'Sending'));

    expect(find.text('Sending'), findsOneWidget);
    expect(_fieldEnabled(tester), isTrue);
    expect(_resendEnabled(tester), isFalse);

    await tester.pumpWidget(
      _app(
        calls,
        initialMessage: 'Sending',
        initialResult: const CodeFailure(CodeFailureReason.deliveryFailed),
      ),
    );

    expect(find.text('Sending'), findsNothing);
    expect(find.text(_undelivered), findsOneWidget);
    expect(_resendEnabled(tester), isTrue);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('fits 320 wide at text scale 1.3 in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = _Calls()
        ..submitResult = Future.value(
          const CodeFailure(CodeFailureReason.tooManyAttempts),
        );
      await tester.pumpWidget(
        _app(
          calls,
          locale: locale,
          textScale: 1.3,
          initialResult: _sent(cooldown: const Duration(seconds: 59)),
        ),
      );

      await _type(tester, '123456');

      expect(tester.takeException(), isNull);
    });
  }
}
