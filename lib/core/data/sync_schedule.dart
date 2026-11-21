class SyncSchedule {
  const SyncSchedule({this.minPullInterval = const Duration(minutes: 10)});

  final Duration minPullInterval;

  bool shouldPull({
    required int nowMs,
    required int? lastPullMs,
    required bool force,
  }) {
    if (force || lastPullMs == null) return true;
    return nowMs - lastPullMs >= minPullInterval.inMilliseconds;
  }
}
