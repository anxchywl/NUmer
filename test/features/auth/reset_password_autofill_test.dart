import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';

import 'reset_sheet_harness.dart';

void main() {
  testWidgets('offers the email and both passwords for autofill', (
    tester,
  ) async {
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);
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
    ], contains(resetEmail));
  });

  testWidgets('keeps the keyboard moving between the visible fields', (
    tester,
  ) async {
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);
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
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);
    tester.testTextInput.log.clear();

    await saveNewPassword(tester);

    expect(finishedAutofill(tester).first, isTrue);
  });

  testWidgets('drops the autofill context when starting again', (tester) async {
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);
    await tester.enterText(find.byType(TextField).first, resetPassword);
    tester.testTextInput.log.clear();

    await tapVisible(tester, find.text('Start again'));

    expect(finishedAutofill(tester), [false]);
  });

  testWidgets('asks to sign in when the reply to a save was lost', (
    tester,
  ) async {
    final api = resetApi()
      ..confirmResult = const CodeFailure(CodeFailureReason.offline);
    await openResetSheet(tester, api);
    await reachPasswordStep(tester);
    await saveNewPassword(tester);
    api.confirmResult = const CodeFailure(
      CodeFailureReason.invalidOrExpiredTicket,
    );
    tester.testTextInput.log.clear();

    await tapVisible(tester, find.byType(FilledButton));

    expect(find.byType(ResetPasswordSheet), findsNothing);
    expect(
      find.text(
        'Sign in with the new password. If that fails, reset it again.',
      ),
      findsOneWidget,
    );
    expect(finishedAutofill(tester).first, isTrue);
  });

  testWidgets('forgets a lost reply when starting again', (tester) async {
    final api = resetApi()
      ..confirmResult = const CodeFailure(CodeFailureReason.offline);
    await openResetSheet(tester, api);
    await reachPasswordStep(tester);
    await saveNewPassword(tester);
    await tapVisible(tester, find.text('Start again'));
    api.confirmResult = const CodeFailure(
      CodeFailureReason.invalidOrExpiredTicket,
    );
    await reachPasswordStep(tester);

    await saveNewPassword(tester);

    expect(find.text('This reset expired. Start again.'), findsOneWidget);
  });
}
