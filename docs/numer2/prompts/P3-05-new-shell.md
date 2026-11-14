# P3-05: New shell: tabs, header avatar, Settings screen, About

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-03, P3-04

## Goal
Switch the tab bar to Home, Habits, Study, Groups and (only when a campus module is visible)
Campus, and move Settings behind the user's avatar on every tab root, as the owner confirmed
(O-1, D-20). Remove the dead timer and alarm screens and fix sign-out navigation.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 3, 4.4, 4.5, 5.1 to 5.3, 7.2, 8 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-20, D-34, D-35, D-36
- `lib/app/shell/shell_tabs.dart` (63 lines), `lib/app/shell/app_shell.dart` (128 lines),
  `lib/app/shell/ios_tab_bar.dart`, `lib/app/shell/android_tab_bar.dart`
- `lib/app/numer_app.dart` (126 lines), `lib/app/routes.dart`, `lib/app/auth_gate.dart:17-19,186`
- `lib/features/account/screens/account.dart` (1331 lines; read 1-300 and 400-890)
- `lib/features/account/widgets/universal_avatar.dart`, `lib/features/account/account.dart`
- `lib/features/habits/screens/habits_screen.dart:180-245, 662-720`
- `lib/features/groups/screens/groups_screen.dart:80-145`
- `lib/features/home/home_screen.dart` (after P3-04)
- `lib/app/modules/` and `lib/core/modules/` (after P3-03), `lib/core/config/app_config_service.dart`
- `lib/features/sessions/sessions.dart`, `lib/features/sessions/screens/timer.dart`,
  `lib/features/sessions/screens/alarms.dart`
- `lib/app/app_state.dart:97, 397, 425, 1112-1146, 2451`, `lib/core/data/storage.dart:604-623`,
  `lib/core/notifications/notifications.dart:245-250`
- `test/boundaries/allowlist.txt`

## Context
- Line numbers are from `main` at `5a6359c` plus P3-01, P3-03, P3-04. Find code by name if
  it moved. P1-07 may have changed the delete-account part of `account.dart`; keep whatever
  is there.
- Today the tabs are Home, Habits, Statistics, Groups, Account (`shell_tabs.dart:30-62`).
  `AppShell` builds them every frame, keeps each page alive in a `PageView`, and feeds the
  same list to `IosTabBar` and `AndroidTabBar`.
- New tab roots and their owners (D-34): Study is `lib/features/study/study_screen.dart`
  (new feature), Campus is `lib/features/campus/campus_screen.dart` (new feature).
  Until P3-06, the Study root holds two rows, Statistics and History, that push the
  existing screens (D-35). `StatsScreen` has its own `SliverAppBar`, which shows a back
  arrow when pushed; it needs no change. `HistoryScreen()` takes only optional filters.
- Settings: `AccountScreen` becomes `SettingsScreen`, pushed on the root navigator, so it
  covers the tab bar. The theme switch calls `widget.onThemeChange?.call(mode)`
  (`account.dart:433`); that callback only calls `AppState.setThemeMode` (`numer_app.dart:84-87`)
  and is threaded through `AuthGate`, `AppShell` and `buildShellTabs` for this one use.
  Settings calls `context.read<AppState>().setThemeMode(mode)` directly, and the callback
  chain is removed.
- The header avatar is drawn the way Settings draws it (`account.dart:228-234`):
  `UniversalAvatar(name: displayName, avatarIndex: state.profileAvatarIndex,
  avatarColorValue: state.profileAvatarColorValue, alwaysShowSilhouette: true, size: 32)`,
  where `displayName` is `state.profileName` when not blank, else an empty string.
- Tab roots live in features, which cannot import `lib/app/` (except `app_state.dart`). The
  header that knows the avatar and opens Settings therefore lives in the `account` feature,
  which owns Settings: `ShellHeader`, exported from `account.dart`.
- Sign-out today ends with `navigator.pushReplacementNamed('/auth')` (`account.dart:264`).
  No `/auth` route exists. `AuthGate` is `MaterialApp.home` and shows the sign-in screen by
  itself when the user is null, so sign-out only has to return to the first route.
- Alarms (D-36): `/timer` and `/alarms` are registered (`numer_app.dart:119-120`) and nothing
  navigates to them, in any commit of this repository. Stored alarms (`alarms_v1`,
  `storage.dart:604-623`) can only exist from an app version before this repository, and
  such an alarm's local notification would keep firing with no screen to remove it. The
  app therefore cancels and clears stored alarms once at load, and the alarm code goes.
