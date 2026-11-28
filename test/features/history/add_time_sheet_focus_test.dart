import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/history/widgets/add_time_sheet.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

Future<void> _open(WidgetTester tester) => openSheet(
  tester,
  (context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTimeSheet(day: DateTime(2026, 5, 4)),
  ),
  providers: [
    ChangeNotifierProvider<AppState>(
      create: (_) =>
          FakeState(courses: [course('a', 'Algebra'), course('b', 'Biology')]),
    ),
  ],
);

void main() {
  testWidgets('add time keeps the typed time and done', (tester) async {
    await _open(tester);

    await typeIn(tester, fieldLabeled('Start'));

    expect(find.text('Add time'), findsNothing);
    expect(fieldLabeled('End'), findsNothing);
    expect(find.text('Algebra'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expectAboveKeyboard(tester, fieldLabeled('Start'));
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Done'));

    await tester.enterText(fieldLabeled('Start'), '0930');
    await tapDone(tester);

    expect(find.text('Add time'), findsOneWidget);
    expect(find.text('09:30:00'), findsOneWidget);
    expect(fieldLabeled('End'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('next moves to the end time', (tester) async {
    await _open(tester);
    await typeIn(tester, fieldLabeled('Start'));

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(fieldLabeled('Start'), findsNothing);
    expect(fieldLabeled('End'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('the picked course survives typing', (tester) async {
    await _open(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -120));
    await tester.pumpAndSettle();
    double page() =>
        tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(page(), 1);

    await typeIn(tester, fieldLabeled('Start'));
    await tapDone(tester);

    expect(page(), 1);
  });
}
