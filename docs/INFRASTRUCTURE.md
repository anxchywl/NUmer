# Infrastructure

How NUmer runs and ships. For *what it does* see [PRODUCT.md](PRODUCT.md); for *where code
lives and how it's organized* see [AGENTS.md](../AGENTS.md). This file is the single source of
truth for the runtime system, backend, and build/deploy.

## Architecture — offline-first client/server

```mermaid
graph TD
    UI[Flutter UI / feature screens] -->|read / write| State[AppState provider]
    State -->|local mutations| DB[(Hive local DB)]
    State -->|controls| Sync[SyncService]
    Sync -->|push dirty / pull new| FS[(Cloud Firestore)]
    FS -->|triggers| Fn[Cloud Functions]
    Fn -->|FCM push| FCM[Cloud Messaging]
```

The app stores **everything locally in Hive first**. Local entities are marked `dirty` on
change and `SyncService` pushes them to Firestore when online. A local change only pushes. Remote
changes since the last sync timestamp are pulled on launch, on first bootstrap, on a manual sync
and on resume when the last pull is at least 10 minutes old (or none has happened yet). A reconnect
runs a full pull if none has happened in this session or the session began with a bootstrap. There
is no background timer. A sync requested while another is running runs after it. It also runs a
heartbeat to claim/verify active timers across devices.
Data flow, end to end:

1. User acts in a feature screen → mutates `AppState`.
2. `AppState` writes to Hive via `core/data/storage.dart` (`dirty = true`, `updatedAt` set).
3. `SyncService` uploads dirty records to Firestore.
4. A Firestore trigger (e.g. `onStudySessionWrite`) recomputes group aggregates/leaderboards.
5. Updated aggregates stream back and render in the group dashboard.

**Never write to Firestore directly from UI** — always go through Hive + `SyncService`.

## Client stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK ≥ 3.4.0) |
| State management | `provider` + `ChangeNotifier` (`app/app_state.dart`) |
| Local persistence | `hive` / `hive_flutter` + `shared_preferences` |
| Charts / calendar | `fl_chart`, `table_calendar` |
| Notifications | `flutter_local_notifications`, `firebase_messaging`, `timezone` |
| Export | `excel` (`.xlsx`), plus `.csv` / `.ics` generation |
| Firebase SDKs | `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_messaging`, `firebase_app_check` |

App version: `1.0.3+32` (see `pubspec.yaml`). Icons are generated via
`flutter_launcher_icons` from `assets/icon/app_icon.png`.

## Firebase

Project: **`numer-60744`** (see `.firebaserc`, `firebase.json`).

- **Auth** — email/password with verification.
- **Firestore** — primary cloud store (rules in `firestore/firestore.rules`, indexes in
  `firestore/firestore.indexes.json`; paths wired via `firebase.json`).
- **Cloud Functions** — Node.js 20 / TypeScript in `functions/` (source `functions/src/`, one folder per area,
  re-exported by `functions/src/index.ts`).
- **Cloud Messaging (FCM)** — nudge push notifications.
- **App Check** — activated by the app in release; debug provider in debug builds (`main.dart`).
  Cloud Functions enforce it only for the callables listed in the configuration below.
- Dart config generated at `lib/core/firebase_options.dart` (wired via the `flutter` block in
  `firebase.json`).

### Firestore data model

Top-level collections and the per-user subcollection tree (owner read/write unless shared via
a group; see `firestore.rules` for exact access):

```
/groups/{groupId}                      group metadata
  /members, /invites, /secrets, /aggregates, /stats, /leaderboard
/users/{userId}                        profile (name, major, goals, prefs)
/email_index/{emailId}                 email → uid lookup
/mailQueue/{id}                        outgoing email, server only
/groupIndex/{userId}                   server-written: groups the user belongs to
/publicProfiles/{userId}               server-written: profile fields group peers may see
/nudgeLimits, /joinAttempts            server-only rate limit counters
/roleAudit/{entryId}                   role change log, server only
/users/{userId}/
  fcmTokens, aggregates, aggState (server only), sessions, studySessions, courses, studyTimes,
  courseGoals, courseProgress, goals, reflections, preferences, aiLogs,
  stats, meta, groupMemberships, nudgeCooldowns,
  habits (+ /history), habit_categories, connections, connectionGroups
```

### Cloud Functions (`functions/src/`)

| Type | Name | Purpose |
|------|------|---------|
| Firestore trigger | `onStudySessionWrite` | Recompute user/group aggregates on session change |
| Firestore trigger | `onCourseWrite` | Recompute aggregates when course visibility changes |
| Firestore trigger | `onGroupMemberDelete` | Clean up membership associations |
| Firestore trigger | `onMailQueued` | Render and send a queued email |
| Firestore trigger | `onGroupMemberWrite` | Maintain `groupIndex` from member create and delete |
| Firestore trigger | `onUserProfileWrite` | Mirror public profile fields into `publicProfiles` |
| Callable | `deleteGroupCallable` | Recursively delete group, members, aggregates |
| Callable | `deleteAccountCallable` | Delete auth user + subcollections + memberships |
| Callable | `joinPrivateGroup` | Transactionally validate join code and add member |
| Callable | `sendNudge` | Persist nudge + FCM push with localized phrase |
| Callable | `setUserRoles` | Administrator sets a user's module roles (see below) |

