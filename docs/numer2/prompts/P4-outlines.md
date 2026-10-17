# Phase 4 outlines: module integration

Outlines, not prompts. Expand each with `TEMPLATE.md` when its turn comes, citing the code as
it is then. Order: Gradus, Clavis, Events, Muto. Each module ships behind its flag
(`config/app`, `DECISIONS.md` D-23).

Common to every task:
- Package tasks work in the module's repo and follow that repo's `AGENTS.md` and
  `./scripts/verify.sh`. Mount tasks work in NUmer.
- UI is bound by `../DESIGN.md`, in particular section 9 (mapping) and 9.5 (per module).
- A module starts nothing until it is opened: no network call, no storage read, no
  controller at app start. Every mount task proves it with a counting-fake test.
- Every mount task measures download size before and after (`scripts/measure_size.sh`) and
  reports the difference against the 1.0 MB budget.
- A module's flag is opened beyond the `allow` list only after its account-events handler is
  deployed (Gradus has none: it stores nothing on a server).
- NUmer depends on a module package by git tag; `numer_ui` is overridden to the local path
  with `dependency_overrides`.

The token contract every package adopts: the host passes
`Future<String> Function({bool forceRefresh}) idToken`. The package calls it for every
request, never stores the token, and keys its state on the user id, not on the token. On a
401 it calls `onSessionExpired` once; the host refreshes and retries or signs out.

---

## Gradus (GPA)

### P4-01 Gradus package: `numer_ui`, token provider, host chrome
**Repo:** Gradus. **Depends on:** P3-02. **Executor:** sonnet, high. **Risk:** med.

- Replace `app_ui` with `numer_ui` by git tag, following `numer_ui/MIGRATION.md`; delete the
  vendored `app_ui/` once nothing imports it.
- `GradusSession` takes an `idToken` provider and `accountId`; the syllabus importer calls it
  per request; the controller and widget keys depend on `accountId` only
  (`gradus_feature.dart:64-73,87` today rebuild on a token change).
- `GradusChrome.host` is the default the host uses; the standalone app keeps `own`.
- Add the missing EN value for `creditsRatio` or delete the key in all three files.
- Fix the claim in docs that `verify.sh` runs everything CI runs.

**Acceptance:** the repo's verify passes with its floors; a test proves a token change does
not dispose the controller; no `LucideIcons`, `AppColors.primary` constant or `Geist` left.
**Owner:** tag the release.

### P4-02 Grades: Hive types 18 to 20, storage, rules
**Repo:** NUmer. **Depends on:** P0-06. **Executor:** opus, high. **Risk:** high.

- `LocalCourseGrade` (typeId 18, sync entity keyed by course id: `semesterId`,
  `gradeLetter`, `assignments`), `LocalAssignment` (19, plain), `LocalSemester` (20, sync
  entity: `name`, `position`), hand-written positional adapters, registered with the others.
- `LocalCourse` gains `code` as an appended write with a guarded read.
- Boxes `${uid}_course_grades`, `${uid}_semesters`, opened, cleared and deleted with the
  existing boxes.
- `Storage` methods: read all, upsert one, soft-delete one, each setting `dirty` and
  `updatedAt`; soft-deleting a course soft-deletes its grade record in the same call.
- Rules: owner-only `users/{uid}/courseGrades/{id}` and `users/{uid}/semesters/{id}` with a
  rules test.
- First spot checks, written into the report before coding: does any screen break on a
  course with empty `day`, `start`, `end`; what unit `credits` uses; how course ids are
  generated.

**Acceptance:** adapter round-trip tests; a test that data written by the old `LocalCourse`
adapter is read by the new one; `typeId` values 10 to 17 untouched (a test pins the ids).
**Stop and ask if:** a typeId above 17 is already used anywhere.

### P4-03 Grades: sync push and pull
**Repo:** NUmer. **Depends on:** P4-02. **Executor:** opus, high. **Risk:** high.

- Push blocks and `_pullCollection` calls for the two collections, following the course
  pattern exactly (dirty accessors, batches of 450, sync-state keys, server `updatedAt`
  cursor, whole-record last-writer-wins, conflicts logged).
- `code` added to the course create branch, update branch and `_courseToRemote`.
- Account deletion's explicit list gains the two names.

