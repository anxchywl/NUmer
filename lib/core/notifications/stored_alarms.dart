Future<void> cancelStoredAlarms(
  Iterable<int> ids, {
  required Future<void> Function(int id) cancel,
  required Future<void> Function() clear,
}) async {
  if (ids.isEmpty) return;
  for (final id in ids) {
    await cancel(id);
  }
  await clear();
}
