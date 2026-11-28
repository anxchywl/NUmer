# P4-11: Mount Events: registry, Telegram link, reminders, feed taps

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-09, P4-17, P3-09, P3-10, P3-11, P4-08

## Goal
Show "Events" in the Campus tab for users whose `events` flag is on: browse, detail, my
requests, and the coordinator tabs for holders of `events:admin`; a "Remind me" that lands
in Home's Upcoming with a local notification; linking a Telegram account; and event taps in
the news feed that open the event in the module.

## Read first
- `AGENTS.md`, `docs/DESIGN.md` sections 3.3, 4.1, 4.2, 4.4, 5.9, 9.5, 10 and 12
- `docs/numer2/DECISIONS.md` D-21, D-22, D-26, D-40, D-42
- `lib/features/clavis/` (P4-08: descriptor, body, Upcoming writes, lazy-start test),
  `lib/app/modules/open_upcoming.dart` (P4-08)
- `lib/features/news/` (P3-09): the `openInModule` hook and `FeedItem`
- `lib/core/upcoming/` (P3-10, P4-08), `lib/core/notifications/notifications.dart:104-155`
- In EventsBot at tag `v1.1.0`: `flutter_events/lib/app.dart` (`EventsFeature`,
  `EventsHostSession`, `EventsChrome`), `flutter_events/lib/events_host.dart` (P4-17)

## Context
- Line numbers are from `main` at `e031f97`; phase 3 and P4-08 files are found by name.
- The package (`events_feature`, path `flutter_events`) takes `EventsFeature(session:
  EventsHostSession(idToken:, accountId:, onSessionExpired:), baseUrl: Uri, chrome:
  EventsChrome.host, reminders: EventsReminders?, initialEventToken: String?)`. In host
  chrome it draws its own tabs (Events, My requests, and for admins Requests and Analytics)
  under NUmer's app bar (D-42); the admin tabs follow the session's role, which the backend
  takes from the `events:admin` claim. NUmer adds no tab logic.
- `requestEventsTelegramLink()` returns the `t.me` URL or throws `ConflictException` when
  already linked; `eventsTelegramLinked()` GETs the session. Both throw `StateError` until
  the mounted `EventsFeature` has set its host session. Import
  `package:events_feature/app.dart` and `package:events_feature/events_host.dart` (which
  also exports `ConflictException`).
- Campus order is Events, Marketplace, Piano room (`DESIGN.md` 4.4): the registry becomes
  `[gradusModule, eventsModule, clavisModule]`.
- Reminders (D-42): Upcoming item id `'events:<eventId>'`, kind `eventReminder`, title the
  event title, `startsAt` the event start (read as UTC+05:00 by the package, D-37), route `/module/events`; one notification 60
  minutes before the start when that is in the future, id
  `UpcomingStore.notificationIdOf(itemId)`. `isSet` reads the Upcoming store.
- News (D-40): the hook `openInModule(context, item)` returns false today. For an event item
  (`kind == event`, id `event_<token>`) with the Events module visible, it opens the module
  with `initialEventToken: <token>` and returns true; otherwise false, and the news feature
  shows its own detail as today.
- The menu: one `IconButton(Icons.more_vert, tooltip: l10n.moduleMenu)` action on
  `NumerModuleScaffold` opening a `MenuAnchor` with the row "Link Telegram". The menu reads
  `eventsTelegramLinked()` when it is opened (not at build); while that call runs the row is
  disabled, a `StateError` (module still starting) or `true` hides it. Tapping it gets the URL, opens it with
  `launchUrl(url, mode: LaunchMode.externalApplication)` (`url_launcher` is a dependency),
  and on the next `AppLifecycleState.resumed` checks `eventsTelegramLinked()` once and
  shows `showNumerMessage` with the result.
- Strings (`{title}` and `{time}` are `String` placeholders):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `moduleEventsTitle` | Events | События | Іс-шаралар |
  | `moduleEventsSubtitle` | Events on campus | События в кампусе | Кампустағы іс-шаралар |
  | `moduleMenu` | More | Ещё | Тағы |
  | `eventsLinkTelegram` | Link Telegram | Привязать Telegram | Telegram-ды байланыстыру |
  | `eventsTelegramLinked` | Telegram is linked. | Telegram привязан. | Telegram байланыстырылды. |
  | `eventsTelegramNotLinked` | Telegram is not linked yet. | Telegram пока не привязан. | Telegram әлі байланыстырылмаған. |
  | `eventsTelegramFailed` | Could not open Telegram. Try again. | Не удалось открыть Telegram. Попробуйте снова. | Telegram ашылмады. Қайталап көріңіз. |
  | `eventsReminderBody` | {title} starts at {time}. | {title} начинается в {time}. | {title} сағат {time}-да басталады. |

## Steps
1. `pubspec.yaml`: add `events_feature` by git (`url:
   https://github.com/anxchywl/EventsBot.git`, `path: flutter_events`, `ref: v1.1.0`);
   `flutter pub get`. Do not start before the EventsBot tag `v1.1.0` exists (F-1).
