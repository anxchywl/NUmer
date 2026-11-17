# NUmer 2.0 decisions

ADR-style log. Evidence lives in `RESEARCH.md`; section numbers below (`R 3.1`) point there.
Task ids (`P0-05`) point to `PLAN.md`.

Each decision carries one status:

- **Confirmed**: a settled decision from the planning brief, kept as written.
- **Changed**: a settled decision the research gave reason to alter. These are the ones to
  read first.
- **Resolved**: an open question from the brief, now decided.
- **New**: a decision the brief did not ask for but the plan needs.
- **Open**: cannot be decided without the owner. Listed again in `USER_ACTIONS.md`.

Priorities used to break ties, in order: stable architecture, low cost relative to value, how
the app feels, visual consistency.

## Changed from the brief, at a glance

| # | Brief | Decision | Why |
|---|---|---|---|
| D-02 | one PostgreSQL cluster, one database and role per module | each module keeps the Postgres it already runs | the modules are live with their own databases; a merge costs risky cutovers and a proxy swap for a negligible memory saving |
| D-03 | Clavis moves from SQLite to Postgres | Clavis stays on SQLite | no user value; it would add a container on a memory-bound host or couple Clavis to another module's database |
| D-10 | NUmer must upgrade to Flutter 3.38.5 before adding any module | the upgrade is already done; the task shrinks to the constraint and the Android toolchain | `.metadata`, `pubspec.lock` |
| D-20 | tabs Home, Study, Campus, Groups, Profile (hypothesis) | tabs Home, Habits, Study, Groups, Campus; Settings opens from an avatar in the header | Habits is a daily check-in and keeps its tab; Settings is not a daily destination and does not need one |
| D-21 | feed sources include new listings, booking reminders, group activity | feed v1 carries announcements and events only; personal items go to a local "Upcoming" block | cost, moderation exposure, and modules must not load at startup |
| D-30 | modules conform to NUmer's icon family | UI chrome moves to Material icons; the avatar catalogue keeps its glyphs until the owner approves changing users' avatars | avatars are user content |
| D-06 | App Check is in place | it is not enforced anywhere; enforcement is rolled out per callable after measuring | `functions/src/index.ts:15` |

New and urgent, not in the brief: **the AI analysis feature is calling a model that was shut
down on 2026-06-01** (D-12). The owner chose to pause it behind a coming-soon screen; that is
the first task.

---

## A. Architecture and backend

### D-01 Hybrid backend. Confirmed.

Firebase keeps Auth, FCM and NUmer's personal offline-first data. Campus modules run as their
own FastAPI services on one VPS behind one reverse proxy. No cross-module SQL.

Evidence: all four backends already run this way (R 6, R 9.1). Firebase stays inside its
free tiers at the current scale once D-13 lands (R 5.1, R 12).

### D-02 Databases: one per module, where they already are. Changed.

The brief asked for one PostgreSQL cluster with a database and role per module. Decision:
EventsBot and Muto keep their own Postgres containers; nothing is merged.

Evidence:
- Every module ships and runs its own Postgres (R 9.1). A merge means a write freeze and a
  dump-and-restore cutover per database, a change of base image with different collation
  behaviour, and a proxy swap that touches unrelated projects on the host (R 9.2).
- An idle module Postgres uses little memory, so the saving from a merge is negligible.
- Isolation is already stronger than "one role per database": separate processes, volumes
  and networks.

The brief's intent is kept: no cross-module joins, separate credentials, separate backups.

Revisit when: a fifth database-backed module is added, or the host is replaced. A new module
may then start on a shared cluster without moving the existing ones.

### D-03 Clavis stays on SQLite. Changed.

Evidence: Clavis has no database URL setting and no Postgres code
(`Clavis/backend/app/config.py:99-103`); one room with at most a few bookings per hour sits
far inside what a single SQLite connection handles; its integrity rule is a partial unique
index that works today (R 6.3). Moving it needs an application rewrite of the store, a data
migration, and either a new container or a dependency on another module's database.

Required instead: its backup gets the same restore test as the others (P2-08).

Revisit when: Clavis needs a second API instance, or write contention is measured.

### D-04 Reverse proxy: keep the existing one. New.

Module APIs stay behind the reverse proxy that already owns ports 80 and 443. No second
proxy is added. The proxy belongs to another project on the same host; that is a recorded
risk, and moving it into its own project is an optional task that needs the owner's approval
(P2-13).

### D-05 One identity. Confirmed, with the details the brief left open.

