import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Future<ColorScheme> _show(
  WidgetTester tester, {
  bool isError = false,
  VoidCallback? onAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNumerMessage(
              context,
              'Session saved.',
              isError: isError,
              actionLabel: onAction == null ? null : 'Undo',
              onAction: onAction,
            ),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
  return Theme.of(tester.element(find.byType(SnackBar))).colorScheme;
}

void main() {
  testWidgets('floats for 4 seconds with radius 16', (tester) async {
    final scheme = await _show(tester);
    final toast = tester.widget<SnackBar>(find.byType(SnackBar));
    final shape = toast.shape! as RoundedRectangleBorder;

    expect(toast.behavior, SnackBarBehavior.floating);
    expect(toast.duration, const Duration(seconds: 4));
    expect(shape.borderRadius, BorderRadius.circular(16));
    expect(toast.backgroundColor, scheme.primaryContainer);
    expect(toast.action, isNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an error uses the error container', (tester) async {
    final scheme = await _show(tester, isError: true);
    final toast = tester.widget<SnackBar>(find.byType(SnackBar));

    expect(toast.backgroundColor, scheme.errorContainer);
  });

  testWidgets('the action calls back', (tester) async {
    var calls = 0;
    await _show(tester, onAction: () => calls++);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
