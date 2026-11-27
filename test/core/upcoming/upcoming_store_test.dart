import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/core/upcoming/upcoming_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _start = DateTime.utc(2026, 11, 28, 12);

UpcomingItem _item(String id, Duration after, {String title = 'Practice'}) =>
    UpcomingItem(
      id: id,
      moduleId: 'clavis',
      kind: UpcomingKind.pianoBooking,
      title: title,
      startsAt: _start.add(after),
      route: '/module/clavis',
    );

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late UpcomingStore store;
  late int notified;

  Future<void> setUpStore([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    now = _start;
    notified = 0;
    store = UpcomingStore(prefs, now: () => now)..addListener(() => notified++);
  }

  List<String> ids(String uid) => [
    for (final item in store.upcoming(uid)) item.id,
  ];

  setUp(setUpStore);

  test('a put item is returned with every field', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));

    final item = store.upcoming('a').single;
    expect(item.id, '1');
    expect(item.moduleId, 'clavis');
    expect(item.kind, UpcomingKind.pianoBooking);
    expect(item.title, 'Practice');
    expect(item.startsAt, _start.add(const Duration(hours: 1)));
    expect(item.startsAt.isUtc, isTrue);
    expect(item.route, '/module/clavis');
    expect(notified, 1);
  });

  test('a local start time keeps its instant', () async {
    final local = _start.add(const Duration(hours: 1)).toLocal();
    await store.put(
      'a',
      UpcomingItem(
        id: '1',
        moduleId: 'events',
        kind: UpcomingKind.eventReminder,
        title: 'Fair',
        startsAt: local,
        route: '/module/events',
      ),
    );

    expect(store.upcoming('a').single.startsAt.isAtSameMomentAs(local), isTrue);
  });

  test('an item is returned until its start has passed', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));

    now = _start.add(const Duration(hours: 1));
    expect(ids('a'), ['1']);

    now = now.add(const Duration(milliseconds: 1));
    expect(ids('a'), isEmpty);
  });

  test('put drops past items from storage', () async {
    await store.put('a', _item('old', const Duration(hours: 1)));
    await store.put('a', _item('past', const Duration(hours: -1)));
    now = _start.add(const Duration(hours: 2));
    await store.put('a', _item('new', const Duration(hours: 3)));

    final stored = jsonDecode(prefs.getString('upcoming_v1_a')!) as List;
    expect([for (final entry in stored) (entry as Map)['id']], ['new']);
  });

  test('put replaces the item with the same id', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));
    await store.put('a', _item('1', const Duration(hours: 2), title: 'Moved'));

    expect(store.upcoming('a').single.title, 'Moved');
  });

  test('remove removes one item', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));
    await store.put('a', _item('2', const Duration(hours: 2)));
    await store.remove('a', '1');

    expect(ids('a'), ['2']);
    expect(notified, 3);
  });

  test('items come soonest first', () async {
    await store.put('a', _item('later', const Duration(days: 2)));
    await store.put('a', _item('soon', const Duration(hours: 1)));
    await store.put('a', _item('middle', const Duration(days: 1)));

    expect(ids('a'), ['soon', 'middle', 'later']);
  });

  test('one user never sees the items of another', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));

    expect(ids('b'), isEmpty);
  });

  test('clear removes only that user', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));
    await store.put('b', _item('2', const Duration(hours: 1)));
    await store.clear('a');

    expect(prefs.containsKey('upcoming_v1_a'), isFalse);
    expect(ids('b'), ['2']);
    expect(notified, 3);
  });

  test('a stored list survives a new store', () async {
    await store.put('a', _item('1', const Duration(hours: 1)));
    store = UpcomingStore(prefs, now: () => now);

    expect(ids('a'), ['1']);
  });

  test('a malformed stored entry is skipped', () async {
    final good = _item('good', const Duration(hours: 1)).toJson();
    await setUpStore({
      'upcoming_v1_a': jsonEncode([
        {...good, 'id': 'unknown', 'kind': 'lecture'},
        {...good, 'id': 'missing'}..remove('route'),
        {...good, 'id': 'mistyped', 'startsAt': 'soon'},
        'text',
        good,
      ]),
    });

    expect(ids('a'), ['good']);
  });
}