The global id is the Firebase `uid`. Modules receive a Firebase ID token as the bearer token
and verify it locally.

| Point | Decision | Evidence |
|---|---|---|
| Library | `numer_identity`, a Python package at `backend/numer_identity/` in the NUmer repo | one repo fewer; uv supports a git dependency with a subdirectory |
| Delivery | git dependency pinned by tag (`identity-v<semver>`), built in a Docker builder stage that has `git` | R 7.1 |
| Implementation | PyJWT with the x509 key endpoint, not the Admin SDK | module backends must not hold a Firebase service account |
| Checks | RS256 pinned; `kid`; `iss` and `aud` mandatory; `exp`, `iat`, `auth_time`; `sub` 1 to 128 characters; `email_verified` must be `true`; reject `anonymous` and `custom` providers and any tenant; 30 seconds of leeway | R 3.5 |
| Project id | configuration (`FIREBASE_PROJECT_ID`), asserted non-empty at startup | staging must produce a different `iss` and `aud` |
| Keys | cached for the response `max-age` (clamped to 5 minutes to 24 hours); one refetch per 60 seconds on an unknown `kid`; stale keys served up to 24 hours on fetch failure; cold cache with no keys returns 503, never an accept | R 7.1 |
| Provisioning | by `(issuer, subject)`, never by email | Muto already does this (R 6.5) |
| Revocation | not checked per request. Account deletion and disabling reach modules through signed account events (D-08). A stale token is tolerated for at most one hour | no service account on the VPS |
| Domain rule | `is_verified` for campus-only features means `email_verified` and the address ends with `@nu.edu.kz`; the domain is configuration | Muto and EventsBot already distinguish verified students (R 7.2) |

Client side: every module receives a token provider, `Future<String> Function()`, never a
token string, so an hourly refresh does not rebuild feature state (R 7.4). On a 401 the
module calls `onSessionExpired`; the host forces one refresh and signs out only if that
fails.

### D-06 App Check. New.

App Check is activated on the client in release builds and enforced nowhere (R 1.3).

- New callables that take no authentication (the three password-reset callables) enforce
  App Check from their first deploy; only new app versions call them.
- Existing callables switch to `enforceAppCheck: true` one at a time, each only after the
  Firebase console shows at least 95% of that callable's requests carrying a valid token for
  7 days (owner checks; P1-09 makes the switch per callable).
- Module backends do not verify App Check in 2.0. The ID token is the gate. Revisit if abuse
  appears.

### D-07 Roles. Resolved.

One custom claim, `numer_roles`: an array of `"<module>:<role>"` strings. Values:
`gradus:operator`, `clavis:operator`, `events:admin`, `muto:admin`, `numer:editor` (may
publish announcements), `numer:admin` (may assign roles). Unknown values grant nothing.

- Set only through the Admin SDK: first by a local owner script, then by a callable gated on
  `numer:admin` (P2-02).
- Backends compute the effective role from the claim on every request and never store it.
  EventsBot's stored role remains only for its Telegram surfaces (R 7.3).
- Removing a role also revokes refresh tokens.

### D-08 Account events and deletion fan-out. New.

Deleting or disabling an account in Firebase must reach every module (App Store 5.1.1(v),
R 12).

- Cloud Functions write an event to a server-only queue and deliver it to each module at
  `POST /internal/v1/account-events`.
- Body: `{id, type, issuer, subject, occurredAt}` with `type` of `account.deleted` or
  `account.disabled`.
- Header `X-Numer-Signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of "<t>.<raw body>">`,
  one secret per module, 5-minute tolerance. Handlers are idempotent on `id`.
- Delivery retries with backoff for 72 hours, then alerts.
- The library ships the signature check (P2-07). Each module adds its handler in its
  integration task. A module flag cannot be opened to all users before its handler is live.

### D-09 No core migration off Firestore now. Confirmed, with one open risk.

Cost trigger: the model predicts about 2 USD per month at 200 users and about 20 USD at 2,000
before the fixes, and less after (R 5.1). The 50 USD trigger is far away.

Open risk: Kazakhstan's data-localization rule is in force and, as summarised by secondary
sources, is not satisfied by storage abroad. Whether it applies to this app and its developer
is unknown and needs local legal advice (R 12, rows b1 to b3). Until the owner has that
advice this decision stands, and nothing in the plan makes a later move harder: personal
study data sits behind `storage.dart` and `sync_service.dart`, and module data is already on
a server the owner controls.

