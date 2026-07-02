# sessions

Timer, stopwatch, pomodoro, alarms, and study-session recording.

Owns: `models/` (`StudySession`, `AlarmItem`), `screens/` (timer, alarms),
`widgets/` (reflection sheet). Public surface is `sessions.dart`.

## Native code (not in this folder)
The iOS Live Activity for a running session lives in native project paths that
Xcode/CocoaPods require and cannot be moved into `lib/`:

- `ios/SessionLiveActivityExtension/` — the widget extension (Swift).
- `ios/Shared/` — attributes shared between the app and the extension.

Treat those as owned by this feature: if you change session start/stop or the
live-activity payload here, check whether the native attributes need updating too.
