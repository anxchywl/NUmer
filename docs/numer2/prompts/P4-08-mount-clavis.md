# P4-08: Mount Clavis: registry, Upcoming item, local reminder

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-06, P4-07, P3-10, P3-11, P4-04

## Goal
Show "Piano room" in the Campus tab for users whose `clavis` flag is on. A booking made
there appears in Home's "Upcoming" block and gives one local reminder 30 minutes before;
both go away when the booking is released.

## Read first
- `AGENTS.md`, `docs/numer2/DESIGN.md` sections 3.3, 4.1, 4.4, 6, 7.2, 9.5, 10 and 12
- `docs/numer2/DECISIONS.md` D-21, D-24, D-40, D-42
- `lib/features/gradus/` (P4-04: the descriptor, module body and lazy-start test to copy)
- `lib/core/modules/module_descriptor.dart`, `lib/app/modules/module_registry.dart`,
  `lib/core/config/app_config_service.dart` (`moduleBaseUrl`, P4-04)
- `lib/core/upcoming/upcoming_item.dart`, `upcoming_store.dart` (P3-10),
  `lib/features/home/upcoming_section.dart` (P3-10), `lib/features/campus/campus_screen.dart`
  (P3-11), `lib/app/shell/shell_tabs.dart` (`openUpcoming`, P3-10)
- `lib/features/account/data/sign_out.dart` (`signOutAndReset`, P3-03 and P3-10)
- `lib/core/notifications/notifications.dart:104-155` (`scheduleOnce`), `:245-250` (`cancel`)
- `lib/core/config/app_config.dart:87-94` (`stableHash`)
- In Clavis at tag `v0.2.0`: `piano_room_feature/lib/piano_room_feature.dart`,
  `lib/piano_room_remote.dart`, `lib/src/data/http_piano_room_repository.dart:261-298`
  (`PianoRoomRemote`), `piano_room_app/lib/main.dart:60-140` (how the dev host mounts it)

## Context
- Line numbers are from `main` at `e031f97`; phase 3 files come from P3-03 to P3-11. Find
  code by name if it moved.
- `PianoRoomRemote(baseUri:, idToken:, onSessionExpired:, studentId:)` builds the policy,
  session and repository; `remote.repository.synchronizeClock()` must complete (or fail)
  before `PianoRoomFeature` mounts, as the dev host does (`main.dart:89`, `:125-136`).
  `PianoRoomFeature(session:, repository:, policy:, now:, onBooked:, onReleased:)`.
- Clavis is online-only. When the network is missing its repository raises
  `PianoRoomFailureCode.offline` and the screen shows its own localized offline message
  ("You are offline. Reconnect and try again. ..."). The host adds no offline screen of its
  own; `lib/features/clavis/clavis.dart` says in one comment that the module is online-only.
- A module that needs a backend is not visible without a `baseUrl` (D-42). This task adds
  `final bool needsBaseUrl` (default `false`) to `ModuleDescriptor` and makes
  `visibleModules` require `config.moduleBaseUrl(d.flagId) != null` when it is true.
  Gradus keeps `false`.
- Campus row order is the registry order Events, Marketplace, Piano room (`DESIGN.md` 4.4).
  Piano room is the first campus module, so the campus part of the registry is
  `[clavisModule]` now; P4-11 and P4-14 insert theirs before it.
- Upcoming (D-21, D-40): `UpcomingItem(id, moduleId, kind, title, startsAt, route)`;
  `UpcomingStore.put(uid, item)`, `remove(uid, id)`, `clear(uid)`. Home's hook
  `bool Function(BuildContext, UpcomingItem)` is `(_, _) => false` in `shell_tabs.dart`.
  This task replaces it with a function in `lib/app/modules/open_upcoming.dart` that opens
  the visible module whose `id == item.moduleId` with `openModule` and returns true, or
  returns false when none is visible. It is generic; P4-11 reuses it.
- Ids: the item id is `'clavis:<booking id>'`; its reminder's notification id is
  `UpcomingStore.notificationIdOf(itemId)` = `stableHash(itemId) & 0x7FFFFFFF`, added by
  this task, so the store can cancel a reminder without knowing the module.
