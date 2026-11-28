import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

Future<void> _open(WidgetTester tester) => openSheet(
  tester,
  (context) => showCourseTimeSheet(context, course('a', 'Algebra')),
  providers: [ChangeNotifierProvider<AppState>(create: (_) => FakeState())],
);

void main() {
  testWidgets('timer entry keeps the time fields and done', (tester) async {
    await _open(tester);
    final fields = find.byType(TextField);

    await typeIn(tester, fields.first);

    expect(find.text('Algebra'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.text('00:00:00'), findsNothing);
    expect(fields, findsNWidgets(3));
    expectAboveKeyboard(tester, fields.first);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Done'));

    await tapDone(tester);

    expect(find.text('Algebra'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('two digits move to the next field while typing', (tester) async {
    await _open(tester);
    final fields = find.byType(TextField);
    await typeIn(tester, fields.first);

    await tester.enterText(fields.first, '12');
    await tester.pumpAndSettle();

    final minutes = tester.widget<TextField>(fields.at(1));
    expect(minutes.focusNode!.hasFocus, isTrue);
    expect(find.text('Done'), findsWidgets);
  });
}
