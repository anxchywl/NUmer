# P0-14: Observability

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-13

## Goal
During the staged security and navigation changes the owner must see crashes in the field,
and the performance budgets of NUmer 2.0 need recorded baselines. Add crash reporting for
release builds and two measuring scripts.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-32 and O-7
- `docs/numer2/DESIGN.md` section 10
- `lib/app/bootstrap.dart`
- `lib/core/startup_metrics.dart`
- `android/settings.gradle.kts`, `android/app/build.gradle.kts`
- `pubspec.yaml` (Firebase package versions)

## Context
- The owner's answer to O-7 is in the task message. Default: yes, add crash reporting. If the
  answer is no, skip steps 1 to 3 and say so in the report.
- Firebase packages are pinned to the 4.x core line (`firebase_core` 4.5.0). Decision D-10
  forbids bumping Firebase major versions.
- `flutter run --profile --trace-startup` writes `build/start_up_info.json` with
  `timeToFirstFrameMicros`.
- Features must not import an SDK for this; they go through one wrapper in `lib/core/`.
- The comment at the top of `lib/core/startup_metrics.dart` breaks the comment rule (mixed
  case, two lines).

## Steps
1. Add `firebase_crashlytics` at the newest version that resolves with the existing `firebase_core` (use `flutter pub add firebase_crashlytics` and accept only a result that changes no other Firebase package). Apply the Crashlytics Gradle plugin in `android/settings.gradle.kts` and `android/app/build.gradle.kts` the way the google-services plugin is applied there.
2. Create `lib/core/observability/crash_reporter.dart`:
   `abstract class CrashReporter { Future<void> init(); void recordError(Object error, StackTrace stack, {bool fatal}); void setUser(String? uid); }`
   with `FirebaseCrashReporter` and `NoopCrashReporter`. `init` enables collection only when
   `kReleaseMode` is true.
3. In `lib/app/bootstrap.dart`, after Firebase is initialised: create the reporter
   (`NoopCrashReporter` when not release), set
   `FlutterError.onError` to forward to `recordError(..., fatal: true)` and then call the
   previous handler, and set `PlatformDispatcher.instance.onError` to forward and return true.
   Call `setUser(uid)` from the existing auth-state listener and `setUser(null)` on sign-out.
   Never pass an email or a name.
4. `scripts/measure_startup.sh [device id]`: runs
   `flutter run --profile --trace-startup -d <device>` (the device argument is optional), then
   prints one line: `timeToFirstFrameMs=<value>` computed from
   `build/start_up_info.json`. It exits 1 if the file is missing.
5. `scripts/measure_size.sh`: runs
   `flutter build apk --release --target-platform android-arm64 --analyze-size` and prints one
   line `apkDownloadBytes=<value>` taken from the tool's summary. It exits 1 if the build fails.
6. Create `docs/PERFORMANCE.md`: the budget table of `docs/numer2/DESIGN.md` section 10, a
   "Baseline" table with rows cold start (ms), APK download size (bytes), and columns value,
   device, date, app version, all cells `not measured`, and the two commands. One screen of text.
7. Rewrite the file comment of `lib/core/startup_metrics.dart` as one lowercase line without trailing punctuation that says why the file exists, or delete it if the code is self-explanatory.
8. Add `test/core/observability/crash_reporter_test.dart`: `NoopCrashReporter` accepts every call without throwing. Run `./scripts/verify.sh` and `bash -n scripts/measure_startup.sh scripts/measure_size.sh`.

## Non-goals
- Do not add analytics, performance monitoring or any other SDK.
- Do not record user content, emails or names in a crash report.
- Do not edit `ios/Runner.xcodeproj` by hand. If uploading iOS debug symbols needs a build phase, describe the manual Xcode step in the report as a user action.
- Do not bump any other Firebase package.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
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
- [ ] `git diff main -- pubspec.lock` shows no version change of `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_messaging`, `firebase_app_check`.
- [ ] `grep -rn "firebase_crashlytics" lib | grep -v lib/core/observability` prints nothing.
- [ ] `bash -n` passes for both scripts.
- [ ] `docs/PERFORMANCE.md` exists with both tables.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Enable Crashlytics in the Firebase console; run both scripts on the reference device and fill the baselines; add the billing alert (`docs/numer2/USER_ACTIONS.md` A-3, B-9).
- If the report lists an Xcode step for debug symbols, do it.

## Deliverable
Branch `numer2/p0-14-observability`, one commit, message `feat: add crash reporting and performance baselines` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- No `firebase_crashlytics` version resolves without changing `firebase_core`.
- The release build cannot be signed in your environment (leave `measure_size.sh` untested and say so).
- The owner answered no to O-7 and the task message does not say so explicitly.