### D-10 SDK and dependencies. Changed.

NUmer already runs Flutter 3.38.5 and Dart 3.10.4. Left to do (P0-03):

- `environment: sdk: ^3.10.0`, `flutter: ">=3.38.1"`.
- Android: AGP 8.12.1 or newer in the 8.x line, Gradle 8.13 or newer, Kotlin 2.2.0. Not AGP 9.
- Remove `image_picker`, `animations`, `vector_math` (0 imports). `package_info_plus` stays:
  the minimum-build gate (P0-13) and the version row in Settings need the build number.
- Firebase major versions are **not** bumped in 2.0. Revisit when a store or SDK requirement
  forces it.
- Hive 2.2.3 and `provider` stay.

### D-11 Structure of the host app. New.

- `lib/main.dart` shrinks to an entry point. Bootstrap, root widget, auth gate, shell and
  navigation bars move to `lib/app/` (P0-12).
- No router package. Named routes and a root navigator key are enough for notification and
  feed links. Revisit if web or external deep links become goals.
- `AppState` (2637 lines) is frozen, not decomposed: no new state goes into it. New features
  own a `ChangeNotifier` or service of their own, created lazily.
- Layer violations are tracked by a boundary test with an allow-list that may only shrink
  (P0-02).
- `functions/src/index.ts` is split into one file per area with the same exports (P0-04).

### D-12 AI analysis. New, urgent.

`analyzeCourseAi` calls `gemini-2.0-flash`, shut down on 2026-06-01 (R 2 row 8). The
prompt review also found that the app catches the failure and shows a built-in sample
analysis, so users have been reading invented insights since then.

- Owner decision: the feature is paused. The entry points stay and open a screen with one
  sentence saying it is coming soon; the callable, all Gemini code, the client service, the
  sample analysis and the local analysis cache are removed (P0-01).
- Installed app versions keep showing their built-in sample when the call fails; accepted.
- It returns as P5-07, built clean: a current model chosen by the owner, the prompt built on
  the server from the user's own data, a per-user daily quota and a global cap, verified email
  required, App Check through the P1-09 switch, and failures shown as failures.
- In the UI the feature is labelled as plain text, with no sparkle icon or special styling.

### D-13 Firestore cost. Confirmed, with the design.

`onStudySessionWrite` moves to incremental aggregates: a private per-user state document
with a per-session ledger, about 3 reads per event instead of about 111, behind an
environment flag with a shadow comparison (P0-08, R 5.3). Client-side reductions follow
(P0-09, P0-10, R 5.4). The owner sets a billing budget alert.

---

## B. Security

### D-14 Rules are tightened in two stages. New.

Installed app versions cannot be changed, and no forced-update gate exists (R 4.5). A check
of the client's write paths showed which fixes would break them: group create and join write
`groupIds` inside an awaited batch, timer start and stop await a write of the active session
to the user document, and sign-up awaits a write to `email_index`. So the fixes are split by
whether an installed version survives them.

**Stage 1 (P0-06), safe for every installed version:**
- Peer access no longer trusts the client-written `groupIds`. The rules read a
  server-maintained membership index instead (D-15). Old versions keep writing `groupIds`;
  it simply stops mattering (fixes H1).
- Group membership: member payload validated; `role` is `member` on join and `admin` only
  for the creator at creation; only the creator changes roles; `createdBy` immutable; admin
  updates limited to four fields; `memberCount` moves by exactly one (fixes C1, L2). With
  roles no longer forgeable, the catch-all delete inside a group is limited to real admins;
  it is removed in stage 2 because an old version's account deletion can still use it.
- `users/{uid}`: `list` denied; `get` requires sign-in (stops the unauthenticated dump).
- `email_index`: `get` and `list` denied; a write must target the caller's own token email
  (stops enumeration and the overwrite attack; old versions keep working, and their reset
  flow already falls back when the read fails).
- `users/{uid}/aggregates`: readable by the owner and real co-members only (fixes H5).
- `/nudges`: the receiver may read and may set `status` to `delivered` (fixes L3).
- Session writes validated for type and range (fixes M5).
- New server-only collections denied explicitly.

**Stage 2 (P1-08), deployed only after the owner confirms at least 90% of weekly active
users run a version that contains P0-11 and P1-06:**
- `users/{uid}` readable by its owner only; peers read `publicProfiles/{uid}`.
- Every write requires a verified email.
- `email_index` closed and its data deleted.
- The catch-all delete inside a group removed; group deletion is server-side only.

