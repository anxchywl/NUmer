# P0-12: Split `main.dart` into `lib/app/`

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-03, P0-09, P0-11

## Goal
`lib/main.dart` is about 1170 lines holding bootstrap, themes, the auth gate, the tab shell
and both navigation bars. The superapp shell cannot be built on that. Move each part to its
own file under `lib/app/` with no change in behaviour, and add a root navigator key.

## Read first
- `AGENTS.md`
- `lib/main.dart` (all of it)
- `lib/app/app_state.dart` lines 1-70 (imports and public surface only)
- each feature barrel `lib/features/<name>/<name>.dart`
- `test/smoke/app_boot_test.dart`
- `test/boundaries/layer_boundaries_test.dart` and `allowlist.txt`

## Context
Locate everything by class and function name; earlier tasks have shifted line numbers.
What `lib/main.dart` holds:
- `main()`: Firebase, App Check, emulator, Hive and notification setup, a theme preload and
  the helper `_parseThemeMode`;
- `NumerBootstrapApp`, whose `build` holds the `MultiProvider` (sync, groups, habits,
  `AppState`, `AuthController` and any provider added since) and a loading `MaterialApp`
  that uses the static themes `_lightTheme` and `_darkTheme`;
- `AppRoot` and `_AppRootState`: the lifecycle observer and the real `MaterialApp`, whose
  light and dark `ThemeData` are built inline from the accent colour;
- `AuthGate`;
- `_Shell` and `_ShellState`: a `PageView` over five tabs; fields and methods for the
  profile dialog, the reflection sheet and the pomodoro re-open; and two methods that build
  the navigation bars (`_buildDefaultNavigationBar` and
  `_buildIosLiquidGlassNavigationBar`), which read the selected index;
- small private widgets such as `_IosNavItem` and `_KeepAlivePage`.
Its imports reach into feature internals; these are recorded in the boundary allow-list.
The app has no navigator key and three named routes: `/shell`, `/timer`, `/alarms`.
Features may already import `lib/app/app_state.dart`; that is allowed and is not a cycle.

## Steps
1. Create these files and move the code into them. The only edits allowed are the ones listed
   here; everything else moves unchanged apart from making a moved private name public when
   another file now needs it (`_Shell` becomes `AppShell`, and so on):

   ```
   lib/main.dart                       Future<void> main() => startApp();
   lib/app/bootstrap.dart              startApp() (the current body of main and _parseThemeMode), NumerBootstrapApp with its MultiProvider
   lib/app/numer_app.dart              AppRoot and its state: lifecycle observer and MaterialApp
   lib/app/app_theme.dart              buildAppTheme, lightFallbackTheme, darkFallbackTheme
   lib/app/auth_gate.dart              AuthGate
   lib/app/routes.dart                 rootNavigatorKey, routeShell, routeTimer, routeAlarms
   lib/app/shell/app_shell.dart        AppShell, its state, _KeepAlivePage
   lib/app/shell/shell_tabs.dart       the list of tabs (label, icons, builder)
   lib/app/shell/shell_hooks.dart      mixin ShellHooks on State<AppShell>
   lib/app/shell/android_tab_bar.dart  AndroidTabBar
   lib/app/shell/ios_tab_bar.dart      IosTabBar, _IosNavItem
   ```
   - `app_theme.dart`: `ThemeData buildAppTheme(Color accent, Brightness brightness)` is the two
     inline theme blocks of `_AppRootState` merged into one function; the only change is that
     captured local values become parameters. The static themes become the public
     `lightFallbackTheme` and `darkFallbackTheme`.
   - `shell_hooks.dart`: a mixin holding, unchanged, the fields and methods of `_ShellState`
     that serve the profile dialog, the reflection sheet and the pomodoro re-open. The shell
     state mixes it in.
   - The two navigation bars become stateless widgets with the parameters `currentIndex`,
     `onTap` and `tabs`; their build code is the body of the former methods with those three
     values substituted.
   - The `MultiProvider` stays in `NumerBootstrapApp`.
2. In `lib/app/routes.dart` define `final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();` and the three route name constants with today's values. Pass the key to the `MaterialApp` in `numer_app.dart` only (not the loading one), and use the constants in its `routes` map. Nothing else uses them yet.
3. Replace every feature-internal import that came from `main.dart` with the feature's barrel. Where a barrel does not export a needed symbol, add one `export` line to that barrel. The barrel of the courses feature is `courses.dart`. In `lib/features/**` edit barrel files only.
4. Update the import in `test/smoke/app_boot_test.dart`. Remove from `test/boundaries/allowlist.txt` every line that is no longer a violation.
5. Run `flutter analyze`, `flutter test` and `./scripts/verify.sh`. Do not run the app: it would connect to the production project. Write "app run not verified" in the report.

## Non-goals
- No behaviour change of any kind: no renamed route, no changed duration, colour, padding or text, no change to the provider tree.
- Do not fix bugs you find. In particular `account.dart` navigates to a route named `/auth` that is not registered: report it, do not fix it, and do not add a constant for it.
- Do not remove the `/timer` and `/alarms` routes or their screens (P3-05 does).
- Do not touch `lib/app/app_state.dart`, and nothing under `lib/features/**` except barrel files.
- Do not introduce a router package.

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
- [ ] `wc -l lib/main.dart` prints at most 40.
- [ ] `find lib/app -name '*.dart' ! -name app_state.dart -exec wc -l {} +` shows no file above 600 lines (ignore the `total` row).
- [ ] `grep -n "navigatorKey: rootNavigatorKey" lib/app/numer_app.dart` prints one line.
- [ ] `grep -n "MultiProvider" lib/app/bootstrap.dart` prints at least one line and `grep -rn "MultiProvider" lib/app/numer_app.dart` prints nothing.
- [ ] `./scripts/verify.sh` exits 0, including the boundary test with a shorter allow-list.
- [ ] The report lists each class and top-level function that moved, with old and new file, and every barrel line added.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Run the smoke list in `docs/numer2/PLAN.md` on a device (`USER_ACTIONS.md` B-2).

## Deliverable
Branch `numer2/p0-12-split-main`, one commit, message `refactor: split main.dart into lib/app` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A method of the shell state that must move into the mixin or a bar widget reads state that cannot be passed as one of the three parameters.
- A barrel would have to export a file that imports one of the new files under `lib/app/shell/` (a cycle).
- Two barrels export the same name and an import becomes ambiguous.
- The smoke test cannot be kept passing without changing what it asserts.
