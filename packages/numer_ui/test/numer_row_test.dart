import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app(Widget row, {double scale = 1}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: row),
    ),
  );
}

void main() {
  testWidgets('one line is 56 high and two lines 72', (tester) async {
    await tester.pumpWidget(_app(const NumerRow(title: 'Title')));
    expect(tester.getSize(find.byType(NumerRow)).height, 56);

    await tester.pumpWidget(
      _app(const NumerRow(title: 'Title', subtitle: 'Meta')),
    );
    expect(tester.getSize(find.byType(NumerRow)).height, 72);
  });

  testWidgets('a long title grows the row at large text', (tester) async {
    final title = 'A long course title ' * 8;
    await tester.pumpWidget(
      _app(NumerRow(title: title, subtitle: 'Meta'), scale: 1.3),
    );
    final row = tester.getRect(find.byType(NumerRow));

    expect(row.height, greaterThan(72));
    expect(tester.getRect(find.text(title)).bottom, lessThan(row.bottom));
    expect(tester.getRect(find.text('Meta')).bottom, lessThan(row.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long value wraps and leaves the title room', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const NumerRow(title: 'Habits', value: 'twelve of twelve done today'),
        scale: 1.3,
      ),
    );

    final value = find.text('twelve of twelve done today');
    expect(tester.getSize(value).width, lessThanOrEqualTo(128));
    expect(tester.getSize(find.text('Habits')).width, greaterThan(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pads 16 at the sides and 12 after the leading', (tester) async {
    await tester.pumpWidget(
      _app(
        const NumerRow(
          leading: Icon(Icons.school_outlined),
          title: 'Title',
          value: '3',
        ),
      ),
    );
    final row = tester.getRect(find.byType(NumerRow));
    final icon = tester.getRect(find.byType(Icon));

    expect(icon.left - row.left, 16);
    expect(tester.getRect(find.text('Title')).left - icon.right, 12);
    expect(row.right - tester.getRect(find.text('3')).right, 16);
  });

  testWidgets('shows a chevron only when asked', (tester) async {
    await tester.pumpWidget(_app(NumerRow(title: 'Title', onTap: () {})));
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.pumpWidget(
      _app(NumerRow(title: 'Title', showChevron: true, onTap: () {})),
    );
    expect(tester.getSize(find.byIcon(Icons.chevron_right)).width, 20);
  });

  testWidgets('a tap on the row calls back', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(NumerRow(title: 'Title', onTap: () => taps++)),
    );
    await tester.tap(find.byType(NumerRow));

    expect(taps, 1);
  });

  test('a value and a trailing widget cannot share a row', () {
    expect(
      () => NumerRow(title: 'Title', value: '3', trailing: const Icon(null)),
      throwsAssertionError,
    );
    expect(
      () => NumerRow(title: 'Title', showChevron: true),
      throwsAssertionError,
    );
  });
}
