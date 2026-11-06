import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/account/widgets/delete_account_sheet.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class _FakeDelete {
  _FakeDelete(this.correctPassword);

  final String correctPassword;
  final passwords = <String>[];
  int callableCalls = 0;

  Future<DeleteAccountFailure?> call(String password) async {
    passwords.add(password);
    if (password != correctPassword) return DeleteAccountFailure.wrongPassword;
    callableCalls++;
    return null;
  }
}

Future<List<bool>> _open(WidgetTester tester, _FakeDelete delete) async {
  final results = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(
              await showDeleteAccountSheet(context, onDelete: delete.call),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('a wrong password shows the error and keeps the sheet open', (
    tester,
  ) async {
    final delete = _FakeDelete('right');
    await _open(tester, delete);

    expect(
      find.text('Enter your password to delete the account'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong password. Try again.'), findsOneWidget);
    expect(find.byType(DeleteAccountSheet), findsOneWidget);
    expect(delete.passwords, ['wrong']);
    expect(delete.callableCalls, 0);
  });

  testWidgets('success closes the sheet and reports the deletion', (
    tester,
  ) async {
    final delete = _FakeDelete('right');
    final results = await _open(tester, delete);

    await tester.enterText(find.byType(TextField), 'right');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountSheet), findsNothing);
    expect(results, [true]);
    expect(delete.callableCalls, 1);
  });

  testWidgets('cancel closes the sheet without deleting', (tester) async {
    final delete = _FakeDelete('right');
    final results = await _open(tester, delete);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountSheet), findsNothing);
    expect(results, [false]);
    expect(delete.passwords, isEmpty);
  });
}
