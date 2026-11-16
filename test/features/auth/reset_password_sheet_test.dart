import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';

import 'reset_sheet_harness.dart';

void main() {
  testWidgets('changes the password in three steps without a sign out', (
    tester,
  ) async {
    final api = resetApi();
    final auth = SignedOutAuth();
    await openResetSheet(tester, api, auth: auth);

    await sendResetCode(tester);
    expect(
      find.text('If an account exists for $resetEmail, a code is on its way.'),
      findsOneWidget,
    );
    await enterResetCode(tester);
    expect(find.text('Set a new password'), findsOneWidget);
    await saveNewPassword(tester);

    expect(api.resetRequests, [(resetEmail, 'en')]);
    expect(api.checkedResetCodes, [(resetEmail, '123456')]);
    expect(api.confirmations, [(resetEmail, 'ticket', resetPassword)]);
    expect(find.byType(ResetPasswordSheet), findsNothing);
    expect(
      find.text('Password changed. Sign in with the new password.'),
      findsOneWidget,
    );
    expect(auth.signOuts, 0);
  });

  testWidgets('treats an unknown email like a known one', (tester) async {
    final seen = <List<String>>[];
    for (final email in [resetEmail, 'nobody@nu.edu.kz']) {
      await tester.pumpWidget(const SizedBox());
      await openResetSheet(tester, resetApi(), initialEmail: email);
      await sendResetCode(tester);
      seen.add([
        for (final text in visibleTexts(tester))
          text.replaceAll(email, '{email}'),
      ]);
    }

    expect(seen.first, seen.last);
    expect(seen.first, contains('Enter the code'));
  });

  testWidgets('sends a trimmed lowercase email in the app locale', (
    tester,
  ) async {
    final api = resetApi();
    await openResetSheet(
      tester,
      api,
      locale: const Locale('ru'),
      initialEmail: '',
    );

    await tester.enterText(find.byType(TextField), 'A.Student@NU.edu.kz');
    await sendResetCode(tester);

    expect(api.resetRequests, [(resetEmail, 'ru')]);
  });

  testWidgets('refuses a malformed email without a call', (tester) async {
    final api = resetApi();
    await openResetSheet(tester, api, initialEmail: 'student@nu');

    await sendResetCode(tester);

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
      final api = resetApi()..sendResult = CodeFailure(reason);
      await openResetSheet(tester, api);

      await sendResetCode(tester);

      expect(find.text(text), findsOneWidget);
      expect(find.text('Reset password'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNotNull);
    });
  }

  testWidgets('counts down a rate limit on the email step', (tester) async {
    final api = resetApi()
      ..sendResult = const CodeFailure(
        CodeFailureReason.rateLimited,
        retryAfterSeconds: 2,
      );
    await openResetSheet(tester, api);

    await sendResetCode(tester);
    expect(find.text('Too many requests. Try again in 2 s.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Too many requests. Try again in 1 s.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Too many requests'), findsNothing);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('keeps the floating label inside a 56 high field', (
    tester,
  ) async {
    await openResetSheet(tester, resetApi());

    final field = tester.getRect(find.byType(TextField));
    final label = tester.getRect(find.text('Email address'));

    expect(field.height, 56);
    expect(label.top, greaterThan(field.top));
  });

  testWidgets('does not call for mismatched passwords', (tester) async {
    final api = resetApi();
    await openResetSheet(tester, api);
    await reachPasswordStep(tester);

    await saveNewPassword(tester, repeated: 'correct-horse-2');

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(api.confirmations, isEmpty);
  });

  testWidgets('does not call for a short password', (tester) async {
    final api = resetApi();
    await openResetSheet(tester, api);
    await reachPasswordStep(tester);

    await saveNewPassword(tester, password: 'short');

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
      final api = resetApi()..confirmResult = CodeFailure(reason);
      await openResetSheet(tester, api);
      await reachPasswordStep(tester);

      await saveNewPassword(tester);

      expect(find.text(text), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNotNull);
    });
  }

  testWidgets('disables saving while rate limited', (tester) async {
    final api = resetApi()
      ..confirmResult = const CodeFailure(
        CodeFailureReason.rateLimited,
        retryAfterSeconds: 30,
      );
    await openResetSheet(tester, api);
    await reachPasswordStep(tester);

    await saveNewPassword(tester);

    expect(find.text('Too many requests. Try again in 30 s.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  const deadTickets = [
    CodeFailureReason.invalidOrExpiredTicket,
    CodeFailureReason.malformedInput,
  ];
  for (final reason in deadTickets) {
    testWidgets('returns to the email step for ${reason.name}', (tester) async {
      final api = resetApi()..confirmResult = CodeFailure(reason);
      await openResetSheet(tester, api);
      await reachPasswordStep(tester);

      await saveNewPassword(tester);

      expect(find.text('Reset password'), findsOneWidget);
      expect(find.text('This reset expired. Start again.'), findsOneWidget);
    });
  }

  testWidgets('starts again from the code step', (tester) async {
    await openResetSheet(tester, resetApi());
    await sendResetCode(tester);

    await tapVisible(tester, find.text('Start again'));

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text(resetEmail), findsOneWidget);
  });

  testWidgets('starts again from the password step', (tester) async {
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);

    await tapVisible(tester, find.text('Start again'));

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.textContaining('expired'), findsNothing);
  });

  testWidgets('survives a keyboard inset below zero', (tester) async {
    addTearDown(tester.view.reset);
    await openResetSheet(tester, resetApi());

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
      final api = resetApi()
        ..confirmResult = const CodeFailure(CodeFailureReason.offline);
      await openResetSheet(
        tester,
        api,
        locale: Locale(language),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);

      await sendResetCode(tester);
      expect(tester.takeException(), isNull);

      await enterResetCode(tester);
      expect(tester.takeException(), isNull);

      await saveNewPassword(tester);
      expect(api.confirmations, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
