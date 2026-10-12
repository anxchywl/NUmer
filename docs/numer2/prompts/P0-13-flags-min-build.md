# P0-13: Remote flags and the minimum-build gate

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-12, P0-06

## Goal
Modules will be switched on per user without a release, and one day an old version must be
told to update. Add one remotely read configuration document with safe compiled-in defaults,
and an update-required screen driven by it.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-23
- `docs/numer2/DESIGN.md` sections 2, 5.4 and 8
- `lib/app/bootstrap.dart`, `lib/app/numer_app.dart`, `lib/app/auth_gate.dart`
- `lib/core/data/sync_service.dart`: the constructor and `_sendHeartbeat`
- `README.md` (store links)

## Context
- The document is `config/app` in Firestore. Rules already allow a signed-in user to `get`
  it and nobody to write it. Shape:
  `{minSupportedBuild: int, modules: {<id>: {enabled: bool, rollout: int 0..100, allow: [uid], minBuild: int}}}`.
- A module is visible when `enabled` is true, the app build is at least `minBuild`, and the
  uid is in `allow` or `stableHash(uid) % 100 < rollout`.
- Parsing is per field: a `minSupportedBuild` that is not an int counts as 0 and does not
  affect modules; a malformed module entry is dropped and the others are kept; `rollout` is
  clamped to 0..100; `allow` keeps only strings. A missing document means no module is
  visible and `minSupportedBuild` is 0.
- Startup must not wait for the network: use the cached copy at once and refresh later.
- `package_info_plus` is already a dependency. `PackageInfo.buildNumber` is a string; use
  `int.tryParse(buildNumber) ?? 0`.
- `SyncService` is created in a provider as `SyncService()`; its constructor has only
  optional named parameters. `_sendHeartbeat` writes
  `{'activeSession': {deviceId, updatedAt}}` to `users/{uid}` with merge.
- The `numer_ui` package does not exist yet, so the update screen uses Material widgets
  with the values of `DESIGN.md` written inline for this one screen.
- The two store URLs in `README.md` are public links and may be written into the code.

## Steps
1. `lib/core/config/app_config.dart`: immutable `ModuleFlag {enabled, rollout, allow, minBuild}`
   and `AppConfig {minSupportedBuild, modules}` with `AppConfig.defaults` (0 and an empty map),
   `AppConfig.fromMap(Map<String, dynamic>?)` following the per-field rules in Context (it never
   throws), `toJson`/`fromJson` for caching, and
   `bool isModuleVisible(String id, {required String uid, required int build})`.
   Add the top-level pure function `int stableHash(String s)`: 32-bit FNV-1a over the UTF-8
   bytes (offset basis 2166136261, prime 16777619, masked with `0xFFFFFFFF` after each
   multiplication).
2. `lib/core/config/app_config_service.dart`: a `ChangeNotifier` constructed with a
   `SharedPreferences` instance, a `Future<Map<String, dynamic>?> Function() fetch`, and the
   build number.
   - the constructor loads the cached JSON (key `app_config_v1`) synchronously into `config`;
   - `Future<void> refresh({bool force = false})` calls `fetch`; on success it parses, stores,
     and notifies when the value changed; when `fetch` throws a `FirebaseException` (offline,
     permission denied, unavailable) it keeps the current value. It catches nothing else;
   - the time of the last successful refresh is kept in memory only. Without `force`, `refresh`
     does nothing when that time is less than 6 hours ago;
   - getters `bool get updateRequired` (`build < config.minSupportedBuild`) and
     `bool isModuleVisible(String id, String uid)`.
3. Wire it in `lib/app/`:
   - read the build number in `bootstrap.dart` alongside the existing startup futures;
   - provide `AppConfigService` in the existing `MultiProvider`, with a `fetch` that reads
     `config/app` and returns `data()`;
   - in the state of the root widget in `numer_app.dart` (it already observes the app
     lifecycle), call `refresh()` in three places: in a post-frame callback when a user is
     already signed in, whenever `AuthController`'s current user changes from null to
     non-null, and on `AppLifecycleState.resumed`. Never await it during startup.
