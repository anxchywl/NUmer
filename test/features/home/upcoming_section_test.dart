import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/core/upcoming/upcoming_store.dart';
import 'package:numer_app/features/home/upcoming_section.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// far enough ahead that nothing expires while the tests run
final _year = DateTime.now().year + 1;

UpcomingItem _item(
  String title,
  DateTime startsAt, {
  UpcomingKind kind = UpcomingKind.pianoBooking,
}) => UpcomingItem(
  id: title,
  moduleId: 'clavis',
  kind: kind,
  title: title,
  startsAt: startsAt,
  route: '/module/clavis',
);

Future<UpcomingStore> _pump(
  WidgetTester tester, {
  List<UpcomingItem> items = const [],
  Locale locale = const Locale('en'),
  bool Function(BuildContext, UpcomingItem) openInModule = openNoUpcomingItem,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = UpcomingStore(await SharedPreferences.getInstance());
  for (final item in items) {
    await store.put('u1', item);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<UpcomingStore>.value(
      value: store,
      child: MaterialApp(
        theme: NumerTheme.build(
          seed: Colors.indigo,
          brightness: Brightness.light,
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UpcomingSection(uid: 'u1', openInModule: openInModule),
        ),
      ),
    ),
  );
  return store;
}

List<NumerRow> _rows(WidgetTester tester) =>
    tester.widgetList<NumerRow>(find.byType(NumerRow)).toList();

Future<String> _when(
  WidgetTester tester,
  Locale locale,
  DateTime startsAt,
  DateTime now,
) async {
  await _pump(tester, locale: locale);
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(UpcomingSection));
  return upcomingWhen(AppLocalizations.of(context)!, startsAt, now);
}

void main() {
  testWidgets('an empty store renders nothing', (tester) async {
    await _pump(tester);

    expect(find.byType(NumerSection), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(tester.getSize(find.byType(UpcomingSection)).height, 0);
  });

  testWidgets('three of five items show, soonest first', (tester) async {
    await _pump(
      tester,
      items: [
        _item('e', DateTime(_year, 5, 5)),
        _item('b', DateTime(_year, 2, 2), kind: UpcomingKind.eventReminder),
        _item('d', DateTime(_year, 4, 4)),
        _item('a', DateTime(_year, 1, 1)),
        _item('c', DateTime(_year, 3, 3)),
      ],
    );

    expect(find.text('Upcoming'), findsOneWidget);
    expect(_rows(tester).map((row) => row.title), ['a', 'b', 'c']);
    expect(_rows(tester).map((row) => (row.leading! as Icon).icon), [
      Icons.piano_outlined,
      Icons.event_outlined,
      Icons.piano_outlined,
    ]);
  });

  testWidgets('a put item appears without a new screen', (tester) async {
    final store = await _pump(tester);

    await store.put('u1', _item('Fair', DateTime(_year, 3, 12, 18)));
    await tester.pump();

    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('Mar 12, 18:00'), findsOneWidget);
  });

  testWidgets('without a module a row does not navigate', (tester) async {
    await _pump(tester, items: [_item('a', DateTime(_year))]);

    expect(_rows(tester).single.showChevron, isFalse);
    expect(_rows(tester).single.onTap, isNull);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('with a module a row opens its item', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      items: [_item('a', DateTime(_year))],
      openInModule: (_, item) {
        opened.add(item.id);
        return true;
      },
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('a'));
    expect(opened, ['a']);
  });

  final now = DateTime(2026, 12, 31, 12);
  for (final (language, startsAt, text) in [
    ('en', DateTime(2026, 12, 31, 18), 'Today, 18:00'),
    ('en', DateTime(2027, 1, 1, 9, 30), 'Tomorrow, 09:30'),
    ('en', DateTime(2027, 1, 2, 9, 30), 'Jan 2, 09:30'),
    ('ru', DateTime(2026, 12, 31, 18), 'Сегодня, 18:00'),
    ('ru', DateTime(2027, 1, 1, 9, 30), 'Завтра, 09:30'),
    ('kk', DateTime(2026, 12, 31, 18), 'Бүгін, 18:00'),
  ]) {
    testWidgets('$language reads $text', (tester) async {
      expect(await _when(tester, Locale(language), startsAt, now), text);
    });
  }

  testWidgets('a utc start is read in local time', (tester) async {
    final startsAt = DateTime(2026, 12, 31, 18).toUtc();

    expect(
      await _when(tester, const Locale('en'), startsAt, now),
      'Today, 18:00',
    );
  });
}
