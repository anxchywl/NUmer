# P4-17: Events package: host chrome, filter rows, focus mode, host hooks

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** EventsBot (`/Users/anx/events_bot`) @ `main`   **Depends on:** P4-16, P4-09

## Goal
Third of the three Events package tasks (D-42). Inside NUmer the package shows its sections
as tabs under NUmer's app bar instead of its own bottom bar, its filters as rows that open
sheets instead of pills, and every sheet with a text field in focus mode. It also gives
the host the three hooks P4-11 needs: Telegram linking, a local reminder, and opening an
event from the news feed.

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DESIGN.md` sections 3.3, 5.2, 5.3, 5.5, 5.7,
  6, 9.5 and 11, `docs/numer2/DECISIONS.md` D-42 (`/Users/anx/numer_app/docs/numer2/...`)
- `/Users/anx/numer_app/packages/numer_ui/MIGRATION.md` "Focus mode" and the "Sheets with a
  text field" table
- `flutter_events/lib/app.dart` (`EventsFeature`), `lib/features/shell/app_shell.dart`
  (256 lines), `lib/features/events/events_screen.dart:560-700` (`_buildBody`,
  `_buildFilterStrip`), `:885-` (`_EventFilterPill`), `:1128-1300` (`_SortSheet`,
  `_MultiSelectSheet`), `lib/features/submit/submit_screen.dart:1240-1260` (the
  `ChoiceChip`), `lib/features/events/event_detail_screen.dart` (`_ModerationCommentSheet`),
  `lib/features/event_manager/analytics_event_picker.dart`,
  `lib/features/shared/loading_skeleton.dart`

## Context
- Line numbers are from EventsBot `main` at `a5a44ef` plus P4-10 and P4-16. Find code by name.
- `AppShell` draws a custom `bottomNavigationBar` (`app_shell.dart:140`) over an
  `IndexedStack` of destinations (`:36-67`, `:70-86`): for admins Events,
  `CoordinatorDashboardScreen` ("Requests") and `EventManagerScreen` ("Analytics"); for
  others Events and `MyEventsScreen` ("My requests").
- Host chrome (D-42, `DESIGN.md` 3.3 and 9.5): the role is known only after the session
  bootstrap, so the package itself draws the tabs: in host chrome, after bootstrap,
  `EventsFeature` renders a text-only `TabBar` (theme from `NumerTheme`, labels in sentence
  case) above a `TabBarView`, with tabs Events and My requests, and for admins also
  Requests and Analytics (four at most). NUmer wraps it in `NumerModuleScaffold(title:
  "Events", body: EventsFeature(...))` (P4-11). The standalone app keeps `AppShell`.
- The filter strip (`events_screen.dart:643`) is a row of `_EventFilterPill`s: search, sort,
  relevance and categories, each opening a sheet or the search field. `DESIGN.md` 5.5 and
  11: no chips or pills. They become one `NumerBlock` of `NumerRow`s (title = the filter's
  name, trailing = its current value as `meta` text, chevron), each opening the same sheet
  as today; search becomes the theme `TextField` above the block with a search prefix icon
  and a clear `IconButton` with a tooltip while text is present.
- The one `ChoiceChip` (`submit_screen.dart:1248`) becomes a `RadioListTile` group in the
  same place, or rows with a check mark when the choice is multiple.
- Sheets with a text field (`MIGRATION.md` table): `submit_screen.dart` (`asSheet: true`,
  a stepped form), `_ModerationCommentSheet`, `_MultiSelectSheet` when `withSearch`, and the
  `GlobalSearchBar` inside `AppBottomSheet.show` in `analytics_event_picker.dart`. The
  submit form uses the stepped-flow fallback of `MIGRATION.md`; the other three are
  `NumerSheetBody` with one field (`doneLabel` null).
- `AppPanelSkeleton` and `AppSheetSkeleton` (10 uses) are the package's own skeletons;
  they become `NumerSkeleton` with the same number of rows.
- Host hooks (D-42), used by NUmer in P4-11:
  - Telegram: P4-09 added `POST /api/flutter/auth/telegram-link` answering `{url,
    expires_in}` (409 when already linked) and `telegram_linked` in `GET
    /api/flutter/auth/session`.
  - Reminders: D-26 puts "a local reminder" in version one. The package shows the action;
    the host stores it (an Upcoming item and a notification), so the package needs no
    storage or notification plugin.
  - News: a feed event item has id `event_<public token>` (`functions/src/feed/compose.ts:93`);
    the Flutter API fetches events by numeric id only (`fetchEvent(int id)`), and
    `EventModel.publicToken` is in every list item.
- New strings (if P4-16 did not create them):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `done` | Done | Готово | Дайын |
  | `remindMe` | Remind me | Напомнить | Еске салу |
  | `reminderSet` | Reminder set | Напоминание установлено | Еске салу қосылды |

## Steps
1. `EventsFeature` gains `this.chrome = EventsChrome.own` with `enum EventsChrome { own,
   host }` (exported). In host chrome, the ready state builds
   `lib/features/shell/host_tabs.dart`: `DefaultTabController` + `Column(TabBar,
   Expanded(TabBarView))` with the tabs of Context, reusing the same screen widgets as
   `AppShell`. `own` keeps `AppShell` unchanged.
2. Hooks:
   - `lib/core/api_client.dart`: `SessionProfile.telegramLinked` (`telegram_linked`,
     default false) and `Future<Uri> requestTelegramLink()` (POST, 409 ->
     `ConflictException` from `core/exceptions.dart`, adding the class if absent).
   - `lib/events_host.dart` (the package has no single entry file; hosts import
     `package:events_feature/app.dart` and `package:events_feature/events_host.dart`):
     `export 'core/exceptions.dart' show ConflictException;`, `Future<Uri>
     requestEventsTelegramLink()` and `Future<bool> eventsTelegramLinked()`, which GETs
     `/api/flutter/auth/session` and returns `telegram_linked`; both use the host session of
     `AuthStore` and throw `StateError('events is not started')` when no host session is set; `@immutable class EventReminder { final int eventId;
     final String title; final DateTime startsAt; }`; `abstract interface class
     EventsReminders { bool isSet(int eventId); Future<void> set(EventReminder reminder);
     Future<void> clear(int eventId); }`.
   - `EventsFeature` gains `EventsReminders? reminders` and `String? initialEventToken`.
     With `reminders` set, the event detail screen shows one `AppTextButton` under the
     date: `remindMe` when not set (tap -> `set` with the event's start read as
     UTC+05:00 from `eventDate` and `eventTime`, the zone D-37 uses for the feed,
     then `HapticFeedback.lightImpact()`), `reminderSet` when set (tap -> `clear`); hidden
     for an event that has started. With `initialEventToken`, after the first list load the
     events tab pushes the detail of the event whose `publicToken` matches, once; no match
     leaves the list.
3. Before editing `events_screen.dart` (1464 lines) and `event_detail_screen.dart` (1739),
   move `_EventFilterPill`, `_SortSheet` and `_MultiSelectSheet` (`events_screen.dart:885-`,
   `:1128-1300`) and `_ModerationCommentSheet` into files of their own under the same
   folder, unchanged, so the new code goes into small files.
   Filters: replace `_buildFilterStrip` and `_EventFilterPill` with the field and block of
   Context; the row titles and values use the keys P4-16 made for the pill labels. Delete
   `_EventFilterPill`.
4. Replace the `ChoiceChip` per Context.
5. Focus mode for the four sheets of Context, following `MIGRATION.md` "Focus mode". Each
   builder re-wraps its content in `EventsStringsScope`, because `showNumerFormSheet` uses
   the root navigator.
6. Replace `AppPanelSkeleton` and `AppSheetSkeleton` with `NumerSkeleton`; delete
   `loading_skeleton.dart` if nothing else uses it.
7. Tests:
   - `test/host_tabs_test.dart`: host chrome with a user profile shows two tabs, with an
     admin profile four, and no bottom bar in either; own chrome shows the bottom bar.
   - `test/events_list_states_test.dart` (fake `http.Client`): loading shows
     `NumerSkeleton`; an empty list shows the empty text; a failed request shows the
     error with a retry button that refetches; a list shows its rows.
   - `test/filter_rows_test.dart`: the block has one row per filter with its current value;
     tapping the sort row opens the sort sheet; no `Chip`, `ChoiceChip` or
     `_EventFilterPill` in the tree.
   - One focus-mode test per sheet of Context: with keyboard insets the title is hidden;
     the submit form shows a "Done" button that brings the form back.
   - `test/events_host_test.dart`: `requestEventsTelegramLink` returns the URL and maps 409
     to `ConflictException`; the detail shows "Remind me" with a fake `EventsReminders`,
     calls `set` with the event's id, title and start, then shows "Reminder set"; no
     button without `reminders` or for a started event; `initialEventToken` of a listed
     event opens its detail once, an unknown token opens nothing.
   - Every icon-only control in the files you touched has a non-empty tooltip or
     semantics label (assert with `find.byTooltip` or `bySemanticsLabel`).
8. Run the CI `flutter` job commands in `flutter_events/`.

## Non-goals
- No NUmer code (P4-11). No new screen; the Telegram row and the reminder storage are NUmer's.
- No change to the coordinator or analytics behaviour.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart`; no `Chip(`, `ChoiceChip`, `FilterChip`, `Badge(` or a pill-shaped container. Every icon-only control has a tooltip.
- Every sheet or dialog with a text field uses focus mode; a loading button shows only its spinner and passes `loadingHint`.
- Every user-facing string in the three ARB files.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] The CI `flutter` job commands pass in `flutter_events/`, including the release build.
- [ ] `grep -rn "Chip(\|_EventFilterPill\|AppPanelSkeleton\|AppSheetSkeleton" flutter_events/lib` prints nothing.
- [ ] The tests of step 7 exist and pass.
- [ ] Screenshots: host chrome as user and as admin (a test host or the standalone app with `chrome: host`), the filter block, each focus-mode sheet while typing; light and dark, EN and RU.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- After review: `git tag v1.1.0 && git push origin v1.1.0` in EventsBot (`USER_ACTIONS.md` F-1).

## Deliverable
Branch `numer2/p4-17-events-host-chrome`, one commit, message `feat: show events sections as host tabs` (subject line only). Do not push.
Report: files changed, each command's output, screenshots, user actions still pending.

## Stop and ask if
- The submit form cannot use the stepped-flow fallback of `MIGRATION.md`.
- A filter has no sheet today and would need a new one.
