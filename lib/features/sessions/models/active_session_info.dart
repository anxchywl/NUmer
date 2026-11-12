import 'package:numer_app/app/app_state.dart';

bool hasAnyActiveSessionIn(AppState s) =>
    s.timerRunning.values.any((v) => v == true) ||
    s.stopwatchRunning.values.any((v) => v == true) ||
    s.pomodoroRunning.values.any((v) => v == true);

({String kind, String id})? activeSessionInfo(AppState s) {
  final t = s.timerRunning.entries.firstWhere(
    (e) => e.value == true,
    orElse: () => const MapEntry<String, bool>('', false),
  );
  if (t.value == true) return (kind: 'timer', id: t.key);
  final p = s.pomodoroRunning.entries.firstWhere(
    (e) => e.value == true,
    orElse: () => const MapEntry<String, bool>('', false),
  );
  if (p.value == true) return (kind: 'pomodoro', id: p.key);
  final sw = s.stopwatchRunning.entries.firstWhere(
    (e) => e.value == true,
    orElse: () => const MapEntry<String, bool>('', false),
  );
  if (sw.value == true) return (kind: 'stopwatch', id: sw.key);
  return null;
}