What stage 2 costs the remaining old versions: their leaderboards lose live names and
avatars for other members (they fall back to the aggregate copy), and a sign-up made on an
old version reports a false error. Both affect only people who have not updated.

Not done, on purpose: denying client writes to `groupIds`, `email` or `emailVerified` on the
user document. Nothing reads them for authorization after stage 1, and denying them breaks
group create, join and first sign-in on old versions. `nudgeCooldowns` also stays
owner-writable; the real limit moves to the server (D-16).

Peer access to raw sessions and courses stays limited to real co-members. Moving peer detail
fully onto aggregates is a later task (P5-04).

### D-15 Membership index and public profiles. New.

Two server-written collections, both maintained by Cloud Functions triggers so they work for
old and new app versions alike (P0-05):

- `groupIndex/{uid}`: `{groupIds: [...]}`, maintained from `groups/{g}/members/{uid}` create
  and delete. Membership documents are the truth: a private group's member document can only
  be created by the join callable. The rules' shared-group check reads this index for both
  users. A backfill script fills it before the rules are deployed.
- `publicProfiles/{uid}`: what co-members may see: name, avatar fields, major, goal, contact
  line, study presence (without the device id) and the two nudge switches. Mirrored from
  `users/{uid}` only when one of those fields changes. Readable by the owner and co-members.

Email, device id, settings and tokens never leave `users/{uid}`.

### D-16 Callables. New.

All callable ids pass one validator. `getMemberSubjectStats` (no caller) and the empty
`deleteGroup` trigger are deleted. `sendNudge` gets a server-side cooldown and a bounded
sender name. `joinPrivateGroup` gets attempt limits and a minimum length for new codes
(P0-07). Internal error text is no longer returned.

### D-17 Account deletion. New.

Order: write a deletion marker, disable the auth user and revoke tokens, delete data
(including `email_index`, nudges, auth codes, public profile), delete the auth user, emit
the account event (D-08). Triggers return early for marked or missing users and never
re-create a document. The work after disabling runs in a retried trigger, so an interrupted
deletion finishes by itself, and a daily sweep removes anything another signed-in device
wrote before its token expired. The client-side fallback deletion is removed (P1-07). A
recent sign-in is required from versions that can re-authenticate.

---

## C. Auth rework

### D-18 Email codes. Confirmed, with the details.

| Point | Decision |
|---|---|
| Callables | `sendEmailVerificationCode`, `verifyEmailCode`, `requestPasswordResetCode`, `verifyPasswordResetCode`, `confirmPasswordReset` |
| Code | 6 digits from `crypto.randomInt`; stored as HMAC-SHA256 with a Secret Manager key and a `keyVersion`; 10-minute life; single use; 5 attempts; a new send replaces the old code |
| Verify | inside a Firestore transaction; attempts incremented before the result is known |
| Reset | code verification returns a single-use `resetTicket` (10 minutes); completion sets the password, marks the email verified and revokes refresh tokens |
| Enumeration | reset request always answers the same; the email is sent by a queue trigger so latency does not depend on whether the account exists. Sign-up still reveals an existing address (a Firebase limit); accepted |
| Limits | 3 sends per address per 15 minutes and 10 per day; 5 per uid per hour; 10 per IP per hour; 15 failed verifies per address per day; a 2,000 per day global breaker; 60-second resend cooldown reported by the server |
| Storage | `authCodes`, `authRateLimits`, `mailQueue`, `authAudit`: server-only, with TTL policies |
| Verification send | inline in the callable (the caller is authenticated, so there is nothing to hide, and a failed send can be reported) |
| IP | secondary signal only, hashed; the trusted source is measured on staging before it is relied on |
| Squatting | a reset by code verifies the address and replaces the password, so the real owner can always take the account back. No purge job |
| Old versions | Firebase's link emails stay enabled until old versions are gone |
| Region and API | same region and v1 API style as the existing functions |

Evidence: R 4.

### D-19 Email delivery. Resolved.

- Sending goes through one `MailSender` interface with a single HTTPS implementation, so the
  provider can change without touching the callables.
- Templates: one layout, EN, RU and KK, HTML with inline styles plus a plain-text part. The
  subject never contains the code. No links, no images, no tracking.
- Sender: a dedicated subdomain of a domain the owner controls, with SPF, DKIM and DMARC.
- Provider: Resend. Its free tier is 3,000 emails a month, capped at 100 a day (checked
  2026-11-27); move to Pro once daily sign-ups and resets approach the cap.
