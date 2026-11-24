const _fcmResaveAfter = Duration(days: 7);

bool shouldSaveFcmToken(
  String token,
  String? savedToken,
  int? savedAtMs,
  int nowMs,
) {
  if (savedToken != token || savedAtMs == null) return true;
  if (nowMs < savedAtMs) return true;
  return nowMs - savedAtMs >= _fcmResaveAfter.inMilliseconds;
}