- Privacy URL and support address: the owner provides both (`USER_ACTIONS.md` E-2) in the
  message that starts this task. They are public, not secrets.
- New strings (`DESIGN.md` 3.1 for the tab labels):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `navStudy` | Study | Учёба | Оқу |
  | `navCampus` | Campus | Кампус | Кампус |
  | `settingsTooltip` | Settings | Настройки | Баптаулар |
  | `aboutTitle` | About | О приложении | Қолданба туралы |
  | `privacyPolicy` | Privacy policy | Политика конфиденциальности | Құпиялық саясаты |
  | `contactSupport` | Contact support | Написать в поддержку | Қолдау қызметіне жазу |
  | `appVersion` | Version | Версия | Нұсқа |
  | `linkOpenFailed` | Could not open the link. | Не удалось открыть ссылку. | Сілтемені ашу мүмкін болмады. |

  Reuse `home`, `habitsNavLabel`, `groups`, `statistics`, `history`, `settingsTitle`.

## Steps
1. `lib/features/account/widgets/shell_header.dart`: `ShellHeader({required Widget title,
   List<Widget> actions = const []})` returning `NumerShellHeader(title: title, actions:
   actions, avatar: <the avatar of the Context>, avatarTooltip: l10n.settingsTooltip,
   onAvatarPressed: () => openSettings(context))`. It watches `AppState` for the avatar.
   In the same file, `Future<void> openSettings(BuildContext context)` pushes
   `MaterialPageRoute(settings: const RouteSettings(name: '/settings'), builder: (_) =>
   const SettingsScreen())` with `Navigator.of(context, rootNavigator: true)`. Export the
   file from `lib/features/account/account.dart`.
2. Settings screen:
   - `git mv lib/features/account/screens/account.dart
     lib/features/account/screens/settings_screen.dart`; rename `AccountScreen` to
     `SettingsScreen` and its state class; remove the `onThemeChange` field and
     constructor parameter; at the theme switch call `await
     context.read<AppState>().setThemeMode(mode)`. Update the barrel export.
   - The bottom clearance: the screen is pushed above the tab bar, so `_bottomScrollClearance`
     returns `MediaQuery.of(context).padding.bottom + NumerSpace.xl` on both platforms;
     delete `_iosBottomNavClearance` and `_isIos` if nothing else uses them.
   - Sign-out (around line 253): capture `final navigator = Navigator.of(context,
     rootNavigator: true);` before the first `await`, and replace
     `navigator.pushReplacementNamed('/auth')` with `navigator.popUntil((route) =>
     route.isFirst)`. Keep the rest of the sequence.
   - About section: insert, after the export-to-calendar card and before the divider above
     "Delete account", `NumerSection(title: l10n.aboutTitle, child: NumerBlock(children:
     [...]))` with three `NumerRow`s: `privacyPolicy` (`showChevron: true`, opens the
     privacy URL with `launchUrl(uri, mode: LaunchMode.externalApplication)`),
     `contactSupport` (`showChevron: true`, `launchUrl(Uri(scheme: 'mailto', path:
     <support address>))`), `appVersion` (`value: '${info.version} (${info.buildNumber})'`
     from `PackageInfo.fromPlatform()` read once in `initState`; the row shows no value
     until it resolves). When `launchUrl` returns false, `showAppMessage(context,
     l10n.linkOpenFailed, isError: true)`. The Settings list already sits in a
     `SliverPadding(all: 16)`, and `NumerSection` and `NumerBlock` would add a second 16 on
     the left. So build the section from its parts: the title in `context.text.sectionTitle`,
     `SizedBox(height: NumerSpace.sm)`, then a `Material(color:
     scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(NumerRadius.lg),
     clipBehavior: Clip.antiAlias)` holding the three `NumerRow`s with `Divider(height: 1,
     thickness: 1, indent: NumerSpace.lg, color: scheme.outlineVariant)` between them, then
     `SizedBox(height: NumerSpace.xl)`. It lines up with the cards above it.
   - The two constants go at the top of `settings_screen.dart`: `const _privacyPolicyUrl =
     '<from the task message>';` and `const _supportEmail = '<from the task message>';`.
3. `lib/features/study/study.dart` (barrel) and `lib/features/study/study_screen.dart`:
   `StudyScreen`, a `Scaffold` with a `CustomScrollView`: `ShellHeader(title: Text(
   l10n.navStudy, style: context.text.screenTitle))`, then `SliverToBoxAdapter(child:
   NumerBlock(children: [NumerRow(title: l10n.statistics, showChevron: true, onTap: push
   StatsScreen), NumerRow(title: l10n.history, showChevron: true, onTap: push
   HistoryScreen())]))` with `NumerSpace.sm` above the block, then a bottom
   `SliverPadding` equal to the iOS tab bar clearance used by `StatsScreen` today
   (`stats.dart:319-327`). Push with `Navigator.of(context, rootNavigator: true)`.
