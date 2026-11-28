import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/account/account.dart';

import '../../shared/sheet_focus_harness.dart';

void main() {
  testWidgets('profile setup keeps the typed field and done', (tester) async {
    await openSheet(
      tester,
      (context) => showGeneralDialog<void>(
        context: context,
        pageBuilder: (_, _, _) => ProfileSetupDialog(
          formBuilder: (focus) => ProfileForm(
            focusMode: focus,
            initialName: 'Aru',
            primaryButtonLabel: 'Save profile',
            onSubmit: (_) async {},
          ),
        ),
      ),
    );

    await typeIn(tester, fieldLabeled('Name'));

    expect(find.textContaining('Welcome'), findsNothing);
    expect(fieldLabeled('Major'), findsNothing);
    expect(find.text('Save profile'), findsNothing);
    expectAboveKeyboard(tester, fieldLabeled('Name'));
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Done'));

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(fieldLabeled('Name'), findsNothing);
    expect(fieldLabeled('Major'), findsOneWidget);

    await tapDone(tester);

    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(fieldLabeled('Name'), findsOneWidget);
    expect(find.text('Save profile'), findsOneWidget);
  });
}