Callables enforce authentication. App Check is off by default and switched on per callable:
list export names, comma-separated, in `APPCHECK_ENFORCED` in `functions/.env` (`*` means all;
`functions/.env.example` shows the key), then deploy functions. A listed callable rejects a
request without a valid App Check token with `failed-precondition` and reason `app-check`.

Transactional email (`functions/src/mail/`) renders the `verify`, `reset` and
`passwordChanged` templates in EN, RU and KK. Callers send through `MailSender`, or queue with
`enqueueMail` when they must not wait for delivery. A delivered entry is deleted. A failed one
is stripped of its address and code.

Module roles live only in the `numer_roles` custom claim of the Firebase ID token, which
reaches a client on its next token refresh. Allowed values are listed in
`functions/src/roles/roles.ts`. The first administrator is created locally with
`npm run roles:set -- --uid <uid> --roles <comma list> [--dry-run]` in `functions/` (needs
`GOOGLE_APPLICATION_CREDENTIALS`); afterwards administrators call `setUserRoles`, which
requires `numer:admin` in both the caller's token and their current claims. Removing a
role revokes the user's refresh tokens. `setUserRoles` logs each call to `roleAudit`, which
clients cannot access; the script does not.

`AGG_INCREMENTAL` (`on` or `off`, default `off`) switches the two aggregate triggers from the
full recompute to a per-user ledger in the private `users/{uid}/aggState/v1`, which costs about
3 reads per event instead of about 111. With the switch `off`, `AGG_SHADOW_PERCENT` (0 to 100,
default 0) also runs that share of users through the ledger without publishing and logs
`aggregate_shadow_mismatch` when its payload differs; both are set in `functions/.env`
(see `functions/.env.example`).

AI course analysis is paused: its callable has been removed and the app shows a coming-soon
screen.

## Native platforms

- **iOS** (`ios/`) — includes the **Session Live Activity** widget extension
  (`ios/SessionLiveActivityExtension/`) and shared attributes (`ios/Shared/`), logically owned
  by the `sessions` feature (see `lib/features/sessions/README.md`).
- **Android** (`android/`) — adaptive launcher icons, `minSdk 21`.
- **macOS** (`macos/`).

Native project files (`Podfile`, `*.xcodeproj/xcworkspace`, Gradle, `google-services.json`,
`GoogleService-Info.plist`) are tool-owned — do not restructure them.

## Localization

`flutter gen-l10n` (config in `l10n.yaml`) generates `lib/l10n/app_localizations*.dart` from
ARB files `app_en.arb` (template), `app_ru.arb`, `app_kk.arb`. Retrieve strings via
`AppLocalizations.of(context)`. Generated Dart is not hand-edited.

## Build, run, deploy

```bash
# setup
flutter pub get
(cd functions && npm install)

# run the app (simulator/emulator running)
flutter run

# quality gates, the script header lists what it does not run
./scripts/verify.sh

# release builds
flutter build ios
flutter build android
flutter build macos

# Cloud Functions: local emulator
(cd functions && npm run build) && firebase emulators:start --only functions,firestore,auth

# Cloud Functions: unit tests, then rules and emulator tests (needs Java 21)
(cd functions && npm test)
(cd functions && npm run test:emulator)

# deploy
firebase deploy --only firestore:rules
firebase deploy --only functions
```

### CI
- `.github/workflows/ci.yml` runs `./scripts/verify.sh` and the host script tests on pull
  requests and pushes to `main`.
- `.github/workflows/identity.yml` runs `backend/numer_identity/scripts/verify.sh` (ruff,
  mypy strict, pytest with a 95% coverage floor) on Python 3.12 when a pull request or a
  push to `main` touches `backend/numer_identity/**`.

### Secrets & config
- Platform Firebase config files (`google-services.json`, `GoogleService-Info.plist`) live in
  their platform dirs and are git-ignored.
- `MAIL_API_KEY` is a Secret Manager secret bound to `onMailQueued`; it must exist in a
  project before functions are deployed there.
- `MAIL_FROM` and `MAIL_PROVIDER` (`resend`, or `console` outside production) come from a
  git-ignored `functions/.env.<project id>`; `functions/.env.example` lists them.
- Send a test email with `(cd functions && npm run build && npm run mail:test -- --to
  <address> --template verify --locale en)`, with the three variables in the environment.

## Key files
- App state: `lib/app/app_state.dart`
- Local storage / sync: `lib/core/data/storage.dart`, `lib/core/data/sync_service.dart`
- Notifications: `lib/core/notifications/`
- Backend: `functions/src/`, `firestore/firestore.rules`, `firebase.json`
- Module backend token verification: `backend/numer_identity/` (see its README)

## Known follow-ups (technical debt)

Deferred intentionally to keep the shipping app stable — tackle incrementally:

- Decompose the large `app/app_state.dart` `ChangeNotifier` into per-feature controllers.
- Split `main.dart` into `app/bootstrap.dart`, `app/router.dart`, `app/app.dart`.
- Break `core/data/storage.dart`'s imports of feature models (`courses`, `habits`,
  `sessions`) so `core` no longer imports a feature.
- Repair and unskip `test/features/account/accent_color_picker_test.dart` (pre-existing
  failure — slider-label assertions no longer match the widget).
