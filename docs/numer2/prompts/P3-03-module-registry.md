# P3-03: Module registry, session contract, lazy mount

**Recommended model:** opus   **Effort:** medium
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-13, P3-01

## Goal
Give the host one place that knows which modules exist, whether the signed-in user sees
them, and how to open them, without creating anything of a module until it is opened. Give
modules one way to get a Firebase ID token and to recover from an expired session.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 3.3, 3.4 and 10 (binding)
- `docs/numer2/DECISIONS.md` D-05, D-23, D-24, D-34
- `lib/core/config/app_config.dart` (94 lines), `lib/core/config/app_config_service.dart`
  (59 lines)
- `lib/app/bootstrap.dart:145-195` (the provider list), `lib/app/routes.dart` (7 lines)
- `lib/features/auth/data/auth_service.dart:545-556` (`AuthController.signOut`)
- `packages/numer_ui/lib/src/components/numer_module_scaffold.dart` (from P3-01)
- `test/app/update_required_screen_test.dart` (the fake and provider pattern)

## Context
- Line numbers are from `main` at `5a6359c` plus P3-01. Find code by name if it moved.
- Module visibility is already decided by `AppConfigService.isModuleVisible(String id,
  String uid)` (`lib/core/config/app_config_service.dart:34-35`), which reads the cached
  `config/app` document and fails closed. This task does not read Firestore.
- `rootNavigatorKey` is in `lib/app/routes.dart:3` and is the `MaterialApp` navigator.
- gen-l10n has no lookup by key, so a descriptor carries functions of `AppLocalizations`
  instead of key strings (`DESIGN.md` 3.4 calls them `titleKey` and `subtitleKey`).
- No module exists yet; the registry list is empty. Phase 4 adds one entry per module.
- `core` must not import a feature (`test/boundaries/layer_boundaries_test.dart`). The
  identity code in `lib/core/identity/` takes its sign-out step as a callback; the app layer
  passes `AuthController.signOut`.
- `firebase_auth` is already a dependency (`pubspec.yaml:40`); `User.getIdToken([bool
  forceRefresh = false])` returns `Future<String?>` in 6.x.

## Steps
1. `lib/core/identity/id_token_provider.dart`:
   - `typedef IdTokenProvider = Future<String> Function({bool forceRefresh});`
   - `final class SignedOutException implements Exception { const SignedOutException(); }`
   - `IdTokenProvider firebaseIdTokenProvider(FirebaseAuth auth)`: returns a function that
     throws `SignedOutException` when `auth.currentUser` is null or `getIdToken` returns
     null, and otherwise returns `await user.getIdToken(forceRefresh)`.
2. `lib/core/identity/module_session.dart`: `class ModuleSession` with constructor
   `ModuleSession({required IdTokenProvider idToken, required Future<void> Function()
   signOut})`, the field `final IdTokenProvider idToken`, and `Future<String?>
   handleSessionExpired()`: calls `idToken(forceRefresh: true)` once and returns the token;
   on `FirebaseAuthException` or `SignedOutException` calls `signOut()` once and returns
   null. Concurrent calls share one in-flight future (keep it in a field, clear it when it
   completes), so ten modules hitting a 401 at the same moment cause one refresh.
3. `lib/app/modules/module_descriptor.dart`:
   - `enum ModuleSection { study, campus }`
   - `@immutable class ModuleDescriptor` with `const` constructor and final fields `String
     id`, `String Function(AppLocalizations l10n) title`, `String Function(AppLocalizations
     l10n) subtitle`, `IconData icon`, `ModuleSection section`, `String flagId`, and
     `NumerModuleScaffold Function(BuildContext context) builder`. The builder's return type
     is the contract that every module screen sits in `NumerModuleScaffold`.
4. `lib/app/modules/module_registry.dart`:
   - `const List<ModuleDescriptor> moduleRegistry = [];` with the comment `// order is the
     row order of the study and campus roots`.
   - `List<ModuleDescriptor> visibleModules(ModuleSection section, AppConfigService config,
     String uid, {List<ModuleDescriptor> registry = moduleRegistry})`: the registry entries
     of that section, in registry order, for which `config.isModuleVisible(d.flagId, uid)`.
5. `lib/app/modules/open_module.dart`: `Future<void> openModule(BuildContext context,
   ModuleDescriptor descriptor)`: `Navigator.of(context, rootNavigator: true).push(
   MaterialPageRoute<void>(settings: RouteSettings(name: '/module/${descriptor.id}'),
   builder: descriptor.builder))`. The builder runs only inside the route.
6. `lib/app/bootstrap.dart`: after the `AuthController` provider add
   `ProxyProvider<AuthController, ModuleSession>(update: (_, auth, previous) => previous ??
   ModuleSession(idToken: firebaseIdTokenProvider(FirebaseAuth.instance), signOut:
   auth.signOut))`. Import `firebase_auth` if the file does not already.
7. Tests:
   - `test/core/identity/module_session_test.dart` with a hand-written counting token
     function: a successful refresh returns the new token and never signs out; a refresh
     that throws `FirebaseAuthException(code: 'user-token-expired')` signs out once and
     returns null; `SignedOutException` signs out once; two concurrent
     `handleSessionExpired()` calls make exactly one `forceRefresh: true` call; a second call
     after the first completed makes a second refresh.
   - `test/app/modules/module_registry_test.dart`: an `AppConfigService` built from
     `SharedPreferences.setMockInitialValues` with a cached config (as in
     `update_required_screen_test.dart`) where module `a` is `enabled` with `allow: ['u1']`
     and module `b` is disabled; two fake descriptors in section `campus` and one in
     `study`, each with a builder that increments a counter and returns
     `NumerModuleScaffold(title: 'x', body: const SizedBox())`. Assert: `visibleModules`
     returns only `a` for `u1` and nothing for `u2`; it keeps registry order; it filters by
     section; the counters are 0 after building a `MaterialApp` whose home lists the visible
     descriptors as `NumerRow`s; tapping the row calls `openModule` and the counter becomes 1;
     the pushed route is above the home (root navigator) and its name is `/module/a`; going
     back and opening again makes it 2.
   - `test/app/modules/registry_is_empty_test.dart`: `moduleRegistry` is empty (phase 4
     changes this test when it adds the first module).
8. Run `./scripts/verify.sh`.

## Non-goals
- No real module, no tab change, no Study or Campus root (P3-05, P3-06, P3-11).
- No HTTP client, no retry policy, no caching of tokens beyond what `FirebaseAuth` does.
- Do not read or write `config/app`; `AppConfigService` already does.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`. (This task adds none.)
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`. `lib/core/identity/` imports nothing from `lib/features/` or `lib/app/`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `core/identity/` to the `core/` line and `modules/` to the `app/` line of `AGENTS.md`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The three test files above exist and pass; the concurrency case asserts exactly one refresh.
- [ ] `grep -rn "features/" lib/core/identity` prints nothing.
- [ ] `grep -rn "moduleRegistry" lib` shows the declaration and its use in `visibleModules` only.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-03-module-registry`, one commit, message `feat: add module registry and session contract` (subject line only). Do not push.
Report: files changed, test output, anything you could not verify, user actions still pending.

## Stop and ask if
- `NumerModuleScaffold` is missing or has a different constructor than P3-01 specifies.
- `AppConfigService.isModuleVisible` has changed its signature.
