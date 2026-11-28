import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/news/news.dart';

void main() {
  final starts = DateTime(2026, 12, 12, 18);
  final published = DateTime(2026, 11, 27, 9);
  final item = FeedItem.fromFirestore({
    'id': 'a1',
    'kind': 'announcement',
    'title': {'en': 'Library hours', 'ru': 'Часы библиотеки', 'kk': ''},
    'body': {'en': 'Open late.'},
    'startsAt': Timestamp.fromDate(starts),
    'place': 'Block C3',
    'publishedAt': Timestamp.fromDate(published),
    'pinned': true,
    'link': 'https://example.com',
  });

  test('the language text is used when present', () {
    expect(item.localized(item.title, 'ru'), 'Часы библиотеки');
  });

  test('english stands in for an empty or missing text', () {
    expect(item.localized(item.title, 'kk'), 'Library hours');
    expect(item.localized(item.body!, 'ru'), 'Open late.');
  });

  test('json keeps every field', () {
    final copy = FeedItem.fromJson(item.toJson());

    expect(copy.id, 'a1');
    expect(copy.kind, FeedKind.announcement);
    expect(copy.title, item.title);
    expect(copy.body, {'en': 'Open late.'});
    expect(copy.startsAt, starts);
    expect(copy.place, 'Block C3');
    expect(copy.publishedAt, published);
    expect(copy.pinned, isTrue);
    expect(copy.link, 'https://example.com');
  });

  test('an item without english text is refused', () {
    expect(
      () => FeedItem.fromJson({
        'id': 'a1',
        'kind': 'event',
        'title': {'ru': 'Ярмарка'},
        'publishedAt': 0,
      }),
      throwsFormatException,
    );
  });
}