- Sign-out and account deletion call `UpcomingStore.clear(uid)` (P3-10). Reminders must go
  with the items, so `remove` and `clear` cancel the notification of every item they drop.
- Strings (`{time}` is `DateFormat.Hm(localeName)` of the slot start):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `moduleClavisTitle` | Piano room | Комната с пианино | Фортепиано бөлмесі |
  | `moduleClavisSubtitle` | Book the practice room | Бронирование комнаты для занятий | Жаттығу бөлмесін брондау |
  | `clavisReminderBody` | Your piano room booking starts at {time}. | Бронь комнаты с пианино начинается в {time}. | Фортепиано бөлмесін брондау сағат {time}-да басталады. |

## Steps
1. `pubspec.yaml`: add `piano_room_feature` by git (`url:
   https://github.com/anxchywl/Clavis.git`, `path: piano_room_feature`, `ref: v0.2.0`);
   run `flutter pub get`.
2. `ModuleDescriptor.needsBaseUrl` and the `visibleModules` rule (Context); extend
   `test/app/modules/module_registry_test.dart`: a descriptor with `needsBaseUrl: true` is
   hidden without a `baseUrl` and shown with one.
3. `UpcomingStore`: constructor parameter `Future<void> Function(int id)
   cancelNotification` (the app passes `Notifs.cancel`), `static int notificationIdOf(String
   itemId)`, and `remove` and `clear` call `cancelNotification(notificationIdOf(id))` for
   each item they drop (also for an item `put` drops because it is past). Update its
   provider in `bootstrap.dart` and its tests.
4. `lib/features/clavis/`: barrel `clavis.dart` exporting `clavisModule`;
   `clavis_module.dart` with top-level `clavisTitle`, `clavisSubtitle`,
   `buildClavisModule` (a `NumerModuleScaffold` titled `moduleClavisTitle` whose body is
   `const ClavisModuleBody()`) and `const ModuleDescriptor clavisModule = ModuleDescriptor(
   id: 'clavis', ..., icon: Icons.piano_outlined, section: ModuleSection.campus, flagId:
   'clavis', needsBaseUrl: true, builder: buildClavisModule)`.
5. `ClavisModuleBody` (`StatefulWidget`, in `clavis_module_body.dart`): in `initState`
   read `ModuleSession`, `AuthController` (uid), `AppConfigService` and `UpcomingStore`;
   build `PianoRoomRemote(baseUri: config.moduleBaseUrl('clavis')!, idToken:
   session.idToken, onSessionExpired: () async => await session.handleSessionExpired() !=
   null, studentId: uid)` and `_clock = remote.repository.synchronizeClock().catchError((_)
   {}, test: (error) => error is PianoRoomFailure)`. `build` is a `FutureBuilder` on
   `_clock`: until done, `const NumerSkeleton(rows: 6)`; then `PianoRoomFeature(session:
   remote.session, repository: remote.repository, policy: remote.policy, now: remote.now,
   onBooked: _booked, onReleased: _released)`.
6. `_booked(PianoRoomBooking booking)`: `upcoming.put(uid, UpcomingItem(id:
   'clavis:${booking.id}', moduleId: 'clavis', kind: UpcomingKind.pianoBooking, title:
   l10n.moduleClavisTitle, startsAt: booking.start, route: '/module/clavis'))`; then, when
   `booking.start.subtract(const Duration(minutes: 30))` is after now,
   `Notifs.scheduleOnce(id: UpcomingStore.notificationIdOf(itemId), title:
   l10n.moduleClavisTitle, body: l10n.clavisReminderBody(<time>), whenLocal: <that time,
   local>)`. `_released(String bookingId)`: `upcoming.remove(uid, 'clavis:$bookingId')`
   (which cancels the reminder). Read `l10n` from the widget's context at call time.
7. `lib/app/modules/open_upcoming.dart`: `bool openUpcomingItem(BuildContext context,
   UpcomingItem item, List<ModuleDescriptor> visible)` per Context. `shell_tabs.dart`
   passes `(context, item) => openUpcomingItem(context, item, <visible campus and study
   modules for the current uid>)` instead of `(_, _) => false`.
