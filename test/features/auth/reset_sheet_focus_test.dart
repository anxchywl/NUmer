import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

import '../../shared/sheet_focus_harness.dart';
import 'reset_sheet_harness.dart';

void main() {
  testWidgets('the email step keeps the field and its submit', (tester) async {
    await openResetSheet(tester, resetApi());

    await typeIn(tester, find.byType(TextField));

    expect(find.text('Reset password'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await hideKeyboard(tester);

    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('the code step keeps the code and verify', (tester) async {
    await openResetSheet(tester, resetApi());
    await typeIn(tester, find.byType(TextField));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(NumerOtpField), findsOneWidget);
    expect(find.textContaining('Start again'), findsNothing);
    expect(find.byType(TextButton).hitTestable(), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);

    await hideKeyboard(tester);

    expect(find.textContaining('Start again'), findsOneWidget);
  });

  testWidgets('the password step folds the other password', (tester) async {
    await openResetSheet(tester, resetApi());
    await reachPasswordStep(tester);
    Finder field(String label) => fieldLabeled(label);

    await typeIn(tester, field('New password'));

    expect(field('Repeat the password'), findsNothing);
    expect(find.textContaining('Start again'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(field('New password'), findsNothing);
    expect(field('Repeat the password'), findsOneWidget);

    await tapDone(tester);

    expect(field('New password'), findsOneWidget);
    expect(field('Repeat the password'), findsOneWidget);
    expect(find.textContaining('Start again'), findsOneWidget);
  });
}
