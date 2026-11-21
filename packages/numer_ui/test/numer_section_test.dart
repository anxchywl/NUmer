import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _child = SizedBox(key: Key('child'), height: 10, width: 10);

Widget _app({String? actionLabel, VoidCallback? onAction}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: NumerSection(
          title: 'Today',
          actionLabel: actionLabel,
          onAction: onAction,
          child: _child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('puts 8 under the title and 24 under the child', (tester) async {
    await tester.pumpWidget(_app());
    final title = tester.getRect(find.text('Today'));
    final child = tester.getRect(find.byKey(const Key('child')));

    expect(title.left, 16);
    expect(child.top - title.bottom, 8);
    expect(child.left, 0);
    expect(tester.getRect(find.byType(NumerSection)).bottom - child.bottom, 24);
  });

  testWidgets('shows the action only with a label and a callback', (
    tester,
  ) async {
    await tester.pumpWidget(_app(actionLabel: 'All'));
    expect(find.byType(TextButton), findsNothing);

    await tester.pumpWidget(_app(onAction: () {}));
    expect(find.byType(TextButton), findsNothing);

    var taps = 0;
    await tester.pumpWidget(_app(actionLabel: 'All', onAction: () => taps++));
    await tester.tap(find.text('All'));
    expect(taps, 1);
  });
}