**Acceptance:** tests with a fake remote: push of a dirty grade, pull of a newer one, local
dirty wins over an older remote, soft delete propagates; no existing sync test changes.
**Owner:** two-device check.

### P4-04 Mount Gradus
**Repo:** NUmer. **Depends on:** P4-01, P4-03, P3-06, P2-03. **Executor:** sonnet, high.

- `lib/features/gradus/`: `HiveTranscriptRepository implements TranscriptRepository`:
  `load` builds the transcript from courses, grade records and semesters; `save` diffs
  against the current state and writes only changed rows; it never calls
  `Storage.saveCourses` with a partial list. A course created in Gradus is a NUmer course
  with empty timetable fields and `hiddenFromLeaderboard: true`.
- The registry entry (`section: study`, flag `gradus`, title "GPA"), built lazily with the
  token provider and the syllabus base URL from configuration.
- A weight sum above 100 or an unknown letter never loses a course: the adapter skips the
  bad part and keeps the rest.

**Acceptance:** repository tests for every edit the Gradus controller can make (add, edit,
delete course, semester, assignment; rollback on failure); lazy-start test; size report;
screenshots of the GPA screen inside `NumerModuleScaffold` in both modes.

### P4-05 Import from standalone Gradus
Only if the owner says real users have data there (O-5). One-shot, idempotent import from the
`SharedPreferences` keys, matching courses by exact normalized name, never deleting the old
keys, asking the user on an ambiguous match.

---

## Clavis (piano room)

### P4-06 Clavis package: `numer_ui`, token provider
**Repo:** Clavis. **Depends on:** P3-02. **Executor:** sonnet, high.

- `numer_ui` migration; delete the vendored `app_ui/`.
- `HttpPianoRoomRepository` and `PianoRoomRemote` take the `idToken` provider instead of a
  token string; `studentId` is the Firebase uid supplied by the host.
- `onSessionExpired` callback added to `PianoRoomFeature`.
- A callback `onBookingChanged(booking or null)` so the host can keep its Upcoming item.
- UI per DESIGN 9.5: rows for slots, text button "Book", light haptic on a confirmed booking,
  the existing skeleton restyled to the static one.

**Acceptance:** verify with its floors; a test that the provider is called per request and a
401 calls `onSessionExpired` once.

### P4-07 Clavis backend: account events handler
**Repo:** Clavis. **Depends on:** P2-07, P2-04. **Executor:** sonnet, medium.

`POST /internal/v1/account-events`, verified with `numer_identity.account_events`; on
`account.deleted` release the subject's future bookings and anonymise past ones (replace the
subject with a fixed marker), and delete their request and limit rows; idempotent on the
event id (a small table of processed ids). Not routed by any public documentation; refuses a
bad signature with 401.
**Owner (approval):** redeploy; add the target to `ACCOUNT_EVENT_TARGETS`.

### P4-08 Mount Clavis
**Repo:** NUmer. **Depends on:** P4-06, P4-07, P3-10, P3-11. **Executor:** sonnet, high.

Registry entry (`campus`, flag `clavis`, title "Piano room"); the module in
`NumerModuleScaffold`; on a booking, an Upcoming item and one local notification 30 minutes
before, both removed on release; an offline message instead of the schedule when there is no
connection (the module is online-only and says so).
**Acceptance:** lazy-start test; Upcoming item test; size report; screenshots.

---

## Events

### P4-09 Events backend: account events, Telegram link
**Repo:** EventsBot. **Depends on:** P2-06, P2-07. **Executor:** opus, high. **Risk:** high.

- Account events handler: delete or anonymise the user's rows; events they created stay,
  attributed to a removed-user marker.
- `POST /api/flutter/auth/telegram-link` (Firebase bearer): creates a one-time code in Redis
  (10 minutes) bound to the identity and returns `t.me/<bot>?start=link_<code>`.
- Bot handler for `/start link_<code>`: shows the masked email of the NUmer account and asks
  for confirmation; on yes attaches the identity to the Telegram user; if a Firebase-created
  user with content already exists, refuses and explains; never copies a role.
- `GET /api/flutter/auth/session` reports whether a Telegram account is linked.
- Confirm that the public events list used by the feed needs no authentication and returns a
  publish time.

