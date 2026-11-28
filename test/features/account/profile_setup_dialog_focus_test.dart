import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/account/account.dart';

import '../../shared/sheet_focus_harness.dart';

Future<void> _open(BuildContext context) => showGeneralDialog<void>(
  context: context,
  pageBuilder: (_, _, _) => ProfileSetupDialog(
    formBuilder: (focus) => ProfileForm(
      focusMode: focus,
      initialName: 'Aru',
      autofocusName: true,
      primaryButtonLabel: 'Save profile',
      onSubmit: (_) async {},
    ),
  ),
);

void main() {
  testWidgets('profile setup keeps the typed field and done', (tester) async {
    await openSheet(tester, _open);

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

  testWidgets('done after another field leaves nothing focused', (
    tester,
  ) async {
    await openSheet(tester, _open);
    expect(focusedFields(tester), 1);
    await showKeyboard(tester);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(fieldLabeled('Major'), findsOneWidget);

    await tapDone(tester);

    expect(focusedFields(tester), 0);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Save profile'), findsOneWidget);
  });
}
