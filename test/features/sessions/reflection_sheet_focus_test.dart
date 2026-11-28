import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/sessions/sessions.dart';

import '../../shared/sheet_focus_harness.dart';

void main() {
  testWidgets('the reflection sheet keeps the note and save', (tester) async {
    await openSheet(
      tester,
      (context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ReflectionBottomSheet(
          sessionId: 'session',
          durationSeconds: 120,
        ),
      ),
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.textContaining('Session finished'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Save'));

    await hideKeyboard(tester);

    expect(find.textContaining('Session finished'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