- Domain: `mail.anxchywl.dev`, a subdomain of a domain the owner already uses elsewhere, so
  its own `_dmarc.mail` record leaves the root domain's policy alone. Delivery to
  `@nu.edu.kz` is tested before release (`USER_ACTIONS.md`).
- From: `NUmer <no-reply@mail.anxchywl.dev>` (owner, 2026-11-27).

---

## D. Product structure

### D-20 Information architecture. Resolved; differs from the hypothesis.

Five tabs, in this order:

| Slot | Today | NUmer 2.0 | Contents |
|---|---|---|---|
| 1 | Home (course list, timers) | **Home** | streak, running session, today summary with a one-tap way back into the last course, upcoming, news |
| 2 | Habits | **Habits** | unchanged |
| 3 | Statistics | **Study** | the course list with its timer sheet (moved from Home), then rows for Statistics, History, Course analysis and GPA (Gradus) |
| 4 | Groups | **Groups** | unchanged |
| 5 | Account (titled "Settings") | **Campus** | events, marketplace, piano room, and every future campus module |

Settings (profile, appearance, language, switches, export, delete account) opens from the
user's avatar at the top right of every tab root.

What moves, stated plainly:
- The course list and its timer sheet move from Home to Study, as the brief's hypothesis
  intended. To keep the core loop as fast as it is today, Home shows "Continue <last
  course>", which opens that course's timer sheet in one tap, and a "Start" action that
  opens a course picker.
- Statistics becomes a screen opened from Study instead of a tab.
- Settings moves from the fifth tab to the avatar.
- Habits and Groups do not move.

Why Habits keeps a tab and Settings does not (the difference from the hypothesis, which had
Home, Study, Campus, Groups, Profile):
- Habits is a daily check-in with its own date strip and list; under a "Study" label it
  would sit one level down behind a word that does not describe it (habits are not only
  about study).
- Habits is the largest feature by interface code (R 1.2), the only usage evidence available;
  there is no analytics.
- The fifth tab today is a settings screen. Settings is rarely a daily destination, and an
  avatar entry is a standard place for it.

Facts from the screen inventory that the shell tasks must handle:
- `/timer` and `/alarms` are registered routes that nothing navigates to; alarms have no
  visible entry point today. They get no entry in 2.0 and are listed as dead code to remove.
- Tapping a notification does nothing today (the handler only logs), and the app has no
  navigator key. P0-12 adds the key; P5-01 adds the handling.
- Settings has no privacy policy link, support contact or version. An "About" section is
  added with the shell (P3-05), which guideline 1.2 also needs.

How a future module is added without touching navigation: a module is one entry in a
registry (id, title key, icon, section `study` or `campus`, flag key, lazy builder). The
Campus and Study tabs render registry entries as list rows. A new module is one registry
entry plus one feature folder.

Modules open as full-screen routes above the shell, so the tab bar is hidden inside a module
and there is never a second bottom bar. A module's own sections (for example Browse,
Favorites, My listings) become text tabs under its app bar.

The owner should confirm this layout before P3-05; switching to the hypothesis later costs
one registry edit and one shell task.

### D-21 News feed. Resolved.

| Question | Decision |
|---|---|
| Sources in v1 | announcements written by editors, and approved upcoming events from the Events backend |
| Not in v1 | marketplace listings (user content on the most visible surface raises moderation exposure and noise), group activity (per-user fan-out cost) |
| Personal items | piano bookings and event reminders go to an "Upcoming" block on Home, read from a local store that a module writes when the user books or sets a reminder. No network, works offline, and no module loads at startup |
| Who publishes | holders of `numer:editor`, through a callable; events flow in automatically after Events moderation |
| Where stored | `announcements/{id}` (source of truth, server-written) and one composed document `feed/current` with at most 30 items |
| Composition | a scheduled function every 30 minutes merges announcements with the Events public list; it also runs when an announcement is published |
| Ranking | pinned announcements first (at most 2), then newest first by publish time. Ended events drop out. No personalisation |
| Cost | one document read per refresh; the client refreshes at most every 30 minutes and shows the cached copy first |
| Language | announcements carry EN, RU and KK text with EN as fallback; event text is shown as written |
| Rules | `feed` readable by signed-in users, never client-writable |

### D-22 Telegram linking for Events. Resolved.

- Automatic: a Firebase user with a verified `@nu.edu.kz` address is attached to the one
  Events user that verified the same address.