4. `lib/features/campus/campus.dart` (barrel) and `lib/features/campus/campus_screen.dart`:
   `CampusScreen({required List<ModuleDescriptor> modules, required void
   Function(ModuleDescriptor) onOpen})`, a `Scaffold` with `ShellHeader(title: Text(
   l10n.navCampus, ...))` and one `NumerBlock` with a `NumerRow(leading: Icon(d.icon),
   title: d.title(l10n), subtitle: d.subtitle(l10n), showChevron: true, onTap: () =>
   onOpen(d))` per module. The screen takes the list and the callback because a feature
   cannot import `lib/app/modules/`; `shell_tabs.dart` passes `visibleModules(...)` and
   `(d) => openModule(context, d)`. `ModuleDescriptor` comes from
   `lib/core/modules/module_descriptor.dart` (P3-03), which features may import.
5. `lib/app/shell/shell_tabs.dart`: `buildShellTabs(BuildContext context, {List<ModuleDescriptor>
   registry = moduleRegistry})` returns, in order: Home (`l10n.home`, `home_outlined` /
   `home`, `HomeScreen`), Habits (`l10n.habitsNavLabel`, `check_circle_outline` /
   `check_circle`, `HabitsScreen`), Study (`l10n.navStudy`, `school_outlined` / `school`,
   `StudyScreen`), Groups (`l10n.groups`, `group_outlined` / `group`, `GroupsScreen`), and,
   only when `visibleModules(ModuleSection.campus, config, uid, registry: registry)` is not
   empty, Campus (`l10n.navCampus`, `apartment_outlined` / `apartment`, `CampusScreen`).
   `config` is `context.watch<AppConfigService>()` and `uid` is
   `context.watch<AuthController>().currentUser?.uid ?? ''`. Remove the `onThemeChange`
   parameter. Keep the connections comment.
6. `lib/app/shell/app_shell.dart`: remove `onThemeChange`; add `final List<ModuleDescriptor>
   registry` (default `moduleRegistry`) passed to `buildShellTabs`. When the tab count
   shrinks below `_index + 1` (Campus disappears while selected), set `_index` to 0 and
   `jumpToPage(0)` after the frame. `IosTabBar` and `AndroidTabBar` keep reading the list;
   do not change either bar's look.
7. `lib/app/auth_gate.dart` and `lib/app/numer_app.dart`: remove `onThemeChange` and
   `setTheme`. In `numer_app.dart` remove the `routeTimer` and `routeAlarms` routes and the
   `sessions.dart` import if unused; in `routes.dart` remove the two constants.
8. Tab root headers. Each becomes `ShellHeader`:
   - `HomeScreen` (`home_screen.dart`): `ShellHeader(title: const StreakTitle(), actions:
     [const SyncStatusChip()])` in place of its `SliverAppBar`. The chip stays until P3-07.
   - `HabitsScreen` (`habits_screen.dart:196-240`): `ShellHeader(title: Text(
     l10n.habitsNavLabel, style: context.text.screenTitle), actions: [the archive and
     calendar `IconButton`s, each given a tooltip: reuse an existing ARB key if one names
     the screen, else add `archivedHabitsTooltip` "Archived habits" / "Архив привычек" /
     "Мұрағаттағы әдеттер" and `habitsCalendarTooltip` "Calendar" / "Календарь" /
     "Күнтізбе"])`. Directly below it, `SliverToBoxAdapter(Padding(horizontal:
     NumerSpace.lg, vertical: NumerSpace.sm, child: SegmentedButton<int>(segments: [0:
     l10n.habitsTabProgress, 1: l10n.habitsTabList], selected: {_selectedTabIndex},
     showSelectedIcon: false, onSelectionChanged: <the body of the old `_buildTabItem`
     onTap>, plus HapticFeedback.selectionClick())))`. Delete `_buildTabItem`.
   - `GroupsScreen` (`groups_screen.dart:125-144`): `ShellHeader(title: Text(<same
     string>, style: context.text.screenTitle), actions: [<the existing TipIcon when
     hasMemberships>])`. Leave the signed-out `SliverAppBar` at line 88 as it is.
   - `StudyScreen` and `CampusScreen` already use it.