4. `lib/app/update_required_screen.dart`: `Scaffold` without an app bar; `SafeArea`;
   `SingleChildScrollView` with 16 side padding; a column aligned to the start that begins 32
   below the top: the title in `textTheme.titleLarge`, bold, `colorScheme.primary`; 8; the body
   in `textTheme.bodyMedium`, `colorScheme.onSurfaceVariant`; 24; a full-width `FilledButton`,
   48 high, radius 12. No icon and no illustration. The button opens the store page with
   `launchUrl(uri, mode: LaunchMode.externalApplication)`: the App Store URL on iOS and macOS,
   the Google Play URL otherwise; both are constants in that file copied from `README.md`. A
   `false` result is ignored.
   `AuthGate` shows this screen before any other branch when `updateRequired` is true.
   Strings:
   - `updateRequiredTitle`: EN `Update NUmer` / RU `Обновите NUmer` / KK `NUmer қолданбасын жаңартыңыз`
   - `updateRequiredBody`: EN `This version is no longer supported. Install the latest version to continue.` / RU `Эта версия больше не поддерживается. Установите последнюю версию, чтобы продолжить.` / KK `Бұл нұсқаға енді қолдау көрсетілмейді. Жалғастыру үшін соңғы нұсқаны орнатыңыз.`
   - `updateRequiredAction`: EN `Update` / RU `Обновить` / KK `Жаңарту`
5. `SyncService`: add an optional named constructor parameter `int? appBuild`, passed where the provider creates the service. In `_sendHeartbeat`, when it is not null, add `'appBuild': appBuild` as a top-level key of the same `users/{uid}` write, next to `activeSession`. This adds no extra write.
6. Tests:
   - `test/core/config/app_config_test.dart`: null map gives defaults; a module with
     `enabled: false` is not visible; `allow` makes it visible at `rollout: 0`; `rollout: 100`
     makes it visible to everyone; `minBuild` above the build hides it; one test per parsing
     rule in Context; `stableHash('abc')` equals 440920331.
   - `test/core/config/app_config_service_test.dart` (with `SharedPreferences.setMockInitialValues`
     and a fake `fetch`): starts from the cache without calling `fetch`; a `fetch` that throws
     `FirebaseException` keeps the value; a second `refresh` within 6 hours does not call
     `fetch`, and `force: true` does; `updateRequired` flips when `minSupportedBuild` exceeds
     the build.
   - `test/app/update_required_screen_test.dart`: the screen pumped directly shows the three
     strings and holds at text scale 1.3 without overflow.
7. Run `./scripts/verify.sh`.

## Non-goals
- Do not add Firebase Remote Config or any package.
- Do not gate any existing feature behind a flag in this task.
- Do not write `config/app` from the app.
- Do not block startup on the refresh.
- Do not add a runtime switch to force the update screen; screenshots come from the screen pumped in a widget test.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The three test files pass.
- [ ] `grep -rn "await.*refresh(" lib/app` prints nothing.
- [ ] `grep -c "updateRequired" lib/l10n/app_en.arb lib/l10n/app_ru.arb lib/l10n/app_kk.arb` prints 3 or more for each file.
- [ ] `grep -n "appBuild" lib/core/data/sync_service.dart` shows the constructor parameter and the heartbeat key.
- [ ] Screenshots attached to the report: each new or changed screen in light and dark mode, in EN and RU (add KK where labels are long), plus one at text scale 1.3. For screens that load data: loading, empty and error states. If you cannot run the app on a device or simulator, produce the images from a widget test that pumps the screen and writes them with `matchesGoldenFile` (run with `--update-goldens`), attach them, and do not commit them. Never fabricate an image; if none can be produced, say so.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Create the document `config/app` with `minSupportedBuild: 0` and `modules: {}` (`docs/numer2/USER_ACTIONS.md` B-8).

## Deliverable
Branch `numer2/p0-13-flags-min-build`, one commit, message `feat: add remote module flags and minimum build gate` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, screenshots, anything you could not verify, and user actions still pending.

## Stop and ask if
- `README.md` has no store links for both platforms.
- The root widget's state cannot observe `AuthController` without changing the provider tree.
