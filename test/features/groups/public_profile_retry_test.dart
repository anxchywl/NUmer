import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/groups.dart';

class FakeListeners {
  final opened = <StreamController<int>>[];
  var cancelled = 0;

  Stream<int> open() {
    final controller = StreamController<int>(onCancel: () => cancelled++);
    opened.add(controller);
    return controller.stream;
  }
}

void main() {
  const second = Duration(seconds: 1);

  testWidgets('a denied listener is opened again and delivers', (tester) async {
    final fake = FakeListeners();
    final values = <int>[];
    final errors = <Object>[];
    final subscription = retryOnError(
      fake.open,
    ).listen(values.add, onError: errors.add);

    fake.opened.single.addError(StateError('denied'));
    await tester.pump();

    expect(errors, hasLength(1));
    expect(fake.cancelled, 1);
    expect(fake.opened, hasLength(1));

    await tester.pump(second);
    fake.opened.last.add(7);
    await tester.pump();

    expect(fake.opened, hasLength(2));
    expect(values, [7]);
    // the cancel future never completes on the fake clock
    unawaited(subscription.cancel());
    await tester.pump();
  });

  testWidgets('the delay doubles up to the cap and resets on data', (
    tester,
  ) async {
    final fake = FakeListeners();
    final subscription = retryOnError(
      fake.open,
      maxDelay: second * 4,
    ).listen((_) {}, onError: (Object _) {});

    Future<void> failThenExpectRetryAfter(Duration delay) async {
      final before = fake.opened.length;
      fake.opened.last.addError(StateError('denied'));
      await tester.pump();
      await tester.pump(delay - const Duration(milliseconds: 1));
      expect(fake.opened, hasLength(before));
      await tester.pump(const Duration(milliseconds: 1));
      expect(fake.opened, hasLength(before + 1));
    }

    await failThenExpectRetryAfter(second);
    await failThenExpectRetryAfter(second * 2);
    await failThenExpectRetryAfter(second * 4);
    await failThenExpectRetryAfter(second * 4);

    fake.opened.last.add(1);
    await tester.pump();

    await failThenExpectRetryAfter(second);
    unawaited(subscription.cancel());
    await tester.pump();
  });

  testWidgets('cancelling drops a pending retry', (tester) async {
    final fake = FakeListeners();
    final subscription = retryOnError(
      fake.open,
    ).listen((_) {}, onError: (Object _) {});

    fake.opened.single.addError(StateError('denied'));
    await tester.pump();
    unawaited(subscription.cancel());
    await tester.pump();
    await tester.pump(second * 5);

    expect(fake.opened, hasLength(1));
  });

  testWidgets('cancelling closes the open listener', (tester) async {
    final fake = FakeListeners();
    final subscription = retryOnError(fake.open).listen((_) {});

    unawaited(subscription.cancel());
    await tester.pump();

    expect(fake.cancelled, 1);
  });
}
