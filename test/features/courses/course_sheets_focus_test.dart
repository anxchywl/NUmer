import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) => openSheet(
  tester,
  open,
  providers: [ChangeNotifierProvider<AppState>(create: (_) => FakeState())],
);

void main() {
  testWidgets('add course keeps the typed field and done', (tester) async {
    await _open(tester, showAddCourseSheet);

    await typeIn(tester, fieldLabeled('Course name'));

    expect(find.text('Add course'), findsNothing);
    expect(find.text('Color'), findsNothing);
    expect(fieldLabeled('Credits (optional)'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expectAboveKeyboard(tester, fieldLabeled('Course name'));
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Done'));

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(fieldLabeled('Course name'), findsNothing);
    expect(fieldLabeled('Credits (optional)'), findsOneWidget);

    await tapDone(tester);

    expect(find.text('Add course'), findsOneWidget);
    expect(fieldLabeled('Course name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('edit course keeps the name and its save', (tester) async {
    await _open(
      tester,
      (context) => showEditCourseDialog(context, course('a', 'Algebra')),
    );

    await typeIn(tester, fieldLabeled('Course name'));

    expect(find.text('Edit course'), findsNothing);
    expect(find.text('Color'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Save'));

    await hideKeyboard(tester);

    expect(find.text('Edit course'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
