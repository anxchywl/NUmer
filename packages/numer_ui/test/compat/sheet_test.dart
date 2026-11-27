import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/compat.dart';

import 'host.dart';

const double _inset = 34;

Widget _nested(void Function(BuildContext context) open) {
  return host(
    Navigator(
      key: GlobalKey<NavigatorState>(),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => Center(
          child: AppTextButton(text: 'Open', onPressed: () => open(context)),
        ),
      ),
    ),
  );
}

Finder _insideNested(String text) {
  return find.descendant(
    of: find.byType(Navigator).last,
    matching: find.text(text),
  );
}

void main() {
  testWidgets('a sheet opens on the root navigator by default', (tester) async {
    await tester.pumpWidget(
      _nested(
        (context) => AppBottomSheet.show<void>(
          context: context,
          title: 'Report',
          child: const Text('Body'),
        ),
      ),
    );
    final nested = tester.state<NavigatorState>(find.byType(Navigator).last);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Report'), findsOneWidget);
    expect(nested.canPop(), isFalse);
  });

  testWidgets('a sheet can stay on the nested navigator', (tester) async {
    await tester.pumpWidget(
      _nested(
        (context) => AppBottomSheet.show<void>(
          context: context,
          useRootNavigator: false,
          child: const Text('Body'),
        ),
      ),
    );
    final nested = tester.state<NavigatorState>(find.byType(Navigator).last);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(nested.canPop(), isTrue);
    expect(_insideNested('Body'), findsOneWidget);
  });

  testWidgets('a sheet pads the bottom safe area', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: _inset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _nested(
        (context) => AppBottomSheet.show<void>(
          context: context,
          child: const Text('Body'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize.height;
    expect(
      tester.getBottomLeft(find.text('Body')).dy,
      screen - _inset - NumerSpace.sm,
    );
  });

  testWidgets('a sheet keeps to its height fraction', (tester) async {
    await tester.pumpWidget(
      _nested(
        (context) => AppBottomSheet.show<void>(
          context: context,
          maxHeightFraction: 0.5,
          child: const SizedBox(height: 2000, child: Text('Tall')),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(SingleChildScrollView)).height,
      lessThanOrEqualTo(300),
    );
  });

  testWidgets('a selection returns the tapped value', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _nested((context) async {
        picked = await AppBottomSheet.showSelection<int>(
          context: context,
          title: 'Period',
          selectedValue: 1,
          options: const [
            AppBottomSheetOption(title: 'Week', value: 1),
            AppBottomSheetOption(title: 'Month', value: 2),
          ],
        );
      }),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(NumerRow), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.widgetWithText(NumerRow, 'Week'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(picked, 2);
  });
}
