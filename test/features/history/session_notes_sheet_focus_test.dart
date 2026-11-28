import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/history/widgets/session_notes_sheet.dart';

import '../../shared/sheet_focus_harness.dart';

void main() {
  testWidgets('session notes keep the field and their submit', (tester) async {
    await openSheet(
      tester,
      (context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SessionNotesSheet(initialNotes: ''),
      ),
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.text('Session notes'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expectAboveKeyboard(tester, find.byType(FilledButton));

    await hideKeyboard(tester);

    expect(find.text('Session notes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
