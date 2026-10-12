# P0-03: SDK constraint, Android toolchain, unused packages

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-02

## Goal
NUmer already runs Flutter 3.38.5 and Dart 3.10.4, but `pubspec.yaml` still says Dart 3.4,
the Android build tools are older than two installed plugins ask for, and three packages are
never imported. Fix those so module packages (which require Dart ^3.10) can be added later.

## Read first
- `AGENTS.md`
- `pubspec.yaml`
- `android/settings.gradle.kts`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/app/build.gradle.kts`
- `README.md` lines 1-15

## Context
- `pubspec.yaml:8-9`: `sdk: '>=3.4.0 <4.0.0'`, no `flutter:` constraint. `pubspec.lock`
  already requires dart `>=3.10.0` and flutter `>=3.38.1`.
- `android/settings.gradle.kts:23-28`: Android Gradle Plugin 8.9.1, Kotlin 2.1.0.
  `gradle-wrapper.properties:6`: Gradle 8.12. `share_plus` 12 and `package_info_plus` 9 state
  AGP 8.12.1 or newer, Gradle 8.13 or newer, Kotlin 2.2.0.
- `image_picker`, `animations` and `vector_math` have no import under `lib/`.
- `package_info_plus` also has no import today but stays: P0-13 uses it.
- `dependency_overrides: path_provider_foundation: 2.4.1` has no comment; leave it.
- Decision D-10: no Firebase major version bump, no AGP 9, no `flutter pub upgrade`.

## Steps
1. Run `flutter --version`; it must print Flutter 3.38.5 and Dart 3.10.4. Run `./scripts/verify.sh` and keep the output as the baseline.
2. In `pubspec.yaml` set `environment:` to `sdk: ^3.10.0` and `flutter: ">=3.38.1"`.
3. Remove `image_picker`, `animations` and `vector_math` from `dependencies`. Confirm first with `grep -rn "package:image_picker\|package:animations\|package:vector_math" lib test` that nothing imports them.
4. Run `flutter pub get`. The only changes allowed in `pubspec.lock` are the removal of those three packages and of packages only they needed.
5. In `android/settings.gradle.kts` set the `com.android.application` plugin version to `8.12.1` and `org.jetbrains.kotlin.android` to `2.2.0`. In `gradle-wrapper.properties` change the distribution to Gradle `8.13`, keeping the `-all` or `-bin` suffix as it is.
6. Run `flutter build apk --debug`. If Gradle reports that a newer patch version is required, use the lowest version it names within AGP 8.x, Gradle 8.x and Kotlin 2.2.x.
7. Update the Dart version in `README.md` line 8 to `>= 3.10`.
8. Run `./scripts/verify.sh`.

## Non-goals
- Do not bump any package version by hand and do not run `flutter pub upgrade`.
- Do not remove the `dependency_overrides` entry.
- Do not touch `ios/` or `macos/` project files. Do not remove permission strings from `Info.plist`; list any that `image_picker` used in the report.
- Do not move to AGP 9 or Kotlin built into AGP.

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
- [ ] `flutter pub get` exits 0 and `git diff main -- pubspec.lock` shows only removals.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `flutter build apk --debug` exits 0.
- [ ] `grep -n "sdk:" pubspec.yaml` shows `^3.10.0`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Install the debug build on one Android and one iOS device and run the smoke list in `docs/numer2/PLAN.md` (`USER_ACTIONS.md` B-2).
- On a Mac: `cd ios && pod install`, then build once for iOS.

## Deliverable
Branch `numer2/p0-03-sdk-android-toolchain`, one commit, message `chore: align sdk constraint and android toolchain` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `android/app/google-services.json` is missing, so the Android build cannot run (ask the owner to run step 6).
- `flutter pub get` changes any package other than the three removed ones.
- The Android build fails for a reason other than a tool version.
