import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

void main() {
  testWidgets('switches between two text tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NumerModuleScaffold(
          title: 'Market',
          tabLabels: const ['Listings', 'Saved'],
          tabViews: const [Text('first view'), Text('second view')],
        ),
      ),
    );
    final tabs = tester.widgetList<Tab>(find.byType(Tab));

    expect(find.byType(TabBar), findsOneWidget);
    expect(tabs.map((tab) => tab.text), ['Listings', 'Saved']);
    expect(tabs.map((tab) => tab.icon), [null, null]);
    expect(find.text('first view'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('second view'), findsOneWidget);
    expect(find.text('first view'), findsNothing);
  });

  testWidgets('without tabs shows the body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NumerModuleScaffold(title: 'Market', body: const Text('body')),
      ),
    );

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('five tabs are refused', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NumerModuleScaffold(
          title: 'Market',
          tabLabels: const ['1', '2', '3', '4', '5'],
          tabViews: List.filled(5, const SizedBox()),
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });
}