8. Registry: `moduleRegistry` becomes `[gradusModule, clavisModule]`; update
   `test/app/modules/registry_order_test.dart` to `['gradus', 'clavis']`.
9. Strings: add the three keys (the last with a `time` placeholder of type `String`); run
   `flutter gen-l10n`.
10. Tests:
    - `test/features/clavis/clavis_lazy_start_test.dart` (pattern of the Gradus one): with
      the flag and `baseUrl` set, pumping the Campus root makes zero `idToken` calls and
      creates no `ClavisModuleBody`; tapping the row creates one; going back disposes it.
    - `test/features/clavis/clavis_upcoming_test.dart`: drive `_booked` and `_released`
      through a `PianoRoomFeature` built with Clavis's sample repository
      (`piano_room_development.dart`) or by calling the two callbacks of a pumped
      `ClavisModuleBody` with a fake remote; assert one Upcoming item with kind
      `pianoBooking`, the booking's start and id `clavis:<id>`; one scheduled reminder at
      start minus 30 minutes (inject the scheduler: `ClavisModuleBody` takes an optional
      `scheduleReminder` parameter defaulting to `Notifs.scheduleOnce`); no reminder for a
      booking starting in 20 minutes; release removes the item and cancels the same id.
    - `test/core/upcoming/upcoming_store_test.dart` (extend): `remove` and `clear` cancel
      the notification ids of the dropped items.
    - `test/app/modules/open_upcoming_test.dart`: an item of a visible module opens
      `/module/clavis` and returns true; an item of a hidden module returns false and
      pushes nothing.
11. Run `./scripts/verify.sh`.
12. Size: `scripts/measure_size.sh` before and after; report both numbers and the
    difference against the 1.0 MB budget.
13. Screenshots (`DESIGN.md` 12) against the staging Clavis backend with the flag on for
    the test account: Campus with the Piano room row; the module week view; the booking
    sheet; Home with the piano booking in Upcoming; the module with airplane mode on;
    light and dark, EN and RU; one at text scale 1.3.

## Non-goals
- No change to Clavis (P4-06) or its backend (P4-07).
- No Upcoming item for a booking made on another device or in the standalone app; the store
  is local by design (D-21).
- No notification tap routing (P5-01).

## Constraints
- Offline-first contract: UI never writes Firestore. The Upcoming store is device-local by design.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel. Direction is `features -> core -> shared`. `lib/features/clavis/` imports `lib/app/app_state.dart` at most; `lib/core/upcoming/` imports nothing from `lib/features/` or `lib/app/`.
- The module starts nothing before it is opened (`DESIGN.md` 10).
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. A file listed in `scripts/file_size_baseline.txt` may only shrink. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No secrets in code or `--dart-define`; the base URL comes from `config/app`.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `clavis` to the feature list in `AGENTS.md`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The tests of steps 2, 3 and 10 exist and pass.
- [ ] `grep -rn "(_, _) => false" lib/app/shell` prints nothing.
- [ ] The report gives both `apkDownloadBytes` values and the difference.
- [ ] Screenshots of step 13 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- `USER_ACTIONS.md` F-7: add `modules.clavis.baseUrl` to `config/app` (staging, then production).
- Book and release a slot on a device; check the Upcoming row and that the reminder arrives 30 minutes before.
- Keep the `clavis` flag on the `allow` list until P4-07 is deployed and listed in `ACCOUNT_EVENT_TARGETS` (F-3).

## Deliverable
Branch `numer2/p4-08-mount-clavis`, one commit, message `feat: mount the piano room in campus` (subject line only). Do not push.
Report: files changed, test output, the size numbers, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot resolve `piano_room_feature` at `v0.2.0` together with NUmer's dependencies.
- `PianoRoomFeature` has no `onBooked` or `onReleased`, or `PianoRoomFailure` is not exported.
- The Upcoming store or the Campus root differs from the P3-10 and P3-11 prompts.
- The size grows by more than 1.0 MB.
