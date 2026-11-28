import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/account/widgets/delete_account_sheet.dart';
import 'package:numer_app/features/account/widgets/settings/settings_delete_confirm.dart';

import '../../shared/sheet_focus_harness.dart';

void main() {
  testWidgets('the password sheet keeps the field and delete', (tester) async {
    await openSheet(
      tester,
      (context) => showDeleteAccountSheet(context, onDelete: (_) async => null),
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.textContaining('Enter your password'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Delete'));

    await hideKeyboard(tester);

    expect(find.textContaining('Enter your password'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('the phrase dialog keeps the phrase and field', (tester) async {
    await openSheet(
      tester,
      (context) => showDialog<bool>(
        context: context,
        builder: (_) => const DeleteAccountTextConfirmDialog(),
      ),
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.text('Final Confirmation'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('I really want to delete my account'), findsOneWidget);
    expectAboveKeyboard(
      tester,
      find.widgetWithText(FilledButton, 'Delete Forever'),
    );

    await hideKeyboard(tester);

    expect(find.text('Final Confirmation'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