**Acceptance:** integration tests for link success, replayed code, expired code, a uid
already linked, refusal on content conflict, and that an admin Telegram account linked to a
NUmer account without the claim is not admin in Flutter routes.
**Owner (approval):** answer O-4; redeploy.

### P4-10 Events package: `numer_ui`, ARB strings, host chrome, base URL, token provider
**Repo:** EventsBot. **Depends on:** P3-02. **Executor:** sonnet, high. **Risk:** high (the
largest migration: about 300 colour references).

- `numer_ui` migration; delete the vendored `app_ui/`; `AppCalendar` moves into the package
  itself.
- Strings move from the hand-written map to ARB files with identical keys in EN, RU and KK;
  the session-expired text is localised and names NUmer.
- The API base URL becomes a parameter of `EventsFeature`.
- The token provider replaces the token string (`core/api_client.dart` reads it per request).
- Host chrome: with `chrome: host` the package renders no bottom bar; its sections are
  exposed as a list the host turns into tabs (DESIGN 9.5).
- Filters and sort become rows opening sheets; no chips.
- Delete the three screens with no construction site.

**Acceptance:** ARB parity test; no hard-coded user-facing string (a test scans for string
literals in widget files); widget tests for the list's four states; verify passes.

### P4-11 Mount Events
**Repo:** NUmer. **Depends on:** P4-09, P4-10, P3-10, P3-11. **Executor:** sonnet, high.

Registry entry (`campus`, flag `events`); tabs "Events", "My requests", and for holders of
`events:admin` "Requests" and "Analytics"; a "Remind me" action on an event that writes an
Upcoming item and a local notification; a "Link Telegram" row in the module's menu that
opens the link and shows the result on return; feed event taps open the event.
**Acceptance:** lazy-start test; role-dependent tabs test; size report; screenshots.

---

## Muto (marketplace)

### P4-12 Muto backend: block user, moderation, text filter, account events
**Repo:** Muto. **Depends on:** P2-05, P2-07. **Executor:** opus, high. **Risk:** high.

Guideline 1.2 needs all four:
- Block: `PUT` and `DELETE /api/v1/blocks/{seller_id}`, `GET /api/v1/blocks`; a blocked
  seller's listings and profile disappear for the blocker everywhere; one migration.
- Moderation: operator endpoints to hide a listing, restore it, suspend and unsuspend an
  account, each with a reason and an audit row; a report gets a status (open, actioned,
  dismissed); the reporter's listing view hides the reported listing at once.
- Text filter before publishing: a configurable word list checked on title and description,
  answering a specific validation error.
- Account events handler: delete the user's listings, images, favourites, reports they
  filed, and the user.

**Acceptance:** integration tests for each rule above, including that a suspended user's
listings are hidden and that blocked content is absent from search, suggestions and seller
pages. **Owner (approval):** redeploy.

### P4-13 Muto package: `numer_ui`, host chrome, block and report UI
**Repo:** Muto. **Depends on:** P3-02, P4-12. **Executor:** sonnet, high. **Risk:** high.

`numer_ui` migration in `muto_ui` and `muto_feature`; delete the vendored `app_ui/`; the
token provider on `RemoteAuthState`, scope keyed on the uid; host chrome with tabs instead of
the bottom bar; "New listing" as the floating action; "Block seller" and "Report" as rows in
the listing and seller menus, with a confirm sheet; a blocked-sellers list in the module
menu; operator "Reports" tab gains the hide and suspend actions. Contact channels are rows
with a generic icon and the channel name.

**Acceptance:** verify with its floors; tests for block, unblock, report, and that every
icon-only control has a label; screenshots.

### P4-14 Mount Muto
**Repo:** NUmer. **Depends on:** P4-13, P3-11. **Executor:** sonnet, high.

Registry entry (`campus`, flag `muto`, title "Marketplace"); lazy start; size report (the
image packages are the risk for the budget); verified-student state explained in one
sentence where an unverified address limits what the user sees.

### P4-15 App Review readiness for user content
**Repo:** NUmer. **Depends on:** P4-14. **Executor:** sonnet, medium.

A checklist document `docs/APP_REVIEW.md`: where a reviewer finds report, block, the contact
address and account deletion; the review notes text; the test account steps; the moderation
response time the owner commits to. An in-app "Community rules" screen (text only) linked
from the Muto menu and accepted once before the first listing. The Muto flag stays on the
`allow` list until the owner signs this off.
