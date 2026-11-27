import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/notifications/stored_alarms.dart';

Future<List<String>> _run(List<int> ids) async {
  final calls = <String>[];
  await cancelStoredAlarms(
    ids,
    cancel: (id) async => calls.add('cancel $id'),
    clear: () async => calls.add('clear'),
  );
  return calls;
}

void main() {
  test('every alarm is cancelled before the store is cleared once', () async {
    expect(await _run([1, 2, 3]), [
      'cancel 1',
      'cancel 2',
      'cancel 3',
      'clear',
    ]);
  });

  test('no stored alarms means no calls', () async {
    expect(await _run([]), isEmpty);
  });
}
