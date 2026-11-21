import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app(Widget skeleton) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: skeleton),
    ),
  );
}

final _boxes = find.descendant(
  of: find.byType(NumerSkeleton),
  matching: find.byType(DecoratedBox),
);

void main() {
  testWidgets('draws nothing for the first 300 ms', (tester) async {
    await tester.pumpWidget(_app(const NumerSkeleton()));
    await tester.pump(const Duration(milliseconds: 299));
    expect(_boxes, findsNothing);
    expect(tester.getSize(find.byType(NumerSkeleton)).height, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_boxes, findsNWidgets(6));
    expect(tester.getSize(find.byType(NumerSkeleton)).height, 3 * 72);
  });

  testWidgets('lays boxes out like a row', (tester) async {
    await tester.pumpWidget(_app(const NumerSkeleton(rows: 1)));
    await tester.pump(const Duration(milliseconds: 300));
    final title = tester.getRect(_boxes.first);
    final meta = tester.getRect(_boxes.last);
    final inner = tester.getSize(find.byType(NumerSkeleton)).width - 32;
    final decoration =
        tester.widget<DecoratedBox>(_boxes.first).decoration as BoxDecoration;
    final scheme = Theme.of(tester.element(_boxes.first)).colorScheme;

    expect(title.left, 16);
    expect(title.height, 16);
    expect(title.width, moreOrLessEquals(inner * 0.6));
    expect(meta.left, 16);
    expect(meta.height, 12);
    expect(meta.width, moreOrLessEquals(inner * 0.35));
    expect(meta.top - title.bottom, 4);
    expect(decoration.color, scheme.onSurface.withValues(alpha: 0.08));
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('one line rows are 56 high and static', (tester) async {
    await tester.pumpWidget(_app(const NumerSkeleton(rows: 2, twoLine: false)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_boxes, findsNWidgets(2));
    expect(tester.getSize(find.byType(NumerSkeleton)).height, 2 * 56);
    expect(find.bySubtype<ProgressIndicator>(), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NumerSkeleton),
        matching: find.bySubtype<AnimatedWidget>(),
      ),
      findsNothing,
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(
        of: find.byType(NumerSkeleton),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });

  testWidgets('leaving early cancels the delay', (tester) async {
    await tester.pumpWidget(_app(const NumerSkeleton()));
    await tester.pumpWidget(_app(const SizedBox()));

    expect(tester.takeException(), isNull);
  });
}
