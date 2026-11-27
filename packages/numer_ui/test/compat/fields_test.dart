import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/compat.dart';

import 'host.dart';

void main() {
  testWidgets('a field validates and trims doubled spaces', (tester) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        Form(
          key: form,
          child: AppTextField(
            controller: controller,
            validator: (value) => 'Required',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(AppTextField), '  two  words');
    form.currentState!.validate();
    await tester.pump();

    expect(controller.text, 'two words');
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('the search bar clears its text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var cleared = 0;
    await tester.pumpWidget(
      host(
        GlobalSearchBar(
          controller: controller,
          clearTooltip: 'Clear',
          onClear: () => cleared++,
        ),
      ),
    );
    expect(find.byTooltip('Clear'), findsNothing);

    await tester.enterText(find.byType(GlobalSearchBar), 'piano');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear'));

    expect(controller.text, isEmpty);
    expect(cleared, 1);
  });

  testWidgets('a page loader draws a skeleton, an action loader nothing', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AppLoader()));
    expect(find.byType(NumerSkeleton), findsNothing);

    await tester.pumpWidget(host(const AppLoader(page: true)));
    expect(find.byType(NumerSkeleton), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('a third app bar action is refused', (tester) async {
    await tester.pumpWidget(
      host(const AppAppBar(actions: [SizedBox(), SizedBox(), SizedBox()])),
    );

    expect(tester.takeException(), isAssertionError);
  });
}
