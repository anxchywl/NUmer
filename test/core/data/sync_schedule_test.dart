import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/sync_schedule.dart';

void main() {
  const schedule = SyncSchedule();
  const lastPullMs = 1000000;

  bool pullAfter(Duration elapsed, {bool force = false}) {
    return schedule.shouldPull(
      nowMs: lastPullMs + elapsed.inMilliseconds,
      lastPullMs: lastPullMs,
      force: force,
    );
  }

  test('pulls when nothing was pulled yet', () {
    expect(
      schedule.shouldPull(nowMs: lastPullMs, lastPullMs: null, force: false),
      isTrue,
    );
  });

  test('skips a pull 9 minutes after the last one', () {
    expect(pullAfter(const Duration(minutes: 9)), isFalse);
  });

  test('pulls exactly 10 minutes after the last one', () {
    expect(pullAfter(const Duration(minutes: 10)), isTrue);
  });

  test('always pulls when forced', () {
    expect(pullAfter(Duration.zero, force: true), isTrue);
  });
}