- Explicit: NUmer asks the Events backend for a one-time link (10 minutes, stored in Redis)
  and opens `t.me/<bot>?start=link_<code>`. The bot shows the masked NUmer email and asks
  for confirmation before attaching the identity.
- A Firebase-provisioned Events user that already has content is never merged automatically;
  the endpoint answers 409.
- Roles for NUmer sessions come only from claims (D-07), so linking never transfers an admin
  role.
- Linking is optional. Without it a student still browses events and submits requests.

### D-23 Feature flags. Resolved.

One Firestore document, `config/app`, readable by signed-in users and writable only from the
console or Admin SDK:

```
minSupportedBuild: int
modules: { <id>: { enabled: bool, rollout: 0..100, allow: [uid], minBuild: int } }
```

- Compiled-in defaults turn every module off, so a missing document fails closed.
- A module is visible when `enabled`, the build is at least `minBuild`, and the uid is in
  `allow` or `hash(uid) % 100 < rollout`.
- Read once per cold start after the first frame, cached locally, so a module never blocks
  startup.
- `minSupportedBuild` drives an update-required screen. It binds only versions that contain
  it.

Why not Remote Config: no new SDK, the same offline cache and rules model as the rest of the
app, an allow-list by uid for testers, and it works on the staging project and the emulator
unchanged.

### D-24 Module order and packaging. Confirmed, with packaging decided.

Order: Gradus, Clavis, Events, Muto.

- Feature packages stay in their module repos, with their backends and standalone dev hosts.
  NUmer depends on each by git, pinned to a tag.
- Each feature package depends on `numer_ui` by git; the NUmer app overrides it to the local
  path with `dependency_overrides`.
- Each module is mounted from a thin host feature folder, `lib/features/<module>/`, that owns
  the registry entry, session wiring and any host adapters.
- A module initialises on first open: no HTTP call, storage read or controller is created
  before that.

### D-25 Gradus merge. Confirmed, refined.

Grades do not go on the course document, because group peers can read it (R 10.3). They go
into new owner-only records:

| Record | Hive typeId | Firestore path |
|---|---|---|
| `LocalCourseGrade` (semester id, letter, assignments) | 18 | `users/{uid}/courseGrades/{courseId}` |
| `LocalAssignment` (embedded) | 19 | inside the grade record |
| `LocalSemester` | 20 | `users/{uid}/semesters/{semesterId}` |

`LocalCourse` gains one optional appended field, `code`. A course created in Gradus is a
normal NUmer course with no timetable slot and `hiddenFromLeaderboard: true`. The Gradus
backend stays only for syllabus parsing. The host supplies the `TranscriptRepository` over
Hive; Gradus's `SharedPreferences` repository is not used in NUmer.

### D-26 Events scope in NUmer. New.

The Flutter Events package today is a coordinator and submitter interface; favourites,
reminders and registration exist only for the Telegram Mini App (R 6.4). Version one in
NUmer: browse, event detail, a local reminder, submit a request, my requests, and the
coordinator screens for holders of `events:admin`. The Mini App and bot are untouched.

### D-27 Muto before App Review. Confirmed.

Muto is not opened to all users until it has: block user, a report path with an operator who
can hide a listing and suspend an account, a pre-publication text filter, and published
contact information (guideline 1.2, R 12 row c1). These are tasks in its integration group.

---

## E. Design system

### D-28 One UI package. Resolved.

`numer_ui` at `packages/numer_ui/` in the NUmer repo replaces the four `app_ui` copies.

- Base: the Gradus and Clavis line (tested, accessible, no product widgets), plus Clavis's
  `toolbarHeight`, plus Muto's sheet `useRootNavigator`, search tooltips and six icons.
- Colours come from the host `ColorScheme`; the hard-coded purple and the font name are
  removed.
