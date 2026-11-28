# P0-09: Sync: push on change, pull on resume

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-02

## Goal
Every local change (18 call sites) runs a full sync: a push and then an incremental pull that
costs at least 8 document reads even when nothing changed. Make a local change push only.
Pull when the app resumes and the last pull is more than 10 minutes old, and whenever the
user asks for a sync.

## Read first
- `AGENTS.md` (offline-first contract)
- `lib/core/data/sync_service.dart`: `start`, `stop`, `syncNow`, `pushDirty`, `pullSince` (lines 60-200 and 360-400) and the field `lastPull`
- `lib/app/app_state.dart` lines 298-350 (`bindSyncService`, `triggerSync`, `_triggerSync`) and line 604 (`setAllowNudges`)
- `lib/main.dart` lines 275-300 (the resume handler)
- `lib/features/account/screens/account.dart` lines 110-120, 255-290; `lib/features/habits/screens/archived_habits_screen.dart` line 49; `lib/features/auth/screens/verification_status.dart` line 117

## Context
- `SyncService.syncNow({bool full})` (`sync_service.dart:158-187`) runs `pushDirty()` and then
  `pullSince(...)` inside a try/catch that sets `lastError` and the offline status. It has no
  minimum interval. `pushDirty` has its own re-entrancy guard and rethrows errors.
- `SyncService` already has `DateTime? lastPull`, set at the end of a successful
  `pullSince` and cleared in `stop()`.
- `AppState.triggerSync({bool full})` (`app_state.dart:341-345`) calls `syncNow`.
  `AppState._triggerSync()` (`:347-349`) calls `triggerSync()` unawaited and is itself called
  from 18 places after course edits, timer start and stop, profile edits and note saves.
- Other callers of `syncNow`: the resume handler in `lib/main.dart` (`syncNow(full: false)`);
  `account.dart:283`, the manual button (`syncNow(full: true)`);
  `archived_habits_screen.dart:49`, a manual refresh through
  `appState.triggerSync(full: true)`; `account.dart:117` and `:260` and
  `verification_status.dart:117`, which push before signing out or deleting;
  `app_state.dart:604` (`setAllowNudges`), which wants its change pushed at once;
  `app_state.dart:305` (`onBeforeStop`); and calls inside `sync_service.dart` itself.
- After a pull, `_handleRemoteRefresh` reloads `AppState`. That must keep working.
- Consequence to accept: a change made on another device appears after the next resume that
  is more than 10 minutes after the last pull, or after a manual sync. There is no
  background timer.

## Steps
1. Create `lib/core/data/sync_schedule.dart` with a pure class:
   `class SyncSchedule { const SyncSchedule({this.minPullInterval = const Duration(minutes: 10)});`
   `bool shouldPull({required int nowMs, required int? lastPullMs, required bool force}); }`
   It returns true when `force` is true, when `lastPullMs` is null, or when
   `nowMs - lastPullMs >= minPullInterval.inMilliseconds`.
2. In `SyncService`:
   - hold `final SyncSchedule _schedule = const SyncSchedule();`
   - give `syncNow` a named parameter `bool force = false`. After the push, pull only when
     `_schedule.shouldPull(nowMs: now, lastPullMs: lastPull?.millisecondsSinceEpoch, force:
     force || full)` is true. Reuse the existing `lastPull` field; add no second field.
   - add `Future<void> pushNow()`: the push half of `syncNow` with the same guards and the same
     try/catch/finally (set `lastError`, set the offline status, never throw to the caller). If
     sharing that code would duplicate more than 15 lines, extract a private
     `_runGuarded(Future<void> Function() body)` used by both.
   - if `pushNow` is called while a sync is already running, set a private flag
     `_pushPending`; in the `finally` of the running sync, if the flag is set, clear it and run
     one more push.
   Do not change `pushDirty`, `pullSince`, `start` or `stop`.
3. In `AppState`: `_triggerSync` calls `_syncService?.pushNow()` (unawaited, as it does today with `triggerSync`). `triggerSync({bool full = false})` stays a pull-capable method and keeps calling `syncNow(full: full)`. In `setAllowNudges` (line 604) replace the `syncNow` call with `pushNow()`.
4. In `account.dart:117` and `:260` and `verification_status.dart:117` (the pushes before sign-out or deletion) call `pushNow()` instead of `syncNow()`. Leave `account.dart:283`, `archived_habits_screen.dart:49`, the resume handler and `onBeforeStop` unchanged: `full: true` now implies a forced pull, and the resume handler is throttled by the schedule.
5. Add `test/core/data/sync_schedule_test.dart`: a null last pull pulls; 9 minutes does not; exactly 10 minutes does; `force` always pulls. Do not attempt a test of `SyncService` itself: its state is private and set only by `start()`, which needs Firebase and Hive. Say so in the report.
6. Run `./scripts/verify.sh`.

## Non-goals
- Do not change what is pushed or pulled, the cursor logic, conflict handling or batching.
- Do not change the habit-history pull or any query.
- Do not add a timer that pulls in the background.
- Do not touch `Storage`, Hive adapters or `lib/features/**` beyond the three call sites named in step 4.
- No new user-facing string is expected.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `flutter test test/core/data/sync_schedule_test.dart` passes with the four cases.
- [ ] `sed -n '/void _triggerSync/,/^  }/p' lib/app/app_state.dart` shows a call to `pushNow()` and no call to `triggerSync` or `syncNow`.
- [ ] `grep -rn "syncNow(" lib` lists only: the definition and internal calls in `sync_service.dart`, `AppState.triggerSync`, `app_state.dart` `onBeforeStop`, the resume handler in `lib/main.dart`, and `account.dart:283`. Paste the output in the report.
- [ ] `grep -rn "pushNow()" lib` lists `_triggerSync`, `setAllowNudges`, the two sites in `account.dart`, `verification_status.dart` and the definition.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Two-device check (`docs/numer2/USER_ACTIONS.md` B-7).

## Deliverable
Branch `numer2/p0-09-sync-push-pull`, one commit, message `perf: push on change and throttle pulls` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A feature relies on the pull that used to follow every change (for example it reads a server-computed value right after a write).
- `_handleRemoteRefresh` is triggered by something other than a completed pull.
- The line numbers above do not match; locate by method name, and stop only if a named method does not exist.
