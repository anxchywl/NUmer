import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/habits/widgets/habit_logging_sheet.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

class _Habits extends FakeHabits {
  @override
  Stream<void> get historyUpdates => const Stream.empty();
}

void main() {
  testWidgets('logging keeps the value and its submit', (tester) async {
    await openSheet(
      tester,
      (context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => HabitLoggingSheet(
          habit: habit('Water', target: 8),
          date: DateTime(2026, 5, 4),
          userId: 'u1',
        ),
      ),
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => FakeState()),
        Provider<HabitService>(create: (_) => _Habits()),
      ],
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.text('Water'), findsNothing);
    expect(find.text('Set total'), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expectAboveKeyboard(
      tester,
      find.widgetWithText(FilledButton, 'Update progress'),
    );

    await hideKeyboard(tester);

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Set total'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });
}
