import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/news/news.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_fakes.dart';

Map<String, dynamic> _stored(String id) => {
  'id': id,
  'kind': 'announcement',
  'title': {'en': id},
  'publishedAt': Timestamp.fromMillisecondsSinceEpoch(0),
  'pinned': false,
};

class _Source {
  Map<String, dynamic>? document = {
    'items': [_stored('fresh')],
  };
  FirebaseException? error;
  Completer<void>? gate;
  int reads = 0;

  Future<Map<String, dynamic>?> fetch() async {
    reads++;
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return document;
  }
}

void main() {
  late _Source source;
  late DateTime now;

  Future<FeedRepository> repository({String? cache}) async {
    SharedPreferences.setMockInitialValues({'news_feed_v1': ?cache});
    return FeedRepository(
      prefs: await SharedPreferences.getInstance(),
      fetch: source.fetch,
      now: () => now,
    );
  }

  String cacheOf(List<Object> items) =>
      jsonEncode({'fetchedAt': now.millisecondsSinceEpoch, 'items': items});

  Iterable<String> ids(FeedRepository feed) => feed.items.map((i) => i.id);

  setUp(() {
    source = _Source();
    now = DateTime(2026, 11, 28, 12);
  });

  test('a cached feed is there before any refresh', () async {
    final feed = await repository(
      cache: cacheOf([announcement('cached').toJson()]),
    );

    expect(ids(feed), ['cached']);
    expect(feed.fetchedAt, now);
    expect(source.reads, 0);
  });

  test('a refresh reads once, replaces the items and caches them', () async {
    final feed = await repository(
      cache: cacheOf([announcement('cached').toJson()]),
    );
    now = now.add(const Duration(hours: 1));

    await feed.refresh();

    expect(source.reads, 1);
    expect(ids(feed), ['fresh']);
    expect(feed.fetchedAt, now);
    final restarted = FeedRepository(
      prefs: await SharedPreferences.getInstance(),
      fetch: source.fetch,
    );
    expect(ids(restarted), ['fresh']);
    expect(restarted.fetchedAt, now);
  });

  test('an unforced refresh reads at most every 30 minutes', () async {
    final feed = await repository();
    await feed.refresh();

    now = now.add(const Duration(minutes: 29));
    await feed.refresh();
    expect(source.reads, 1);

    now = now.add(const Duration(minutes: 1));
    await feed.refresh();
    expect(source.reads, 2);
  });

  test('a forced refresh always reads', () async {
    final feed = await repository();

    await feed.refresh(force: true);
    await feed.refresh(force: true);

    expect(source.reads, 2);
  });

  test('a clock set back does not hold the feed', () async {
    final feed = await repository();
    await feed.refresh();
    now = now.subtract(const Duration(days: 1));

    await feed.refresh();

    expect(source.reads, 2);
  });

  test('a failed read keeps the items until one succeeds', () async {
    final feed = await repository(
      cache: cacheOf([announcement('cached').toJson()]),
    );
    final cachedAt = feed.fetchedAt;
    source.error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    await feed.refresh(force: true);

    expect(ids(feed), ['cached']);
    expect(feed.fetchedAt, cachedAt);
    expect(feed.lastRefreshFailed, isTrue);
    expect(feed.isLoading, isFalse);

    source.error = null;
    await feed.refresh(force: true);

    expect(feed.lastRefreshFailed, isFalse);
  });

  test('concurrent refreshes make one read and report loading', () async {
    final feed = await repository();
    source.gate = Completer<void>();
    final loading = <bool>[];
    feed.addListener(() => loading.add(feed.isLoading));

    final first = feed.refresh();
    final second = feed.refresh(force: true);
    source.gate!.complete();
    await Future.wait([first, second]);

    expect(source.reads, 1);
    expect(loading, [true, false]);
  });

  test('a missing document means no items', () async {
    final feed = await repository(
      cache: cacheOf([announcement('cached').toJson()]),
    );
    source.document = null;

    await feed.refresh(force: true);

    expect(feed.items, isEmpty);
    expect(feed.fetchedAt, now);
  });

  test('a malformed item is skipped', () async {
    final feed = await repository();
    source.document = {
      'items': [
        _stored('good'),
        _stored('no-title')..remove('title'),
        _stored('unknown')..['kind'] = 'listing',
        _stored('no-time')..['publishedAt'] = 'yesterday',
        'text',
      ],
    };

    await feed.refresh();

    expect(ids(feed), ['good']);
    expect(feed.lastRefreshFailed, isFalse);
  });

  test('a damaged cache counts as none', () async {
    final feed = await repository(cache: '{not json');

    expect(feed.items, isEmpty);
    expect(feed.fetchedAt, isNull);
  });
}
