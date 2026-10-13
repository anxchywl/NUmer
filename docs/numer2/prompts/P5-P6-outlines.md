# Phase 5 and 6 outlines

Outlines, not prompts. Expand each with `TEMPLATE.md` when its phase starts.

## Phase 5: cross-module polish

### P5-01 Notifications: tap handling, categories, settings
**Depends on:** P3-05. **Executor:** sonnet, high. **Risk:** med.

Today a tapped notification only logs, cold start from a notification is not handled, and
push messages are shown only in the foreground (`lib/core/notifications/notifications.dart:72`,
`lib/features/auth/data/auth_service.dart:257-292`).
- One payload format `{route, args}` for local notifications and push data.
- Handle the three entry paths (foreground tap, background tap, cold start) through
  `rootNavigatorKey`.
- Categories: study sessions, habits, groups (nudges), campus (bookings and event
  reminders), announcements. One switch per category in Settings, stored locally and, for
  push categories, on the user document so the server can respect it.
- `sendNudge` adds the route to its data payload.

**Acceptance:** tests for payload parsing and routing; a manual matrix in the report (three
entry paths by five categories). **Non-goals:** new kinds of notification.

### P5-02 Deletion fan-out drill, end to end
**Depends on:** P4-07, P4-09, P4-12. **Executor:** sonnet, medium.

A script and a checklist: create a test account, create data in every module, delete the
account in the app, then verify through each module's own read-only check that nothing
remains, and that `accountEvents` shows every target delivered. Result recorded in
`docs/APP_REVIEW.md`. **Owner:** runs it in production with a test account.

### P5-03 Campus search
**Depends on:** P4-14. **Executor:** sonnet, medium.

A search field on the Campus root that searches module names locally and, for modules that
declare a search function in their descriptor, their content (events by title, listings by
title), each module answering within its own section of the results. No global index.

### P5-04 Peer stats from aggregates; sessions and courses owner-only
**Depends on:** P0-08, P1-08. **Executor:** opus, high. **Risk:** high.

Group peers still read each other's raw sessions and courses, including courses the owner
hid. Add a per-course, per-day breakdown that excludes hidden courses to the server-written
aggregate; make the member sheet read it; then make `sessions` and `courses` owner-only in
the rules. The rules change degrades older versions' member sheet, so it follows the same
adoption gate as stage 2. **Acceptance:** equivalence test between the sheet's old and new
numbers on a generated history; rules tests.

### P5-05 Optional: avatar glyphs to Material icons
**Depends on:** P3-12, owner's answer to O-6. **Executor:** sonnet, medium.

Map each of the 129 avatar glyphs from the three other icon packages to a Material glyph,
keep the stored index stable, show the mapping table to the owner before merging, then remove
the three packages. Reports the download size saved.

### P5-06 Budgets enforced in CI
**Depends on:** P0-14. **Executor:** sonnet, medium.

A CI job that builds the arm64 release and fails when the download size exceeds the recorded
baseline by more than the budget; the lazy-start tests become required; `docs/PERFORMANCE.md`
gets the current numbers. Startup time stays a manual measurement on the reference device.

---

### P5-07 Bring back course analysis
**Depends on:** P0-04, P1-09, P3-06. **Executor:** sonnet, high. **Risk:** med.
**Owner:** choose the provider and model, create the key, set it as a functions secret.

P0-01 paused the feature: the screen says it is coming soon and no AI code is left.
- New callable `analyzeCourse` in `functions/src/ai/`, model id from a parameter, prompt
  built on the server from `users/{uid}/courses/{courseId}` and that course's sessions, at
  least 20 non-empty notes, per-user daily quota and a global cap in server-only `aiUsage`
  documents with a TTL, verified email required, App Check through `requireAppCheck`.
- Client: the analysis screen with course and period selection, results from the callable,
  failures shown with a localized message, no sample analysis, no sparkle icon or gradient;
  the Study row drops its "Coming soon" label.
- Rules: add `aiUsage` to the server-only deny list.

**Acceptance:** emulator tests for quota, notes threshold and another user's course id;
widget tests for success, failure and quota states; screenshots in both modes, EN and RU.
**Non-goals:** chat, streaming, analysis across courses.

## Phase 6: developer docs

Doc tasks at the end of phases 0 to 3 kept the docs true. These rewrite them for the finished
product. Outlines for the two main files come from the docs audit (`RESEARCH.md` 11).

### P6-01 `AGENTS.md` for the superapp
**Executor:** sonnet, medium.

Sections: purpose and that the rules are binding; Sources of truth (which doc owns what);
Verify before reporting; Repository layout (`lib/app`, `lib/core`, `lib/shared`,
`lib/features`, `packages/numer_ui`, `backend/numer_identity`, `functions`, `infra`);
Dependency rules and the boundary test; Modules (table: repo, package, host folder, flag,
backend, account-events handler); How to add a module (registry entry, host folder, flag,
handler, design mapping, tests); Offline-first contract and which modules are online-only;
State and data models (the frozen `AppState`, Hive typeId table 10 to 20, adapter rules);
Backend and rules (server-only collections, rules tests, functions layout, switches);
Identity and security (token, roles, App Check status, what is never logged); Code style
(the conventions of `DECISIONS.md` section F); Design (`docs/DESIGN.md` is binding);
Localization; Tests and coverage; Commits; Known debt; Agent gotchas.
**Acceptance:** every path it names exists; every command it names runs.

### P6-02 `README.md`
**Executor:** sonnet, low.

Tagline for the superapp; what it is (two paragraphs); download links; modules table with
status; documentation table; short tree; getting started (prerequisites, which Firebase
files a clone needs, run against the emulator); verify; contributing (a link to `AGENTS.md`);
licence and privacy. No command duplicated from `docs/INFRASTRUCTURE.md`.

### P6-03 `docs/PRODUCT.md`
**Executor:** sonnet, medium.

What the app does now, by tab: Home and news, Habits, Study (courses, timers, statistics,
history, course analysis, GPA), Groups, Campus (events, marketplace, piano room), Settings.
Accounts and verification. What works offline and what needs a connection, per area. Who can
see what (peers, operators, editors). Open product questions point to `DECISIONS.md`.

### P6-04 `docs/INFRASTRUCTURE.md`
**Executor:** sonnet, medium.

The single home for commands and operations: setup, environments, verify and CI, run,
release, deploy order; Firebase (data model, rules, functions, switches); backends, identity,
roles, account events; feed; flags; operations (backups, restore tests, monitor, host). No
server detail.

### P6-05 Align each module repo's `AGENTS.md`
**Repos:** Gradus, Clavis, EventsBot, Muto. **Executor:** sonnet, low, one task per repo.

Each keeps its own layering and floors, and gains: the host is NUmer; UI comes from
`numer_ui` and follows NUmer's `docs/DESIGN.md`; the token-provider contract; the Firebase
adapter is the production adapter; the account-events handler; the conventions table from
NUmer's `AGENTS.md` where the repo's own was silent; corrections of the stale claims found
in the inventories (`RESEARCH.md` section 6).

### P6-06 Privacy policy update
**Executor:** sonnet, low. **Owner:** approves and publishes.

A draft that covers the modules: what each stores and where, the email and AI providers,
push tokens, crash reports, how deletion reaches every module, and the contact address.