- The module-facing names (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppIcons`, the
  buttons, fields and sheets) are kept as a compatibility layer so module code changes
  little.
- Dropped: product widgets no one uses, the second spacing and radius scales, dead SVG
  references, `google_fonts`, `flutter_svg`, `lucide_flutter`, `simple_icons`.

### D-29 Design language. Resolved.

`DESIGN.md` is binding for every UI task. It keeps the current look (Material 3 from the
user's accent, system font, flat surfaces) and fixes the scale: one type scale, a 4 pt
spacing grid, four radii, no elevation, three durations.

Existing screens are not restyled wholesale. A screen is brought to the tokens when a task
touches it, plus one targeted pass that removes what the rules forbid (P3-12).

### D-30 Icons. Changed in scope.

One family: Material icons, outlined by default and filled for a selected state.

- All interface chrome, including every module, uses Material icons. The modules' `AppIcons`
  names are remapped onto Material glyphs inside `numer_ui`.
- Brand marks (Telegram, WhatsApp) become a generic Material glyph next to the brand name in
  text.
- The avatar catalogue (129 glyphs from three other packages, chosen by users) is content,
  not chrome. It keeps its glyphs in 2.0. Replacing them changes how existing users'
  avatars look, so it is an optional task that needs the owner's approval (P5-05).
- Habit icons persisted by users are left as stored.

### D-31 Glass and gradients. New.

The floating iOS navigation bar stays as it is. Every other blur and decorative gradient is
removed: the duplicated glass action pill on Home and Habits, and the gradients on the auth
screen and the old AI analysis screen (R 8.3, R 8.4). The colour picker's hue gradient stays because it is
functional.

### D-32 Budgets. New.

- Cold start: no official target exists. P0-14 records the baseline on a mid-range Android
  device in profile mode; from then on a release may not exceed the baseline by more than
  10%, and enabling a module may not change it.
- Frames: 99th percentile build plus raster time at most 16 ms while scrolling Home, the
  feed and a module list.
- Size: each module may add at most 1.0 MB to the arm64 release download; NUmer 2.0 as a
  whole at most 4.0 MB over the P0-14 baseline. Numbers are revisited once after the first
  measurement.

---

## F. Engineering conventions (binding in every repo)

NUmer's rules come first; the module repos' rules are merged in where NUmer had none.

| Topic | Rule |
|---|---|
| Comments | only where the why is not obvious; all lowercase; one line; no trailing punctuation; never describe what the code does; no docstrings or block comments. Existing comments are fixed only in files a task already edits |
| Language | English for code, comments, docs and commits |
| Commits | conventional prefix (`feat`, `fix`, `refactor`, `docs`, `chore`, `test`), lowercase, imperative, no period, subject line only, no trailers |
| Shape | follow the file's existing patterns; early returns; small single-purpose functions; short descriptive names; `lower_snake_case.dart` with `*_screen.dart`, `*_service.dart`, `*_sheet.dart` suffixes |
| Leftovers | no debug prints, commented-out code, temporary variables or emoji |
| Errors | catch the specific failure you handle; never catch broadly or swallow |
| Scope | no unrequested features, abstractions, dependencies or error handling; edit existing files where possible |
| Structure (NUmer) | feature-first; a feature is imported only through its barrel; direction is `features -> core -> shared`; `packages/numer_ui` imports nothing from `lib/` |
| Structure (modules) | each keeps its own layering (domain, application, data, presentation) inside its package; the host imports a module only through its public entry; a module never imports the host |
| Offline-first | UI never writes Firestore; mutate Hive through `storage.dart` with `dirty = true`; modules that are online-only say so in their host feature folder |
| Hive | adapters are hand-written and positional; never renumber a typeId or reorder writes; a new field is an appended write and a guarded read; new types take the next free id (18 onward) |
| Strings | every user-facing string in EN, RU and KK; key parity is checked by the verify script; copy rules in `DESIGN.md` |
| UI | only `DESIGN.md` tokens and components; no new colours, radii, fonts or icon packages; every icon-only control has a tooltip or semantics label |
| Tests | `flutter_test` with hand-written fakes, no mocking package; tests mirror the source tree; functions and rules are tested against the emulator |
| Coverage | NUmer: the floor is the baseline measured in P0-02, rounded down, and may only rise. Module repos keep their own floors |
| Verify | `./scripts/verify.sh` in every repo; its header lists what it does not run; a task is not done until it passes |
| Secrets | none in code or `--dart-define`; development mechanisms are refused when `APP_ENV=production` |
| Docs | each doc owns its subject once; a change that makes `AGENTS.md`, `README.md` or `docs/*` wrong fixes them in the same commit |
| Servers | no executor connects to a server; server work is delivered as scripts and a runbook that the owner runs |

---

## G. Owner answers (2026-11-27)

| # | Question | Answer | Blocks |
|---|---|---|---|
| O-1 | Confirm the tab layout in D-20 | yes, the D-20 layout | P3-05 |
| O-2 | Email provider and sending domain (D-19) | Resend, `mail.anxchywl.dev` | P1-01 |
| O-3 | Legal advice on data localization (D-09) | not sought; the risk stays open | nothing in the plan |
| O-4 | Is the Events bot process meant to be running in production? | yes | P4 Events tasks |
| O-5 | Did Gradus ship standalone with real user data? Does Clavis hold bookings under old student ids? | no to both; no import step | the import step in the Gradus and Clavis tasks |
| O-6 | Replace users' avatar glyphs with Material ones (D-30)? | no, keep the glyphs | P5-05 |
| O-7 | Add crash reporting (a new SDK and a privacy-policy line)? | yes, Crashlytics | P0-14 |
| O-8 | Target device for the performance baseline | Samsung Galaxy S23 | P0-14 |

---

## H. Phase 3 expansion (2026-11-27)

Decisions taken while expanding the phase 3 outlines into prompts, from the code on `main`
at `5a6359c`.

### D-33 File size limit. New (owner, 2026-11-27).

- **Decision:** a source file stays under 400 lines and a function under about 60 (`AGENTS.md`
  "Size"). `scripts/check_file_size.sh`, run by `verify.sh`, enforces it. The 33 files in
  `scripts/file_size_baseline.txt` predate the rule and may only shrink; a commit that shrinks
  one lowers its entry, and a commit that splits one away removes it.
- **Why:** the largest files (`home.dart` 3098, `stats.dart` 3228, `add_habit_sheet.dart`
  2462) cannot be reviewed or changed by an executor in one session, and every phase 3 task
  touches them.
- **Consequences:** phase 3 gains three pure splits, P3-14 (`stats.dart`), P3-15
  (`add_habit_sheet.dart`) and P3-16 (`habits_screen.dart`); P3-04 and P3-05 end with the
  files they touch under the limit. A split keeps the big `State` class at its original path,
  so when a class cannot get under 400 lines without changing how its state is shared, the
  file stays in the baseline at its new, lower size. A new path is never added to the
  baseline; if a split needs that, the executor stops and asks.

| # | Decision | Why |
|---|---|---|
| D-34 | Homes: course list, add, edit, goal popup in `courses/widgets/`; time sheet, active session bar, auto-finish watcher in `sessions/widgets/`; new features `study`, `campus`, `news`; `ModuleDescriptor` in `lib/core/modules/` (features cannot import `lib/app/`); the Upcoming store in `lib/core/upcoming/`; `ShellHeader` in `account` | feature-first layout and the boundary test |
| D-35 | Until P3-06 the Study root is two rows (Statistics, History) pushing the existing screens, not the Statistics content under a new header | `StatsScreen` works unchanged as a pushed screen; no temporary mode in it |
| D-36 | P3-05 deletes the timer and alarm screens and the alarm code in `AppState`; on load it cancels the notifications of any stored alarm and clears `alarms_v1` once | nothing in this repository's history navigates to alarms; a stored alarm would fire with no way to remove it |
| D-37 | Feed events come from the Events public list `/api/events` (no auth), which has no publish time: an event's `publishedAt` is when the composer first saw it, carried over from the previous `feed/current`; `startsAt` reads `date` and `time` as UTC+05:00. Announcement titles at most 100 characters, bodies 400 per language, to keep the document under 100 KB | resolves P3-08's stop condition |
| D-38 | P3-01 ships component images from a tagged widget test instead of an `example/` app; the bottom sheet theme does not set `showDragHandle` | the P1-03 precedent; existing sheets draw their own handle |
| D-39 | `DESIGN.md` 9.1 extended for `app_ui` colours in module use and missing from it: `grey`, `iconSecondary` to `onSurfaceVariant`; `white` to `onPrimary`; `black`, `iconPrimary` to `onSurface`; `lightGrey` to `outlineVariant`; `orange` to `warning`; `green` to `success`; `blue` to `primary`; `blueLight`, `infoLight` to `primaryContainer`; `errorLight` to `errorContainer`; `successLight`, `warningLight` to `surfaceContainerHighest`; `iconDisabled` to `onSurface` at 0.38 | together 200 call sites; without a row the executor would guess |
| D-40 | News and Upcoming open module screens through a host hook `bool Function(BuildContext, item)` that returns false until a module fills it (P4-08, P4-11); an event then opens a detail built from the feed item | no module exists in phase 3; the descriptor stays small |
| D-41 | The design pass is two tasks: P3-12 replaces glass, the auth gradient, mode chips, segmented pills, raw snack bars, a card shadow and the Kazakh font branches; P3-17 turns confirmations into confirm sheets and list spinners into skeletons. P3-13 depends on P3-17 | about 40 files in one task is beyond one executor session; the two halves touch different patterns |
