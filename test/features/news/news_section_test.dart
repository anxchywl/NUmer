import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/news/news.dart';
import 'package:numer_app/features/news/screens/announcement_screen.dart';
import 'package:numer_app/features/news/screens/event_detail_screen.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'news_fakes.dart';

const _empty = 'No news yet.';
const _error = 'Could not load news.';

Future<void> _pump(
  WidgetTester tester,
  FakeFeed feed, {
  int limit = 5,
  bool opensInModule = false,
  List<FeedItem>? offered,
}) => tester.pumpWidget(
  ChangeNotifierProvider<FeedRepository>.value(
    value: feed,
    child: MaterialApp(
      theme: NumerTheme.build(
        seed: Colors.indigo,
        brightness: Brightness.light,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => NewsStates(
              limit: limit,
              onOpen: (item) => openNewsItem(context, item, (_, item) {
                offered?.add(item);
                return opensInModule;
              }),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder get _skeletonBoxes => find.descendant(
  of: find.byType(NumerSkeleton),
  matching: find.byType(DecoratedBox),
);

void main() {
  testWidgets('before the first refresh a skeleton waits 300 ms', (
    tester,
  ) async {
    await _pump(tester, FakeFeed());
    expect(_skeletonBoxes, findsNothing);
    expect(find.text(_empty), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));

    expect(_skeletonBoxes, findsNWidgets(6));
    expect(find.text(_empty), findsNothing);
  });

  testWidgets('cached news shows first, then the refreshed news', (
    tester,
  ) async {
    final feed = FakeFeed(
      items: [announcement('Cached')],
      fetchedAt: DateTime.now(),
    );
    await _pump(tester, feed);
    expect(find.text('Cached'), findsOneWidget);
    expect(find.byType(NumerSkeleton), findsNothing);

    feed.answer([announcement('Fresh')]);
    await tester.pump();

    expect(find.text('Fresh'), findsOneWidget);
    expect(find.text('Cached'), findsNothing);
  });

  testWidgets('a failed refresh keeps the cache and says its age', (
    tester,
  ) async {
    final feed = FakeFeed(
      items: [announcement('Cached')],
      fetchedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    await _pump(tester, feed);
    expect(find.textContaining('Updated'), findsNothing);

    feed.answer([], failed: true);
    await tester.pump();

    expect(
      tester.getBottomLeft(find.text('Updated 10 min ago')).dy,
      lessThan(tester.getTopLeft(find.text('Cached')).dy),
    );
  });

  testWidgets('an empty feed offers a forced refresh', (tester) async {
    final feed = FakeFeed(fetchedAt: DateTime.now());
    await _pump(tester, feed);

    expect(find.text(_empty), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Refresh'));

    expect(feed.forced, [true]);
  });

  testWidgets('a failure without a cache offers a retry', (tester) async {
    final feed = FakeFeed(lastRefreshFailed: true);
    await _pump(tester, feed);

    expect(find.text(_error), findsOneWidget);
    expect(find.byType(NumerSkeleton), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));

    expect(feed.forced, [true]);
  });

  testWidgets('only a pinned item carries the pinned label', (tester) async {
    await _pump(
      tester,
      FakeFeed(
        items: [announcement('Top', pinned: true), announcement('Other')],
        fetchedAt: DateTime.now(),
      ),
    );

    expect(find.byType(NumerStatusLabel), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Pinned')).dy,
      lessThan(tester.getTopLeft(find.text('Other')).dy),
    );
  });

  testWidgets('no more rows than the limit, in feed order', (tester) async {
    await _pump(
      tester,
      FakeFeed(
        items: [for (var i = 0; i < 7; i++) announcement('Item $i')],
        fetchedAt: DateTime.now(),
      ),
    );

    expect(find.byType(NewsList), findsOneWidget);
    expect(find.textContaining('Item '), findsNWidgets(5));
    expect(find.text('Item 5'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Item 0')).dy,
      lessThan(tester.getTopLeft(find.text('Item 4')).dy),
    );
  });

  testWidgets('an announcement opens its text and link', (tester) async {
    await _pump(
      tester,
      FakeFeed(
        items: [
          announcement(
            'Library hours',
            body: {'en': 'Open late.'},
            link: 'https://example.com',
          ),
        ],
        fetchedAt: DateTime.now(),
      ),
    );

    await tester.tap(find.text('Library hours'));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementScreen), findsOneWidget);
    expect(find.text('Nov 27, 2026'), findsOneWidget);
    expect(find.text('Open late.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Open link'), findsOneWidget);
  });

  for (final link in ['https://[x', 'http://example.com']) {
    testWidgets('the link $link is refused with a message', (tester) async {
      await _pump(
        tester,
        FakeFeed(
          items: [announcement('Library hours', link: link)],
          fetchedAt: DateTime.now(),
        ),
      );
      await tester.tap(find.text('Library hours'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Open link'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Could not open the link.'), findsOneWidget);
    });
  }

  testWidgets('an event no module opens shows its detail', (tester) async {
    final offered = <FeedItem>[];
    await _pump(
      tester,
      FakeFeed(items: [event('Career fair')], fetchedAt: DateTime.now()),
      offered: offered,
    );

    await tester.tap(find.text('Career fair'));
    await tester.pumpAndSettle();

    expect(offered.single.id, 'Career fair');
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text('Event, Dec 12, 18:00, Block C3'), findsOneWidget);
  });

  testWidgets('an event a module opens pushes nothing', (tester) async {
    await _pump(
      tester,
      FakeFeed(items: [event('Career fair')], fetchedAt: DateTime.now()),
      opensInModule: true,
    );

    await tester.tap(find.text('Career fair'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.byType(NewsList), findsOneWidget);
  });

  testWidgets('the news screen shows up to 30 rows and pulls', (tester) async {
    final feed = FakeFeed(
      items: [for (var i = 0; i < 31; i++) announcement('Item $i')],
      fetchedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<FeedRepository>.value(
        value: feed,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ),
          home: NewsScreen(openInModule: (_, _) => false),
        ),
      ),
    );
    expect(tester.widget<NewsList>(find.byType(NewsList)).limit, 30);

    await tester.fling(find.text('Item 0'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(feed.forced, [true]);
  });
}