2. iOS purpose strings (Events brings `image_picker`): add to `ios/Runner/Info.plist`
   `NSPhotoLibraryUsageDescription` = "NUmer uses your photos when you add a picture to an
   event or a listing." and `NSCameraUsageDescription` = "NUmer uses the camera when you take
   a picture for an event or a listing."; add `InfoPlist.strings` with the same two keys to
   `ios/Runner/ru.lproj` and `ru-KZ.lproj` (RU: "NUmer использует фото, когда вы добавляете
   снимок к событию или объявлению." and "NUmer использует камеру, когда вы снимаете фото для
   события или объявления.") and `kk.lproj` (KK: "NUmer іс-шараға немесе хабарландыруға сурет
   қосқанда фотосуреттеріңізді пайдаланады." and "NUmer іс-шара немесе хабарландыру үшін
   суретке түсіргенде камераны пайдаланады."), registered in the Runner target's variant
   group in `ios/Runner.xcodeproj/project.pbxproj` like `Main.strings`. Run `cd ios && pod
   install` and keep `ios/Podfile.lock`. If the variant group cannot be edited reliably, keep
   the English keys only and say so in the report.
3. `lib/features/events/`: barrel `events.dart` exporting `eventsModule` and
   `openEventFromFeed`; `events_module.dart` with top-level `eventsTitle`,
   `eventsSubtitle`, `buildEventsModule` and `const ModuleDescriptor eventsModule =
   ModuleDescriptor(id: 'events', ..., icon: Icons.event_outlined, section:
   ModuleSection.campus, flagId: 'events', needsBaseUrl: true, builder:
   buildEventsModule)`.
4. `events_module_body.dart`: `EventsModuleBody({String? initialEventToken})`; in
   `initState` read `ModuleSession`, the uid, `AppConfigService` and `UpcomingStore`, build
   the `EventsHostSession` (token contract as P4-04) and an `UpcomingEventsReminders
   implements EventsReminders` (`events_reminders.dart`, per Context, with an injectable
   `scheduleReminder` defaulting to `Notifs.scheduleOnce`). `buildEventsModule` returns
   `NumerModuleScaffold(title: l10n.moduleEventsTitle, actions: [<menu of Context>], body:
   const EventsModuleBody())`.
5. `events_telegram_menu.dart`: the menu action and the resume check of Context, as a
   `StatefulWidget` with `WidgetsBindingObserver`; errors: `ConflictException` -> the
   linked message; a failed `launchUrl` -> `eventsTelegramFailed` (as an error message).
6. `openEventFromFeed(BuildContext context, FeedItem item, List<ModuleDescriptor>
   visible)` in `events_feed_link.dart`: per Context, pushes a route named
   `/module/events` whose builder is `NumerModuleScaffold(title: ..., actions: [...],
   body: EventsModuleBody(initialEventToken: token))` on the root navigator. The app passes
   it as the news hook in `shell_tabs.dart` (and wherever P3-09 placed `(_, _) => false`
   for news: the `openInModule` parameter of `HomeScreen` and `NewsScreen`).
7. Registry `[gradusModule, eventsModule, clavisModule]`; `registry_order_test.dart` to
   `['gradus', 'events', 'clavis']`.
8. Strings: add the keys; run `flutter gen-l10n`.
9. Tests:
   - `test/features/events/events_lazy_start_test.dart` (pattern of the Clavis one).
   - `test/features/events/events_reminders_test.dart`: `set` writes one `eventReminder`
     item with id `events:<id>` and schedules one reminder at start minus 60 minutes; a
     start 30 minutes away writes the item and schedules nothing; `clear` removes it and
     cancels that id; `isSet` follows the store.
   - `test/features/events/events_feed_link_test.dart`: an event item with the module
     visible returns true and pushes `/module/events` with the token; with the module
     hidden returns false; an announcement returns false.
   - `test/features/events/events_telegram_menu_test.dart` with fakes for the two package
     functions and `launchUrl` (`EventsTelegramMenu({Future<Uri> Function() requestLink =
     requestEventsTelegramLink, Future<bool> Function() isLinked = eventsTelegramLinked,
     Future<bool> Function(Uri) open = _openExternal})`): not linked shows the row; tapping opens the URL; on resume a linked result
     shows the linked message and hides the row; a conflict shows the linked message.
10. Run `./scripts/verify.sh`.
11. Size: `scripts/measure_size.sh` before and after; report both numbers and the
    difference against the 1.0 MB budget (the image packages of the module count).
12. Screenshots against the staging Events backend with the flag on for the test account:
    Campus with Events, the module as a student and as an admin (four tabs), an event
    detail with "Remind me" and after it, Home with the reminder in Upcoming, the menu with
    "Link Telegram"; light and dark, EN and RU; one at text scale 1.3.

## Non-goals
- No change to the Events package or backend.
- No Upcoming item for requests or for reminders set in the Mini App.
- No notification tap routing (P5-01).

## Constraints
- Offline-first contract: UI never writes Firestore. The Upcoming store is device-local by design.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel. Direction is `features -> core -> shared`. `lib/features/events/` imports `lib/features/news/news.dart` for `FeedItem` and nothing else of another feature.
- The module starts nothing before it is opened (`DESIGN.md` 10).
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. A file listed in `scripts/file_size_baseline.txt` may only shrink. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No secrets in code or `--dart-define`; the base URL comes from `config/app`.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `events` to the feature list in `AGENTS.md`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The tests of step 9 exist and pass.
- [ ] The report gives both `apkDownloadBytes` values and the difference.
- [ ] Screenshots of step 12 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- `USER_ACTIONS.md` F-7: add `modules.events.baseUrl` to `config/app`.
- F-4: link your own Telegram account from the module menu and confirm your events appear.
- Keep the `events` flag on the `allow` list until P4-18 is deployed and listed in `ACCOUNT_EVENT_TARGETS` (F-3).

## Deliverable
Branch `numer2/p4-11-mount-events`, one commit, message `feat: mount events in campus` (subject line only). Do not push.
Report: files changed, test output, the size numbers, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot resolve `events_feature` at `v1.1.0` with NUmer's dependencies.
- The tagged package lacks `EventsChrome`, `EventsReminders`, `initialEventToken` or the two Telegram functions.
- The size grows by more than 1.0 MB.
