import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('a saved course is read back', () async {
    final store = LastCourseStore(prefs);
    expect(store.id, isNull);

    await store.save('a');

    expect(store.id, 'a');
    expect(LastCourseStore(prefs).id, 'a');
  });

  test('it notifies once per change', () async {
    final store = LastCourseStore(prefs);
    var notified = 0;
    store.addListener(() => notified++);

    await store.save('a');
    await store.save('a');
    await store.save('b');

    expect(notified, 2);
  });
}