9. Alarms (D-36):
   - Delete `lib/features/sessions/screens/timer.dart` and `alarms.dart` and their exports
     from `sessions.dart`. Keep `models/alarm_item.dart` (storage parses it).
   - `lib/core/notifications/stored_alarms.dart`: `Future<void>
     cancelStoredAlarms(Iterable<int> ids, {required Future<void> Function(int id) cancel,
     required Future<void> Function() clear})`: cancels each id, then calls `clear` once;
     does nothing when `ids` is empty.
   - `AppState`: delete the `alarms` field, `addAlarm`, `removeAlarm`, `nextAlarmId` and the
     `alarms = []` in the reset. In the load (`results[9]`), call `await
     cancelStoredAlarms((results[9] as List<AlarmItem>).map((a) => a.id), cancel:
     Notifs.cancel, clear: () => Storage.saveAlarms(const []))`. Keep `Storage.getAlarms`
     and `Storage.saveAlarms`.
   - `test/boundaries/allowlist.txt`: remove the `sessions/screens/timer.dart` line.
10. Tests:
    - `test/app/shell/shell_tabs_test.dart`: with fakes for `AppConfigService` (cached config
      as in `update_required_screen_test.dart`) and `AuthController` (`currentUser` returns a
      user whose `uid` is `u1`, or use a fake that exposes only what `buildShellTabs`
      reads), call `buildShellTabs` inside a `Builder`: no module, four tabs labelled Home,
      Habits, Study, Groups with the icons of step 5; a registry with one campus descriptor
      allowed for `u1`, five tabs ending with Campus; the same descriptor not allowed, four.
      Do not build the tab pages.
    - `test/features/account/shell_header_test.dart`: inside `MultiProvider` with a fake
      `AppState` (profile name, avatar index and colour, `themeMode`) and a fake
      `AuthController` whose `currentUser` is null: tapping the avatar (find by tooltip
      "Settings") pushes a route named `/settings` on the root navigator showing
      `SettingsScreen`; the avatar button is at least 48 by 48.
    - `test/core/notifications/stored_alarms_test.dart`: three ids are cancelled then
      cleared once; an empty list calls neither.
    - `test/features/study/study_screen_test.dart`: with a fake `AppState` for the header,
      both rows show with a chevron and a non-null `onTap`. Do not push `StatsScreen` or
      `HistoryScreen` in a test (they need the full `AppState`); the screenshots cover it.
11. `grep -rln "ShellHeader(" lib/features` must list `home_screen.dart`,
    `habits_screen.dart`, `study_screen.dart`, `groups_screen.dart`, `campus_screen.dart`.
12. Run `./scripts/verify.sh`. Regenerate the design baseline only if a count fell
    (`dart run scripts/check_design.dart --write-baseline`); no count may rise.
13. Screenshots (`DESIGN.md` 12): each tab root (Home, Habits with both segments, Study,
    Groups) and Settings scrolled to About, light and dark, EN and RU; Habits in KK; Settings
    at text scale 1.3. The Campus tab cannot appear with an empty registry; show it with a
    temporary local registry entry that you do not commit, and say so.

## Non-goals
- Home's new layout (P3-07), Study's course list and module rows (P3-06), Campus search
  (P3-11), restyling the rows of Settings, any change to the two tab bars' look.
- Do not touch the connections feature or its hidden-tab comment.
- Do not change the delete-account flow.

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
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (the "Current features" list in `AGENTS.md` gains `study` and `campus`; `docs/PRODUCT.md` describes the tabs, P3-13 rewrites it fully).
- `url_launcher` and `package_info_plus` are already dependencies; add nothing to `pubspec.yaml`.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -rn "'/timer'\|'/alarms'\|routeTimer\|routeAlarms\|TimerScreen\|AlarmsScreen\|addAlarm\|nextAlarmId" lib test` prints nothing.
- [ ] `grep -rn "onThemeChange\|pushReplacementNamed('/auth')" lib` prints nothing.
- [ ] The four test files of step 10 exist and pass; four tabs with no module visible, five with one.
- [ ] Step 11's grep lists the five files.
- [ ] Screenshots of step 13 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Give the privacy policy URL and the support email address in the task message (E-2).
- After merge, sign out and sign in on a device and confirm you land on the sign-in screen,
  then on Home.

## Deliverable
Branch `numer2/p3-05-new-shell`, one commit, message `feat: move to the five tab shell with settings behind the avatar` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- The task message does not contain the privacy URL and the support address.
- Removing a parameter or a file named here breaks a caller this prompt does not list.
- The Habits switch carries behaviour beyond selecting the tab and scrolling to today that
  a `SegmentedButton` cannot keep.
