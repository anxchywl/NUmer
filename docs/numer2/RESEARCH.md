# NUmer 2.0 research dossier

Compiled 2026-11-27 from 18 research reports (5 inventories, 12 deep dives, 1 server audit).
Nothing was built or run; every claim below comes from reading code or a cited web page.
`UNKNOWN` marks what the research could not establish.

Citation style: `path:line` is relative to the NUmer repo root. Module citations are prefixed
with the repo name (`Muto/backend/...`). Short names used throughout:

- `rules` = `firestore/firestore.rules`
- `fn` = `functions/src/index.ts`
- `auth_service` = `lib/features/auth/data/auth_service.dart`
- `sync_service` = `lib/core/data/sync_service.dart`
- `group_service` = `lib/features/groups/data/group_service.dart`

Server details are deliberately absent from this file. Capacity conclusions are stated in
general terms in section 9.

Contents:

1. Host app (NUmer) as it is today
2. Corrections to the planning brief
3. Security findings
4. Auth today and the email-code design
5. Firestore cost
6. Modules
7. Identity integration seams
8. Design package and current style
9. Infrastructure
10. Gradus merge
11. Docs audit
12. Fact-check table
13. Design research
14. Open unknowns

---

## 1. Host app (NUmer) as it is today

### 1.1 Toolchain and dependencies

| Item | Value | Evidence |
|---|---|---|
| Flutter / Dart | 3.38.5 / 3.10.4 (stable, revision `f6ff1529`) | `.metadata:7-8`, `pubspec.lock:1069-1071` |
| pubspec SDK constraint | `>=3.4.0 <4.0.0`, no `flutter:` constraint (stale) | `pubspec.yaml:8-9` |
| App version | 1.0.3+32 | `pubspec.yaml:5` |
| State | `provider` 6.1.5+1, 33 files, 219 usage hits | `pubspec.lock` |
| Local DB | `hive` 2.2.3, `hive_flutter` 1.1.0, hand-written adapters, typeIds 10 to 17 | `lib/core/data/entities.dart:559-876` |
| Firebase | core 4.5.0, auth 6.2.0, firestore 6.1.3, functions 6.0.7, messaging 16.1.2, app_check 0.4.1+5 | `pubspec.lock` |
| Android | AGP 8.9.1, Kotlin 2.1.0, Gradle 8.12, Java 17 | `android/settings.gradle.kts:23-28`, `android/gradle/wrapper/gradle-wrapper.properties:6` |
| iOS | Podfile 15.0, Live Activity target 16.1, Firebase iOS SDK 12.9.0 | `ios/Podfile:2,74`, `ios/Podfile.lock:1211-1216` |
| Functions | Node 20, `firebase-functions` `^7.0.2` but v1 import style | `functions/package.json:18`, `fn:1` |
| Unused packages | `image_picker`, `package_info_plus`, `animations`, `vector_math` (0 imports in `lib/`) | grep over `lib/` |
| Lints | `flutter_lints` 6.0.0 only | `analysis_options.yaml:2` |

- The Android toolchain is below what two locked plugins declare (`share_plus` 12 and
  `package_info_plus` 9 want AGP 8.12.1+, Gradle 8.13+, Kotlin 2.2.0). Whether the build
  fails or warns is UNKNOWN.
- Do not move to AGP 9: `flutter_local_notifications` 23 needs it plus Dart 3.12, so stay on
  22.x.
- Firebase major bumps (core 5, auth 7, firestore 7, functions 7, messaging 17, app_check
  0.5) pull Firebase iOS SDK 13. They are the highest-risk dependency step and are not
  required for NUmer 2.0.
- No deprecated Flutter APIs are in use (`withOpacity`, `WillPopScope`, `MaterialState*` all
  at 0 hits). Two behavioural 3.38 changes need a manual look: SnackBar with an action no
  longer auto-dismisses (`lib/shared/widgets/app_toast.dart:24`), and Android uses the
  predictive-back page transition by default.
- `path_provider_foundation` is pinned to 2.4.1 by a `dependency_overrides` entry with no
  comment (`pubspec.yaml:64-65`). Reason UNKNOWN.

### 1.2 Structure and debt

- Feature-first under `lib/features/` (11 features: auth, account, habits, groups, courses,
  sessions, stats, history, ai_analysis, home, connections). Connections is built but hidden
  (`lib/main.dart:666-669`).
- 42,943 lines of Dart excluding generated l10n, 53,567 including it.
- Largest files: `features/home/home.dart` 2982, `features/stats/screens/stats.dart` 2799,
  `app/app_state.dart` 2637, `features/habits/screens/add_habit_sheet.dart` 1653,
  `core/data/storage.dart` 1558, `features/habits/screens/habits_screen.dart` 1410,
  `features/groups/data/group_service.dart` 1343, `core/data/sync_service.dart` 1320,
  `features/account/screens/account.dart` 1252, `main.dart` 1171.
- Layer violations:
  - `lib/core/data/storage.dart:10-13` imports the sessions, courses, habits and ai_analysis
    features.
  - `lib/shared/widgets/universal_avatar.dart:7` imports `features/account`.
  - 49 imports bypass a feature barrel (34 outside `main.dart`; `main.dart:20-37` holds the
    rest). 12 files import `auth/data/auth_service.dart` directly.
- Direct Firestore access outside the sync engine: `lib/core/data/storage.dart:1389-1415`
  (`Storage.deleteSession`), `lib/app/app_state.dart:945-948,2167-2176`,
  `lib/features/auth/screens/profile_setup_screen.dart:96-99`, and the whole groups feature
  (online-only by design).
- No router package. `MaterialApp.home` is `AuthGate` (`lib/main.dart:370,383`); named routes
  are `/shell`, `/timer`, `/alarms` (`lib/main.dart:371-375`); about 11 `Navigator.push`
  calls sit in feature screens.
- Shell: `_Shell` (`lib/main.dart:558`) is a `PageView` over Home, Habits, Stats, Groups,
  Account (`lib/main.dart:663-671`). The iOS glass bar is built at `lib/main.dart:826`.
- Providers (`lib/main.dart:170-196`): `SyncService`, `GroupService`, `HabitService`,
  `AppState` (proxy on the first and third), `AuthController` (proxy on `SyncService`).
- Tests: 2 files. `test/smoke/app_boot_test.dart` avoids Firebase and Hive;
  `test/features/account/accent_color_picker_test.dart` is `skip: true` (`:62`). No `scripts/`
  directory and no `.github/` directory. No functions tests, no rules tests.
- l10n: EN 397 keys, RU 382, KK 396 (`lib/l10n/app_{en,ru,kk}.arb`). RU is 15 keys short.
  Auth has hard-coded English strings in `auth_service` and
  `lib/features/auth/screens/verification_status.dart`.

### 1.3 Cloud Functions

All in `fn`, v1 API, no region, memory or `maxInstances` options except on the AI callable.

| Name | Kind | Line | Notes |
|---|---|---|---|
| `onStudySessionWrite` | Firestore onWrite `users/{u}/sessions/{s}` | `fn:564` | full recompute on every write (section 5) |
| `onCourseWrite` | Firestore onWrite `users/{u}/courses/{c}` | `fn:572` | recomputes on create, delete and hidden-flag change |
| `onGroupMemberDelete` | Firestore onDelete | `fn:592` | re-creates `users/{uid}` through `set(merge)` |
| `deleteGroup` | Firestore onDelete | `fn:612` | empty body |
| `deleteGroupCallable` | callable | `fn:620` | caller `group_service:1181` |
| `deleteAccountCallable` | callable | `fn:670` | caller `auth_service:556` |
| `joinPrivateGroup` | callable | `fn:714` | caller `group_service:988` |
| `getMemberSubjectStats` | callable | `fn:799` | no client caller |
| `sendNudge` | callable | `fn:903` | caller `group_service:880` |
| `analyzeCourseAi` | callable, 60 s, 512 MB, secret `GEMINI_API_KEY` | `fn:1123-1128` | calls `gemini-2.0-flash` at `fn:1168` |

- `requireAppCheck` returns on its first line (`fn:15`); the real check is commented out. It
  is called at `fn:621,671,715,800,904,1130`. App Check is therefore not enforced on any
  callable.
- The client activates App Check only in release builds or with
  `--dart-define=ENABLE_APPCHECK=true` (`lib/main.dart:51-73`).

### 1.4 Firestore data

- Collections used by the client: `users`, `habits`, `members`, `sessions`, `aggregates`,
  `groups`, `courses`, `history`, `groupMemberships`, `secrets`, `nudgeCooldowns`,
  `email_index`, `nudges`, `invites`, `goals`, `fcmTokens`, `connections`,
  `connectionGroups`.
- `users/{uid}` holds `email`, `emailVerified`, `groupIds`, `fcmEnabled`,
  `timezoneOffsetMinutes`, `allowNudges`, the active session, and a base64 avatar
  (`auth_service:727-740`, `sync_service:390-410`).
- Indexes: 7 composite entries in `firestore/firestore.indexes.json`, no field overrides.

---

## 2. Corrections to the planning brief

These contradict the shared context the plan started from. Each one changes a task.

| # | Brief said | Research found | Evidence |
|---|---|---|---|
| 1 | NUmer must upgrade to Flutter 3.38.5 | It already runs 3.38.5 / Dart 3.10.4. Left to do: the pubspec constraint, the Android toolchain, pruning unused packages. | `.metadata:7-8`, `pubspec.lock:1069-1071` |
| 2 | Three copies of `app_ui` | Four. Clavis has one too. | section 8 |
| 3 | All modules use dev-only auth | Gradus and Clavis run host adapters in production with self-minted HS256 tokens; Muto production rejects every token; EventsBot owns full password and email-code auth. | section 7 |
| 4 | One PostgreSQL cluster | Every module ships its own Postgres container. Consolidating is new work. | section 9 |
| 5 | Backends verify RS256 with JWKS, `iss` and `aud` | No module implements JWKS or a required `aud` today. EventsBot maps by subject only. | section 7 |
| 6 | Default accent is indigo | Indigo is only the base seed. The default user accent is `0xFF448AFF`. | `lib/app/app_state.dart:156`, `lib/main.dart:243` |
| 7 | App Check is in place | Client-side only. The server check is a no-op. | `fn:15` |
| 8 | Gemini 2.0 Flash deprecation to check | `gemini-2.0-flash` was shut down on 2026-06-01. `analyzeCourseAi` still calls it, so the AI analysis feature is very likely failing in production now. | `fn:1168`, section 12 |
| 9 | 10 Cloud Functions | 10 exports, but one is an empty stub and one has no caller. | `fn:612`, `fn:799` |
| 10 | EventsBot is ready to embed in NUmer | Its docs and a hard-coded string name another host app ("Jas Wallet"). | `EventsBot/flutter_events/lib/app.dart:60-61` |

---

## 3. Security findings

Source: the security review (22 findings: 3 critical, 5 high, 7 medium, 7 low). Every
critical and high item can be exploited today with only the public API key.

### 3.1 Critical

| ID | Finding | Evidence | Fix |
|---|---|---|---|
| C1 | Any signed-in user can make themselves admin of any public group, then take it over. The member payload is unchecked on create and a member may rewrite their own `role`. | `rules:99-109`, `rules:112-113`, `rules:35-43`, `rules:82-89`, `rules:163-165` | Validate the member payload (`role` is `member` on join, `admin` only for the creator at creation); only the creator changes roles; `createdBy` immutable; admin updates limited to `name`, `description`, `visibility`, `updatedAt`; remove the catch-all delete. |
| C2 | `/users/{uid}` is readable and listable without authentication, so every email leaks. | `rules:170`, `auth_service:727-740` | `users/{uid}` becomes owner-only. A server-mirrored `publicProfiles/{uid}` holds name and avatar fields for peers. Peer reads to move: `lib/features/groups/data/group_aggregation_service.dart:123,207,350,510`, `group_service:253-259`, `lib/shared/widgets/universal_avatar.dart:50-53`, `lib/shared/widgets/user_profile_tile.dart:25`, `lib/features/groups/widgets/user_subjects_bottom_sheet.dart:74-77`. |
| C3 | `email_index` is listable by anyone and any signed-in user can overwrite any entry. Overwriting blocks a victim's password reset. | `rules:175-179`, `auth_service:860-872`, `auth_service:901-906` | Close the collection; do the lookup server-side with `admin.auth().getUserByEmail`; delete the data and `functions/scripts/backfill_email_index.js`. |

### 3.2 High

| ID | Finding | Evidence | Fix |
|---|---|---|---|
| H1 | Peer access to sessions and courses is decided by `users/{uid}.groupIds`, which the owner writes. Set it to a victim's group and read their sessions, including hidden courses. | `rules:24-33`, `rules:171`, `rules:192-203`, `group_service:88,979,1038` | `groupIds` becomes server-managed (the trigger logic exists at `fn:421-426`); better, stop exposing raw sessions to peers and serve peer detail from aggregates. |
| H2 | `getMemberSubjectStats` returns any user's per-course study time through any public group, ignoring hidden courses. | `fn:799-901`, `fn:831-843` | Require both caller and target to be members; exclude hidden courses; validate ids. It has no client caller, so deleting it is also valid. |
| H3 | App Check is a no-op and `analyzeCourseAi` forwards a 12,000-character client prompt to Gemini with no quota. | `fn:14-27`, `fn:1131-1172` | `enforceAppCheck: true` per callable after monitoring; build the prompt server-side; per-uid daily quota; require a verified email. |
| H4 | Private-group join codes are user-chosen with no minimum length, compared in plain text, with no attempt limit. | `fn:725-728`, `fn:765-767`, `group_service:956-962` | Server-generated 8-character codes, stored as HMAC, compared in constant time, with attempt counters. |
| H5 | `users/{uid}/aggregates` is readable without authentication (35-day activity profile). | `rules:186-190`, `fn:533-547` | Owner or co-member only, once `groupIds` is server-managed. |

### 3.3 Medium and low

| ID | Finding | Evidence |
|---|---|---|
| M1 | `sendNudge` has no server rate limit; the cooldown is a client-written doc; the push body carries an unbounded sender name. | `fn:903-1120`, `rules:264-266`, `group_service:861-917` |
| M2 | Account deletion is incomplete and triggers re-create deleted documents. | section 3.4 |
| M3 | Password reset reveals whether an account exists and is verified; the gate reads a client-written flag; the throttle is client memory. | `auth_service:874-979` |
| M4 | Callables use client ids unvalidated; a slash path such as `G/members/ATT` resolves to an attacker-controlled document. | `fn:626`, `fn:720`, `fn:805-806`, `fn:909-910` |
| M5 | No schema validation on sessions or courses: `seconds: 1e9` tops a leaderboard; mass writes amplify trigger cost. | `rules:192-203` |
| M6 | `deleteAccountCallable` does not require a recent sign-in. | `fn:670-676` |
| M7 | Unverified accounts have full Firestore and callable access; verification is enforced only by client UI. | `rules:6-12`, `auth_service:129-139` |
| L1 | Raw error text returned to clients. | `fn:1118`, `fn:1196-1197` |
| L2 | Admins can remove the creator; `memberCount` is client-settable to any value. | `rules:112-116`, `rules:52-68` |
| L3 | `/nudges` has no rule, so the client listener is always denied and the error is swallowed. | `auth_service:809-835` |
| L4 | iOS bundle id in `firebase_options.dart` is the placeholder `com.example.numerApp`; API key restrictions UNKNOWN. | `lib/core/firebase_options.dart:54` |
| L5 | Password policy (8+) is client-only; the server minimum is 6. | `auth_service:409` |
| L6 | Group deletion batches exceed 500 writes above 250 members. | `fn:653-665`, `fn:122-136` |
| L7 | EventsBot's code flow has weaknesses that must not be copied: unkeyed SHA-256, a non-atomic attempt counter, email-only limits, optional `aud`/`iss`. | `EventsBot/backend/app/web/routers/auth.py:75-76,987-988`, `EventsBot/backend/app/web/superapp_bridge.py:52-64,116` |

The security report contains replacement rule snippets for every finding (helpers
`isVerified`, `isGroupCreator`, `onlyKeys`, `changed`; blocks R-C1, R-C2, R-C3, R-H1, R-H5,
R-M1, R-M5, R-M7, R-L3). The execution prompts for the rules tasks carry those snippets.

### 3.4 Account deletion coverage

`deleteAccountCallable` (`fn:670-712`) removes memberships, cascades owned groups, deletes
an explicit subcollection list (`fn:691-706`), runs `recursiveDelete(users/{uid})`
(`fn:708`), then deletes the auth user (`fn:709`).

| Data | Status |
|---|---|
| `users/{uid}` and all subcollections | covered, but `onStudySessionWrite` (`fn:423-426`, `fn:558-559`) and `onGroupMemberDelete` (`fn:600-602`) can re-create the user doc and aggregates after the delete |
| `groups/*/members/{uid}`, `groups/*/aggregates/{uid}`, owned groups | covered |
| `email_index/{email}` | missing |
| `nudges` where the user is sender or receiver | missing |
| Module backends | missing (nothing exists yet) |
| Client fallback `_deleteAccountLocally` (`auth_service:670-683`) | deletes a shorter list; leaves habits, connections, fcmTokens, aiLogs, stats, nudgeCooldowns |

Required order: write a server-only deletion marker, disable the auth user and revoke
refresh tokens, make every trigger return early for marked or missing users (and use
`update`, not `set(merge)`), delete data, delete the auth user, fan out to modules. Remove
the client fallback.

### 3.5 ID-token verification requirements for module backends

Source for the rules: https://firebase.google.com/docs/auth/admin/verify-id-tokens

1. Algorithm pinned to RS256; never read it from the token header.
2. `kid` must match a key from
   `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`.
   On an unknown `kid`, refetch at most once per 60 seconds.
3. Cache keys for the response `Cache-Control: max-age`; on fetch failure serve the last good
   keys for max-age plus a grace period, then fail closed.
4. `aud == numer-60744` and `iss == https://securetoken.google.com/numer-60744`, both
   mandatory; `exp` in the future, `iat` and `auth_time` in the past; at most 60 seconds of
   leeway.
5. `sub` non-empty, at most 128 characters. Provision by `(iss, sub)`, never by email.
6. `email_verified` must be the literal boolean `true`.
7. Reject `firebase.sign_in_provider` of `anonymous` or `custom`, and any `firebase.tenant`.
8. Revocation: `verify_id_token` alone does not check it. Use `check_revoked=True` on
   sensitive endpoints; elsewhere cache per-uid revocation and disabled state for at most 5
   minutes.
9. Roles only from namespaced custom claims (payload limit 1000 bytes); unknown values map
   to `user`.
10. Accept only `Authorization: Bearer`, at most 4 KB; never log the token.
11. App Check from a non-Google backend is possible: header `X-Firebase-AppCheck`, keys at
    `https://firebaseappcheck.googleapis.com/v1/jwks`
    (https://firebase.google.com/docs/app-check/custom-resource-backend).

The security report lists 20 test vectors (valid token, `alg: none`, HS256 key confusion,
unknown kid, wrong `aud`, wrong `iss`, expiry and leeway, future `iat`, missing `auth_time`,
bad `sub`, unverified email, anonymous provider, revoked, disabled, unknown role, key
endpoint down with warm and cold cache, token in query string, concurrent first requests).
The identity library prompt reproduces them.

---

## 4. Auth today and the email-code design

### 4.1 Current flow

- One `AuthController` (`auth_service:26`), email and password only.
- `AuthGate._buildForAuthState` (`lib/main.dart:429`): not initialized, signed out
  (`AuthScreen`), `requiresEmailVerification` (`EmailVerificationStatus`,
  `lib/main.dart:466-474`), bootstrapping, onboarding (`ProfileSetupScreen`), shell.
- Register (`auth_service:392-446`): `createUserWithEmailAndPassword` (`:415`),
  `user.sendEmailVerification()` (`:430`), a fixed one-second delay (`:432`),
  `_upsertEmailIndex` (`:434`). The form then opens a non-dismissable
  `EmailVerificationDialog` that polls every 3 seconds
  (`lib/features/auth/screens/email_verification_dialog.dart:32,87-88`), while `AuthGate`
  also swaps in `EmailVerificationStatus`. Two UIs for one state.
- Reset: `ResetPasswordSheet` (`lib/features/auth/screens/auth_screen.dart:722`) calls
  `sendPasswordResetSecure` (`auth_service:874-960`): client-only 15-second throttle, a read
  of `email_index` and `users/{uid}.emailVerified`, then Firebase's link email (`:933`).
- Dead code: the `verify your email` branch at `auth_screen.dart:445`; the `signOut` branch
  at `auth_screen.dart:669`.

### 4.2 What to reuse

| Piece | Source | Decision |
|---|---|---|
| Code generation and keyed-HMAC hashing | `Loci/backend/app/core/security/codes.py:14-24` | port to Node `crypto.randomInt`, `createHmac`, `timingSafeEqual` |
| Challenge lifecycle (replace, active, increment, consume) | `Loci/backend/app/db/repositories/email_challenges.py:9-77` | keep the design; store in Firestore with a transaction |
| Limits: 5 attempts, 10 minutes, 60-second resend | `Loci/backend/app/core/config/__init__.py:86-92`, `EventsBot/backend/app/config.py:165-168` | reuse values |
| Generic anti-enumeration responses | `Loci/backend/app/modules/auth/email.py:72-74,171-176` | reuse |
| Rate limiter policy (per IP and per address, fail closed) | `Loci/backend/app/core/security/rate_limit.py:6-43` | keep the policy; implement with Firestore counters |
| Email copy structure, "password changed" notice | `EventsBot/backend/app/services/email.py:10-38`, `Loci/backend/app/integrations/email.py:98-196` | rewrite as NUmer templates in TypeScript with a plaintext alternative |
| EventsBot SHA-256 hashing, 3-step reset with `verified_at` | `EventsBot/backend/app/web/routers/auth.py:75-76,913-1112` | do not reuse |
| `AppOtpField` | `EventsBot/app_ui/lib/inputs/app_otp_field.dart` | do not reuse: `maxLength: 1` (`:172`) breaks paste, no `autofillHints`, no semantics |

### 4.3 Design constraints from the security review

- Code: 6 digits from `crypto.randomInt(0, 1_000_000)`. Stored as
  `HMAC-SHA256(key, purpose | uid | code | codeId)` with a key in Secret Manager and a
  `keyVersion` field.
- Verify inside a Firestore transaction: reject if consumed, expired or `attempts >= 5`;
  increment attempts before revealing the result; set `consumedAt` on a match.
- A new send replaces the old code.
- Reset: verifying the code returns an opaque single-use `resetTicket` (32 random bytes,
  stored as HMAC, 10-minute TTL); completing the reset consumes it, sets the password, sets
  `emailVerified: true`, then calls `revokeRefreshTokens`.
- `requestPasswordReset` returns the same response whether or not the account exists.
- Verification takes the uid and email from the ID token only.
- Server-only collections: `authCodes`, `authRateLimits` (fixed-window counters), an audit
  log. Rules deny all client access.
- Starting limits: 3 sends per email per 15 minutes and 10 per day; 5 per uid per hour; 10
  per IP per hour; 15 failed verifies per email per day; a global circuit breaker of 2,000
  sends per day.
- App Check enforced on all five callables once client coverage is confirmed.

### 4.4 Client states

Enter code, sending, sent with resend timer, verifying, wrong code (with attempts left),
expired, too many attempts, rate-limited (with countdown), offline, delivery failed, success.
Reset adds: enter email, new password, ticket expired. The research proposes the l10n keys
`codeScreenTitle`, `codeScreenSubtitle`, `verifyCodeButton`, `enterCodeLabel`, `codeSending`,
`resendCode`, `resendCodeIn`, `codeSentTo`, `newCodeSent`, `codeVerifying`, `codeInvalid`,
`codeAttemptsLeft`, `codeExpired`, `codeTooManyAttempts`, `codeRateLimited`, `codeRetry`,
`codeDeliveryFailed`, `emailVerifiedTitle`, `emailVerifiedBody`, `resetCodeSentGeneric`,
`newPasswordTitle`, `confirmPasswordLabel`, `passwordsDontMatch`, `passwordResetSuccess`,
`resetSessionExpired`. Keys to retire: `verificationEmailSent`, `resendEmail`,
`resendVerificationEmail`, `verifyEmailFirst`, `signInToResend`, `resetLinkSent`,
`sendResetLink`.

### 4.5 Migration facts

- Old app versions keep using Firebase's link emails. They keep working as long as the
  Firebase templates stay enabled. A code verified through the new callable sets
  `emailVerified` server-side, so an old client's polling picks it up.
- No forced-update mechanism exists in `lib/main.dart` or `lib/app/`.
- Old clients write `email_index` on every cold start and read it on reset. The read sits in
  a `try/catch` (`auth_service:900-926`) and falls through to the link email, so closing
  reads does not break their reset. Closing writes makes their cold-start upsert fail;
  whether that failure is swallowed is UNKNOWN and must be checked before closing writes.
- Email squatting: anyone can register another person's address unverified; the real owner
  then gets `email-already-in-use`. Mitigations: reset-by-code also verifies the address, and
  a scheduled purge of stale unverified accounts.

---

## 5. Firestore cost

### 5.1 Per-user model (assumed persona: 1 cold start, 3 timer sessions, 4 courses, 3 habits, one group of 10)

| | Low | High |
|---|---|---|
| Client reads per day | 101 | 141 |
| Function reads per day | 333 | 333 |
| Total reads per day | about 434 | about 474 |
| Total writes per day | about 30 | about 36 |
| Function invocations per day | 6 | 6 |

At 200 users: 87k to 95k reads per day, above the 50k free quota; writes stay inside the 20k
free quota. Estimated bill about 2 USD per month at 200 users and about 20 USD at 2,000.
The numbers rest on an assumed usage model; real figures need the Firebase console.

### 5.2 Hotspots

1. `onStudySessionWrite` runs `updateUserAggregates` (`fn:418-562`) on every session write:
   it reads memberships, the user doc, all courses and 35 days of sessions (about 111 reads
   per event for the persona), and ignores `change.before/after`. It is 70% or more of all
   reads and grows quadratically with study intensity.
2. `users/{uid}` is written 12 to 18 times per day (active session start and stop, heartbeat,
   FCM fields, `groupIds` from two sources) and every write wakes each group peer's presence
   listener (`group_service:253-259`).
3. `syncNow` pushes and then runs a full incremental pull on every mutation: 17
   `_triggerSync` call sites in `lib/app/app_state.dart` plus resume. Each pull costs at
   least 8 reads with no changes, plus one history query per habit
   (`sync_service:1019-1038`), plus echo reads of the user's own writes.
4. Leaderboard: one listener per member on `users/{memberId}`, one per member on
   `nudgeCooldowns`, and avatar widgets that create a new `snapshots()` stream inside
   `build()` (`lib/shared/widgets/universal_avatar.dart:50`).
5. `watchUserMemberships` writes `groupIds` on every emission (`group_service:82-91`) and is
   built inline in `build()` (`lib/features/groups/screens/groups_screen.dart:62`).
6. Each session stop dirties its course for `totalMinutes`
   (`lib/core/data/storage.dart:649-652`): one extra write, echo read and `onCourseWrite`
   invocation.
7. Cold start writes `email_index`, `fcmTokens`, FCM fields and a heartbeat unconditionally
   (`auth_service:145-146,310-315`, `sync_service:457`).
8. `Storage.deleteSession` queries and writes Firestore directly, then the tombstone is
   pushed again: two trigger runs per delete.
9. `watchPublicGroups` has no limit (`group_service:33-37`).

### 5.3 Incremental aggregate design

- New private doc `users/{uid}/aggState/v1`, written only by the Admin SDK:
  `{v, tz, hidden: [courseId], ledger: {sessionId: {c, d, s, t}}, rebuiltAt, payloadHash}`.
- The ledger holds each counting session in the 35-day window (about 40 bytes each; about
  4 KB for the persona, 14 KB for a heavy user).
- Per event, one transaction: read the state doc, `users/{u}` and the memberships; compute
  the session's new contribution from `change.after`; if it equals the ledger entry, return
  with no writes; otherwise set or delete the entry, derive the public payload from the
  ledger in memory, and write the aggregates only when the payload hash changed.
- Setting a ledger entry by session id is idempotent, so duplicate and out-of-order events
  are safe.
- Rebuild from a session query when the state doc is missing, its version or timezone
  differs, or it is older than 7 days. Migration is therefore lazy: the first event per user
  costs one legacy-sized read.
- `onCourseWrite` acts only on a `hiddenFromLeaderboard` change and updates `hidden` without
  reading sessions.
- The public payload shape is unchanged, so no client change is needed.
- Effect: function reads per event drop from about 111 to about 3 (333 to 9 per day for the
  persona).
- Rollout: an environment flag selects the new path; a shadow mode compares both paths on a
  sample of events.

### 5.4 Other cheap fixes, by saving

1. `_triggerSync` pushes only; pull on resume, manual refresh, or at most every 10 to 15
   minutes (saves about 24 reads per day).
2. Query habit history only for habits whose `updatedAt` changed.
3. `watchUserMemberships` without side effects, hoisted out of `build()`.
4. Hoist per-widget `snapshots()` out of `build()`.
5. Gate cold-start writes on an actual change.
6. Stop the `_performLoad` re-broadcast of the active session when nothing is running
   (`lib/app/app_state.dart:495-497`).
7. Compute course `totalMinutes` locally instead of dirtying the course per session.
8. Route session deletion through the local tombstone only.
9. Bound `watchPublicGroups`; debounce group search.
10. Delete the empty `deleteGroup` trigger and other dead paths.
11. Add a Cloud Billing budget alert.

---

## 6. Modules

All four pin Flutter 3.38.5 in CI and require Dart `^3.10`. All ship EN, RU and KK.

### 6.1 Summary

| | Gradus | Clavis | EventsBot | Muto |
|---|---|---|---|---|
| Client package | `gradus_feature` | `piano_room_feature` | `events_feature` (folder `flutter_events`) | `muto_feature` over `muto_ui` |
| Mount widget | `GradusFeature(session, dependencies, config, chrome)` (`Gradus/gradus_feature/lib/gradus_feature.dart:40-58`) | `PianoRoomFeature(session, repository, policy, now, refreshInterval)` (`Clavis/piano_room_feature/lib/piano_room_feature.dart:18-31`) | `EventsFeature(session, onSessionExpired)` (`EventsBot/flutter_events/lib/app.dart:72-78`) | `MutoFeature(session, dependencies, config, onSessionExpired)` (`Muto/muto_feature/lib/src/presentation/muto_feature_widget.dart:32-45`) |
| Session type | `GradusSession(accessToken, accountId)` | `PianoRoomSession(studentId, displayName, email?)`; token lives in the HTTP repository | `EventsHostSession(accessToken)` | `MutoHostSession(accessToken)` |
| Own navigation | pushes routes on the host navigator; `GradusChrome.host` returns the body only | owns a nested `Navigator` | `AppShell` with its own bottom navigation (2 or 3 tabs by role) | `MutoShell` with its own bottom bar and FAB (2 or 3 tabs by role) |
| l10n | ARB, 88/89/89 keys (`creditsRatio` missing in EN) | ARB, 54 keys each | hand-written map, about 209/154/151 keys | ARB, 188 keys each |
| Icons | `AppIcons` (Lucide) only | `AppIcons` (Lucide) only | `AppIcons` 30 uses, Material `Icons` 24 | `AppIcons` 51 uses, Material 3 |
| Backend | FastAPI, 3 routes, no DB | FastAPI, 9 routes, SQLite | FastAPI and aiogram 3, 88 routes, 23 tables, 32 migrations, Redis | FastAPI, 24 routes, 8 tables, 8 migrations, S3 images |
| Workers | none | backup sidecar | asyncio tasks inside the bot process | hourly maintenance loop, backup, monitor |
| Online-only | syllabus import only | yes | yes | yes |
| Coverage floors | backend 90, client 85 | backend 90, feature 85 | backend 30, no Flutter floor | backend 80, feature 70 |
| Verify script | `scripts/verify.sh` | `scripts/verify.sh` | none (CI only) | `scripts/verify.sh` |

### 6.2 Gradus

- Stateless backend: `POST /api/v1/syllabus-extractions` behind a bearer token and an
  `Idempotency-Key` (`Gradus/backend/app/api/syllabus.py:30-53`). The identity is used only
  as a rate-limit key.
- Model: `SYLLABUS_MODEL=gemini-3.1-flash-lite`, provider enum at
  `Gradus/backend/app/config.py:31-35`.
- Client data lives in `SharedPreferences` under keys namespaced by `accountId`
  (`Gradus/gradus_feature/lib/src/data/preferences_transcript_repository.dart:18-26`).
- A changed `accessToken` disposes and rebuilds the controller and remounts the subtree
  (`Gradus/gradus_feature/lib/gradus_feature.dart:64-73,87`).
- Screens: `GradusScreen`, `CourseDetailScreen`, `CourseForm` (with syllabus import),
  `SemesterForm`, `AssignmentForm`, a confirm sheet.
- Defects: `scripts/verify.sh` does not run everything CI runs although the docs say so;
  dead SVG references in `app_ui/lib/icons/app_icons.dart:12-15`; `google_fonts` and `intl`
  declared but unused.

### 6.3 Clavis

- Tables `bookings`, `booking_requests`, `weekly_limits`; a unique partial index enforces one
  active booking per slot (`Clavis/backend/app/infrastructure/store/sqlite.py:18-41`).
- A single SQLite connection behind a lock; each use case runs through `asyncio.to_thread`
  (`Clavis/backend/app/application/booking_service.py:41-42`, `sqlite.py:152-164`).
- Config has `DATABASE_PATH` only, no database URL (`Clavis/backend/app/config.py:99-103`).
  Its own docs say SQLite suits one host (`Clavis/docs/ARCHITECTURE.md:49`).
- Bookings are keyed on a bare `subject` string with no issuer.
- `PianoRoomRemote` hard-codes `Asia/Almaty` and sets `displayName = studentId`
  (`Clavis/piano_room_feature/lib/src/data/http_piano_room_repository.dart:280-281`).
- Server time decides everything; the feature already has `ScheduleSkeleton`
  (`Clavis/piano_room_feature/lib/src/presentation/piano_room_widgets.dart:91`).
- No operator screen exists in the client. Operator routes exist on the backend
  (`Clavis/backend/app/api/operator.py:29-64`).
- Production signs its own HS256 tokens through
  `Clavis/backend/app/commands/issue_token.py:18-48`.

### 6.4 EventsBot

- Three identity paths: Telegram initData (`EventsBot/backend/app/web/auth.py:43`), a
  dev-only HS256 token (`EventsBot/backend/app/web/flutter_auth.py:21-53`), and an inert
  superapp bridge (`EventsBot/backend/app/web/superapp_bridge.py:42-66`). All Flutter routes
  go through `require_flutter_user` (`flutter_auth.py:63-91`).
- The Flutter package is a coordinator and submitter UI: `EventsScreen`, `EventDetailScreen`,
  `SubmitScreen`, `MyEventsScreen`, `CoordinatorDashboardScreen`, `EventManagerScreen`.
  `CalendarScreen`, `PendingEventsScreen` and `StubScreen` have no construction site.
- The Flutter API (`/api/flutter/events`) lists events, categories, the user's own events and
  an updates stream. Favourites, reminders, registration, ratings and friends exist only on
  the Mini App routes, which require Telegram initData.
- The API base URL is a compile-time constant (`EventsBot/flutter_events/lib/core/constants.dart:16-18`),
  not a host parameter.
- The expired-session text is hard-coded English and names another host app
  (`EventsBot/flutter_events/lib/app.dart:60-61`).
- It owns passwords (bcrypt) and email codes of its own
  (`EventsBot/backend/app/web/routers/auth.py:110-1001`).
- Workers are asyncio tasks in the bot process (`EventsBot/backend/app/main.py:96-163`).
  Whether that process is meant to be running in production is a question for the owner.

### 6.5 Muto

- Already provisions users by `(issuer, subject)` under an advisory lock
  (`Muto/backend/app/application/identity.py:11-54`). Admin status is read from the token on
  every request and never stored (`identity.py:65`).
- Production resolver rejects every token (`Muto/backend/app/infrastructure/auth/resolvers.py:14-16,50-53`).
- No block-user and no moderation. Reports go to a read-only operator list
  (`GET /api/v1/operations/reports`). `Muto/docs/PRODUCT.md:109-121,144` states there is no
  queue, verdict, appeal or enforcement. Account status can be changed only by raw SQL.
- Images go to S3-compatible storage; production refuses local storage
  (`Muto/backend/app/config.py:191-213`).
- Contact channels: Telegram, email, phone and WhatsApp.
- Defects: `Muto/deploy/Caddyfile:11` and `Muto/deploy/restore.sh:18,24,25` reference a
  service named `backend` that does not exist, so the restore script fails midway.

### 6.6 Loci (reference only)

Not a NUmer 2.0 module. Used as the source of auth patterns (section 4.2) and host hardening
(section 9.4).

---

## 7. Identity integration seams

### 7.1 Shared verifier library

- Proposed distribution `numer-identity` (import `numer_identity`), own repository, tagged
  releases, runtime dependencies `pyjwt[crypto]` and `httpx`.
- Interface: `FirebaseVerifier(project_id, leeway_seconds, key_source, clock,
  revocation_check, roles_claim)` with `async verify(token) -> FirebaseClaims`; exceptions
  `TokenInvalid` (maps to 401) and `KeysUnavailable` (maps to 503).
- `numer_identity.testing` ships `make_test_keypair`, `sign_token` and `StaticKeySource` so
  each backend's tests mint tokens without the network.
- Delivery: all four Dockerfiles run `uv sync --frozen` with the repo root as build context,
  so a path dependency outside the repo cannot build. Options: a git dependency pinned by tag
  (needs `git` in a builder stage; the `python:3.12-slim` runtime has none) or a vendored
  wheel per repo.
- The project id must be configuration (`FIREBASE_PROJECT_ID`) so a staging Firebase project
  produces a different `iss` and `aud`.

### 7.2 Per-module change points

| Module | Resolver factory | Config enum | Preflight | Extra work |
|---|---|---|---|---|
| Gradus | `Gradus/backend/app/infrastructure/auth/resolvers.py:125-130` | `Gradus/backend/app/config.py:26-28,44` | `Gradus/deploy/preflight.sh:22-31` hard-requires `AUTH_ADAPTER=host` | none; no user store |
| Clavis | `Clavis/backend/app/infrastructure/auth/resolvers.py:125-130` | `Clavis/backend/app/config.py:25-27,36` | `Clavis/deploy/preflight.sh:22-31` | delete `issue_token.py` at cutover; remap legacy subjects only if production has bookings under old ids (UNKNOWN) |
| Muto | `Muto/backend/app/infrastructure/auth/resolvers.py:50-53` | `Muto/backend/app/config.py:19-21,37` | `Muto/deploy/preflight.sh:37-43` | fix the profile overwrite at `Muto/backend/app/application/identity.py:48-53` before enabling (a Firebase token has no Telegram name or phone, so every request would null them) |
| EventsBot | `EventsBot/backend/app/web/superapp_bridge.py:42-66` | `EventsBot/backend/app/config.py:53-99` | `EventsBot/deploy/setup-server.sh:26-30` | new `user_identities` table and Alembic revision on top of `20260707_0001`; role computed from claims on every request; Telegram account linking |

Gradus and Clavis resolvers are byte-for-byte siblings.

### 7.3 EventsBot account merging

Proposed resolution on a valid token, inside the existing advisory lock
(`EventsBot/backend/app/web/superapp_bridge.py:100-106`):

1. Look up `(issuer, uid)` in `user_identities`. If found, use it.
2. Else, if `email_verified` and the email domain is `nu.edu.kz`, find a `users` row with the
   same verified email. Exactly one match: attach the identity to it. This reverses the
   current policy tested at
   `EventsBot/tests/integration/test_superapp_bridge_db.py:49`.
3. Else create a new user.
4. Telegram-only users link explicitly: the bot issues a one-time code, and
   `POST /api/flutter/auth/link-telegram` takes the Firebase bearer plus that code. If a
   Firebase-provisioned row with content already exists, refuse with 409.

Role risk: `_role_from_claims` returns `None` when the claim is absent and the stored role is
then left unchanged (`superapp_bridge.py:80-88,123-126`), so removing a claim never demotes.
The Telegram path also writes `role = admin` from `ADMIN_IDS`
(`EventsBot/backend/app/services/users.py:26-29`).

### 7.4 Client token handling

A Firebase ID token lives one hour. Every feature takes a plain token string today.

| Feature | What a new token does today | Needed |
|---|---|---|
| Gradus | disposes the controller and remounts the subtree | a token-provider callback on `GradusSession`; key state on `accountId` only |
| Clavis | repository identity change recreates the controller (`Clavis/piano_room_feature/lib/piano_room_feature.dart:92-102`) | a token-provider callback on `HttpPianoRoomRepository` and `PianoRoomRemote`; `studentId` must be the Firebase uid |
| EventsBot | re-bootstraps through `/session` without remounting (`EventsBot/flutter_events/lib/app.dart:112-118`) | smallest change: a provider callback read at `core/api_client.dart:77` |
| Muto | `MutoScope(key: ValueKey(accessToken))` drops all feature state (`muto_feature_widget.dart:66-69`) | a token provider on `RemoteAuthState`; key the scope on the uid |

Host contract: modules receive `Future<String> Function()` that calls `user.getIdToken()`.
On a 401 the module calls `onSessionExpired`; the host forces one refresh and signs out only
if that fails.

### 7.5 Roles

- Proposal: one custom claim `numer_roles`, an array of `"<module>:<role>"` strings:
  `gradus:operator`, `clavis:operator`, `events:admin`, `muto:admin`.
- Set only through the Admin SDK. No claims code exists in `fn` today.
- Bootstrap: a local script run by the owner with a service account, then an admin-gated
  callable.
- A changed claim reaches the client on the next token refresh, up to one hour. Demotion also
  calls `revokeRefreshTokens`.

---

## 8. Design package and current style

### 8.1 The four `app_ui` copies

| Copy | Files in `lib/` | Lines | Tests | Lineage |
|---|---|---|---|---|
| EventsBot | 36 | 8113 | 0 | origin; includes product widgets |
| Muto | 36 | 8176 | 0 | EventsBot copy plus 7 patched files |
| Gradus | 24 | 3955 | 3 | deliberate fork of EventsBot with product widgets removed (`Gradus/docs/ARCHITECTURE.md:27-42`) |
| Clavis | 24 | 3956 | 4 | Gradus fork plus `AppAppBar.toolbarHeight` (`Clavis/app_ui/lib/appbars/app_app_bar.dart:13`) |

- All four are named `app_ui` and wired by path (`../app_ui`). Two modules compiled into one
  app collide on the package name, so a rename is mandatory.
- Token values are identical across the four copies. The brand colour is a hard-coded purple
  (`AppColors.primary = 0xFF7100FF`, `Gradus/app_ui/lib/tokens/app_colors.dart:4`); themes
  are hand-built with `ColorScheme.light(...)` and `ColorScheme.dark(...)`, not `fromSeed`
  (`Gradus/app_ui/lib/theme/app_theme.dart:18-27`).
- Shared scale: `AppSpacing` with `df = 16`, radii 8, 12, 16 and 20, app bar height 56
  (`Gradus/app_ui/lib/tokens/app_spacing.dart:10,114-120,177`).
- The theme names the font `Geist` but no copy bundles it, so it falls back to the platform
  font. `google_fonts` is declared and never imported. Four SVG icons point at files that do
  not exist (`Gradus/app_ui/lib/icons/app_icons.dart:12-15`).
- Icons are Lucide behind an `AppIcons` facade (121 entries; Muto has 127 and adds
  `simple_icons` brand marks).
- The Gradus line carries quality fixes the EventsBot line lacks: a loading button keeps its
  label, a visible dark progress track, `errorText` colours, a bottom-sheet theme. The Muto
  line adds `AppBottomSheet.useRootNavigator` (and loses the safe-area bottom padding,
  `Muto/app_ui/lib/dialogs/app_bottom_sheet.dart:173`) and search tooltips.
- Widgets no consumer uses: bank, user and job cards, OTP, password and phone fields, the
  premium dialog, level ring, reward toasts, `AppMenu`. `AppCalendar` is used by EventsBot
  only.
- `AppPrimaryButton` takes `color` in Gradus and Clavis, `backgroundColor` in Muto.
- Brand-colour call sites that would lose `const` when colours come from the scheme: about
  126 (Gradus 12, Clavis 2, EventsBot 58, Muto UI 12, Muto feature 44).

Consumer surface (identifier occurrences): Gradus `AppSpacing` 107, `AppColors` 55; Clavis
`AppSpacing` 60, `AppColors` 13; EventsBot `AppSpacing` 319, `AppColors` 303; Muto feature
`AppSpacing` 222, `AppColors` 164; Muto UI `AppColors` 60, `HomeRadius` 7.

### 8.2 NUmer `lib/shared`

Six widgets, 769 lines, no tokens and no component kit: `app_toast.dart` (12 importers),
`loading_screen.dart`, `color_picker_button.dart`, `universal_avatar.dart` (imports a
feature and opens a Firestore listener), `tip_icon.dart`, `user_profile_tile.dart` (opens a
Firestore listener). Two of the six break the rule that `shared` is pure UI.

### 8.3 NUmer's current style, measured

Counts are regex counts over `lib/` excluding `l10n`; treat them as approximate.

| Area | Facts | Evidence |
|---|---|---|
| Theme | Material 3; `ColorScheme.fromSeed(seedColor: accentColor)` for light and dark; only `switchTheme` is customised; theme animation 300 ms | `lib/main.dart:317-355` |
| Seeds | `Colors.indigo` for the bootstrap app only; default user accent `0xFF448AFF`; 5 presets plus user-added ones | `lib/main.dart:241-251`, `lib/app/app_state.dart:156`, `lib/features/account/widgets/accent_color_picker.dart:64-68` |
| Scheme roles | about 576 references; top: `primary` 147, `onSurfaceVariant` 131, `surfaceContainerHighest` 70, `onSurface` 56, `outlineVariant` 43 | grep |
| Literal colours | 226 `Colors.*`, 185 `Color(0x…)` (130 in the avatar catalogue) | grep |
| Font | none set; platform default | `pubspec.yaml:64-66` |
| Text | 274 `textTheme` references against 85 raw `TextStyle(`; 76 `fontSize:` literals (12 x30, 16 x9, 14 x7, 13 x7, 10 x6); `FontWeight.bold` 103, `w600` 39, `w700` 28, `w500` 17 | grep |
| Spacing | about 90% on a 4 pt grid; dominant 16, 8, 12, 24, 4, 32; off-grid mostly 6, 10, 2, 14 | grep |
| Radii | 16 x63, 12 x52, 20 x27, 8 x8, 28 x5; off-grid 10, 22, 14, 6, 18 | grep |
| Elevation | 29 literals, 18 of them 0; 29 `BoxShadow` | grep |
| Gradients and blur | 7 `LinearGradient`, 1 `SweepGradient`, 3 `BackdropFilter` | `lib/main.dart:871-875`, `lib/features/home/home.dart:564-569`, `lib/features/habits/screens/habits_screen.dart:847-852`, `lib/features/auth/screens/auth_screen.dart:66`, `lib/features/ai_analysis/ai_analysis_screen.dart:632` |
| Icons | Material 391 uses in 43 files; `MdiIcons` 111, `PhosphorIcons` 17, `FontAwesomeIcons` 1, all three only in `lib/features/account/models/profile_avatar.dart`; habit icons are persisted as code point, family and package | grep, `lib/features/habits/models/habit_category.dart:19` |
| Motion | 110 millisecond durations; 300 x29, 200 x22, 260 x15, 220 x8, 250 x7; curves `easeOutCubic` 42 | grep |
| Haptics | 13 calls; none on tab switch | grep |
| Loading | 34 `CircularProgressIndicator`, 0 skeletons, 0 pull-to-refresh | grep |
| Toast | `showAppMessage` exists; raw `SnackBar` still used 38 times in 11 files | `lib/shared/widgets/app_toast.dart` |
| Accessibility | 0 `Semantics(`; 33 `tooltip:` | grep |

### 8.4 The iOS navigation bar

`_buildIosLiquidGlassNavigationBar` (`lib/main.dart:826`): a floating bar 66 pt high with a
14 pt side margin and corner radius 34. The bar has no fill of its own; only the selected
item's highlight is drawn: a pill with blur sigma 24 and a white gradient at low alpha,
radius 28, moved by `AnimatedPositioned` over 220 ms with `easeOutCubic`. Items scale to 1.08
when selected over 180 ms; icons are 24 selected and 20 unselected; labels 12 and 11.
The Android bar is a Material `NavigationBar`, height 64.

A second glass element, `_IosLiquidActionPill`, is defined twice
(`lib/features/home/home.dart:539`, `lib/features/habits/screens/habits_screen.dart:828`).

### 8.5 What "modules conform to NUmer" means in practice

NUmer has no component kit to conform to. Its look is the Material 3 scheme generated from
the user's accent. Conforming therefore means: module widgets must read colours from the
host `ColorScheme` instead of the hard-coded purple, and stop naming a font.

---

## 9. Infrastructure

### 9.1 What the module repos assume

- Every module API listens on container port 8000 and publishes no host port. Each module
  joins an external Docker network owned by another project's reverse proxy, which holds
  ports 80 and 443 (`Gradus/deploy/deploy.sh:16`,
  `Gradus/docker/docker-compose.shared-host.yml:7-14`, and the same overlay in Clavis, Muto
  and EventsBot).
- The proxy's site blocks live in that other project's repository, not in the module repos.
- Proxy-header trust is tied to a subnet: Gradus, Clavis and Muto run uvicorn with
  `--forwarded-allow-ips 172.16.0.0/12`
  (`Gradus/docker/docker-compose.production.yml:48-49`).
- Domains in the repos: `gradus.anxchywl.dev`, `clavis.anxchywl.dev`, `muto.anxchywl.dev`
  (`Gradus/deploy/production.env.example:20`, `Clavis/deploy/production.env.example:21`,
  `Muto/.github/workflows/release.yml:74`). The EventsBot domain is UNKNOWN.
- Each module with a database runs its own Postgres container
  (`EventsBot/docker/docker-compose.prod.yml:2-26`,
  `Muto/docker/docker-compose.production.yml:4-24`).

### 9.2 Conflicts if the stacks were merged into one compose project

- Not ports. Service names (`postgres`, `redis`, `backup`, `bot` repeat across repos), DNS
  aliases, and environment names (`POSTGRES_*`, `DATABASE_URL`, `BACKUP_S3_*` with different
  suffixes, five spellings of the domain variable).
- Redis policy: EventsBot needs `volatile-lru` for its image cache
  (`EventsBot/docker/docker-compose.prod.yml:33-35`); a queue-holding service needs
  `noeviction`. One instance cannot serve both.
- One Postgres cluster would need a move from the alpine image to a Debian-based one, which
  changes libc collation; whether any column depends on collation order is UNKNOWN.
- Each module keeps its own `alembic_version`, so separate databases are mandatory either way.
- A merge needs a write freeze and a dump-and-restore cutover per database, then a proxy swap
  that also affects unrelated projects on the host.

### 9.3 Backups and monitoring as they are

| | Clavis | EventsBot | Muto |
|---|---|---|---|
| Tool | SQLite online copy (`Clavis/docker/docker-compose.production.yml:78`) | `pg_dump -Fc` (`EventsBot/deploy/backup.sh:29`) | `pg_dump --format custom --no-owner` (`Muto/deploy/backup.sh:11-17`) |
| Checksums | none | none | sha256 |
| Encryption and offsite | none | none | age and S3 when configured |
| Verify | UNKNOWN | `pg_restore --list` | `verify-backup.sh`: checksum, list, age under 26 h, run only inside `deploy.sh:54` |
| Restore script | none | none | `restore.sh`, broken (section 6.5) |
| Alerting | container logs | container logs | `monitor.sh` posts to a webhook after 3 failures, never re-alerts, never reports recovery (`Muto/deploy/monitor.sh:5-22`) |

- No module runs a real restore test. `verify-backup.sh` only lists the archive.
- Both existing `restore.sh` scripts restore over production.
- EventsBot had no backups until 2026-09-12 and Muto lost about a month of backups to a
  crond environment bug (`EventsBot/deploy/backup.sh:3-12`,
  `Muto/docker/docker-compose.production.yml:133-137`).
- Whether any offsite upload works in production is UNKNOWN.
- A host-local monitor cannot report that the host itself is down.

The infra report contains a full restore-test procedure (scratch Postgres on an internal
network with tmpfs data, restore with `--exit-on-error --single-transaction`, per-table row
counts, migration head check, timing recorded, cleanup). The restore-test prompt carries it.

### 9.4 Host hardening found in setup scripts

Only one repo's setup script hardens the host
(`Loci/deploy/setup-server.sh`): ufw allowing SSH, 80 and 443 (`:15-18`); SSH
`PasswordAuthentication no` and `PermitRootLogin prohibit-password` (`:50-55`); a `deploy`
user in the `docker` group (`:22-30`); unattended upgrades (`:57`); sysctl tuning
(`:34-40`); a 2 GB swap file (`:42-48`). No script installs fail2ban, sets Docker log
rotation, or restricts SSH to a named user. ufw does not filter ports that Docker publishes.

### 9.5 Capacity (general terms)

The server audit found the target host small and shared with other projects. CPU and disk
have ample headroom; memory is the binding constraint. The four module backends and their
databases already run there. The inventory, the projected footprint and the verdict are in
the private capacity file and are not reproduced here. The verdict in one line: NUmer 2.0
fits without shutting anything down, as long as the plan adds no new long-running service.

---

## 10. Gradus merge

### 10.1 Gradus model

- `Semester(id, name, position)`; `Course(id, semesterId, code, title, credits, grade?,
  assignments[])`; `Assignment(id, courseId, name, weight, maximumScore, earnedScore?)`
  (`Gradus/gradus_feature/lib/src/domain/semester.dart:10-16`, `course.dart:47-56`,
  `assignment.dart:36-42`).
- Invariants: credits above 0 and at most 24; assignment weights sum to at most 100; a grade
  is persisted as its letter only and resolved through the scale on load.
- One scale, `FourPointScale` (16 letters), lives in code
  (`Gradus/gradus_feature/lib/src/domain/grade.dart:64-180`).
- The repository interface loads and saves the whole `Transcript` at once
  (`Gradus/gradus_feature/lib/src/domain/repositories.dart:6-10`). The controller mutates
  optimistically and rolls back on a failed save
  (`Gradus/gradus_feature/lib/src/application/gradus_controller.dart:238-253`).
- Persisted today as one JSON string under `gpa_v2_{accountId}_transcript`.

### 10.2 NUmer side

- Hive typeIds 10 to 17 are taken (`lib/core/data/entities.dart`); 18 is the next free id.
- `LocalCourse` (typeId 11) has a positional hand-written adapter: the `@HiveField` numbers
  are cosmetic, the write order is what matters, and trailing fields are read behind
  `reader.availableBytes > 0` guards (`lib/core/data/entities.dart:651-674`). A new field is
  an appended write plus a guarded read.
- The course UI model requires `day`, `start`, `end` and `colorValue`
  (`lib/features/courses/course.dart:3-27`).
- `Storage.saveCourses` soft-deletes every course absent from the list it is given
  (`lib/core/data/storage.dart:507-514`).
- The pull path's update branch does not re-apply `totalMinutes` or
  `pomodoroLongBreakMinutes` and assigns `goalHours` twice (`sync_service:741-754`); a new
  course field must be added to the create branch, the update branch and `_courseToRemote`.

### 10.3 Why grades cannot live on the course document

`users/{uid}/courses/{courseId}` is readable by any user who shares a group with the owner
(`rules:199-203`), and peer clients download whole course documents
(`group_service:648-655`). A grade stored there would be visible to group peers.

### 10.4 Proposed mapping

| Gradus | NUmer target | Hive |
|---|---|---|
| `Course.id`, `title`, `credits` | existing `LocalCourse.id`, `name`, `credits` | typeId 11, existing fields |
| `Course.code` | new optional `LocalCourse.code` | appended write position, guarded read |
| `Course.semesterId`, `grade` letter, `assignments[]` | new `LocalCourseGrade` keyed by course id | typeId 18 (sync entity) |
| `Assignment` fields | `LocalAssignment`, embedded in the grade record | typeId 19 (plain adapter) |
| `Semester` | `LocalSemester` | typeId 20 (sync entity) |

- Firestore: `users/{uid}/courseGrades/{courseId}` and `users/{uid}/semesters/{semesterId}`,
  both owner-only. The names `courseGoals` and `courseProgress` already exist
  (`rules:213-219`).
- Sync: new dirty accessors, push blocks and `_pullCollection` calls following the course
  pattern (`sync_service:202-270,365-390`). Whole-record last-writer-wins, as for courses.
  Soft delete, so other devices learn of it through the `updatedAt` cursor.
- No function trigger matches the new paths.
- Seam: `GradusFeature` already takes `GradusDependencies{transcript, scales, syllabus?}`
  (`Gradus/gradus_feature/lib/src/config/gradus_scope.dart:11-27`). The host supplies a
  `TranscriptRepository` over Hive. Its `save` must diff and write only changed rows, and
  must never call `Storage.saveCourses` with a partial list.

### 10.5 Open points the research could not settle

- Whether NUmer screens tolerate a course with empty `day`, `start` and `end`.
- Whether NUmer `credits` (which drives `expLevel`, `lib/features/courses/course.dart:31`)
  and Gradus ECTS credits are the same unit.
- How NUmer generates course ids.
- Whether Gradus ever shipped standalone with real user data to import.
- Retakes: Gradus allows the same title in two semesters; NUmer has one course per title.

---

## 11. Docs audit

### 11.1 Stale claims

| Where | Claim | Reality |
|---|---|---|
| `AGENTS.md:33` | core never imports a feature | `lib/core/data/storage.dart:10-13` does |
| `AGENTS.md:56-58` | features are imported only through barrels | 49 imports bypass a barrel |
| `AGENTS.md:62` | tests mirror the feature tree | 2 test files exist |
| `AGENTS.md:109-112` | data is owner-only except groups, profiles, aggregates | misses the public reads on `users` and `email_index` and group-shared courses |
| `docs/INFRASTRUCTURE.md:57,93` | App Check enforced | server check is a no-op (`fn:15`) |
| `docs/INFRASTRUCTURE.md:85` | `deleteGroup` cascades cleanup | empty body (`fn:612-618`) |
| `docs/INFRASTRUCTURE.md:99` | see `lib/features/sessions/README.md` | file does not exist |
| `docs/INFRASTRUCTURE.md:100` | Android `minSdk 21` | `minSdk = flutter.minSdkVersion` |
| `docs/INFRASTRUCTURE.md:159-160` | a known failing test | the test is skipped (`test/features/account/accent_color_picker_test.dart:62`) |
| `docs/INFRASTRUCTURE.md:58-59` | `firebase_options.dart` is generated and ignored | listed in `.gitignore` but tracked |
| `README.md:8` | Dart >= 3.4 | the lock requires 3.10 |
| `docs/PRIVACY_POLICY.md` | lists Firebase services | does not name the AI provider or FCM tokens |
| `lib/core/startup_metrics.dart:4-5` | file comment | mixed case, long dash, two lines: breaks the comment convention |

### 11.2 Duplicated subjects and proposed single owners

| Subject | Today | Owner |
|---|---|---|
| Build, run, test commands | `README.md:57-79`, `docs/INFRASTRUCTURE.md:112-137` | `docs/INFRASTRUCTURE.md` |
| Offline-first contract | `AGENTS.md:92-96`, `docs/INFRASTRUCTURE.md:20-31` | rule in `AGENTS.md`, flow in `docs/INFRASTRUCTURE.md` |
| Repo layout and dependency rule | `README.md:31-46`, `AGENTS.md:13-62` | `AGENTS.md` |
| Feature list | `AGENTS.md:52-54`, `docs/PRODUCT.md:18-61` | `docs/PRODUCT.md` |
| Localization | three files | tooling in `docs/INFRASTRUCTURE.md`, rule in `AGENTS.md` |
| Version, user count, store links | three files | `pubspec.yaml` for the version, `README.md` for links |
| Known debt | `docs/INFRASTRUCTURE.md:151-160` contradicts `AGENTS.md:33` | one "Known debt" section in `AGENTS.md` |
| Firestore collection tree | three places | the rules file plus `docs/INFRASTRUCTURE.md` |
| Which doc owns what | four files | one "Sources of truth" block in `AGENTS.md` |

### 11.3 Conventions across repos

All four module repos already state the comment rule the brief makes binding (why only,
lowercase, one line, no trailing punctuation, no docstrings), no emoji, English only,
specific catches, conventional commit prefixes with a subject line only, hand-written fakes
with no mocking package. NUmer states none of these. Module repos layer as domain,
application, data, presentation, enforced by a boundary test; NUmer is feature-first with
barrels and has no boundary test.

### 11.4 Proposed verify script

`scripts/verify.sh`, stopping on the first failure: `flutter pub get`, `flutter gen-l10n`,
`dart format --set-exit-if-changed lib test`, `flutter analyze --fatal-infos`,
`flutter test --coverage`, a coverage floor, a layer-boundary test with an allow-list of
today's violations that may only shrink, an ARB key-parity check, and
`npm ci && npm run build` in `functions/`. CI mirrors it and adds secret and dependency
scanning. Current coverage, the size of the one-time format commit and the number of
analyzer infos are UNKNOWN.

---

## 12. Fact-check table

Checked 2026-11-27. Google Cloud pricing pages did not render for the checker, so some unit
prices come from secondary pages.

| # | Claim | Verdict | Correct value | Source |
|---|---|---|---|---|
| a1 | Firestore free quota | confirmed | 1 GiB stored, 50,000 reads, 20,000 writes and 20,000 deletes per day, 10 GiB egress per month | https://firebase.google.com/docs/firestore/pricing |
| a2 | Firestore unit prices | nuanced | about 0.03 USD per 100k reads and 0.09 USD per 100k writes (search snippet); delete and storage prices UNKNOWN | https://cloud.google.com/firestore/pricing |
| a4 | Firebase Auth free tier | confirmed | 50,000 monthly active users at no cost | https://firebase.google.com/pricing |
| a6 | Auth email limits | confirmed | verification 1,000 per day on Spark and 100,000 on Blaze; password reset 150 and 10,000 | https://firebase.google.com/docs/auth/limits |
| a7 | Cloud Functions free tier | nuanced | functions need the Blaze plan; 2M invocations per month free, then 0.40 USD per million; 400K GB-seconds, 200K CPU-seconds | https://firebase.google.com/pricing |
| b1 | Kazakhstan data localization | confirmed | Law 94-V Art. 12(2): personal data must be stored in a database located in Kazakhstan; article rewritten by Law 326-VIII, in force 2026-08-25 | https://uppersetup.com/en/blog/personal-data-and-localisation-in-kazakhstan-in-2026-law-no ; https://amcham.kz/wp-content/uploads/2026/05/2026-05-15_AmCham_DataLocalization_Issue-Brief_ENG_v5.pdf |
| b2 | Applies to foreign servers | nuanced | storing only abroad does not satisfy the article as summarised; a draft decree would relax it, adoption UNKNOWN | same |
| b3 | Exemption for an individual developer | UNKNOWN | the scope article could not be read; needs local counsel | https://adilet.zan.kz/eng/docs/Z1300000094 |
| b4 | Penalties | nuanced | administrative fines, 30 to 200 MCI for an individual (MCI 2026 = 4,325 KZT) | https://vlolawfirm.com/legal-updates/kazakhstan-2026-q3-data-protection |
| c1 | App Store guideline 1.2 | confirmed | UGC apps need filtering, a report mechanism with timely response, the ability to block abusive users, and published contact information | https://developer.apple.com/app-store/review/guidelines/ (updated 2026-10-16) |
| c2 | Guideline 5.1.1(v) | confirmed | an app that supports account creation must offer account deletion inside the app | same |
| d1 | Gemini 2.0 Flash | confirmed | shut down 2026-06-01 | https://aistudio.google.com/docs/deprecations |
| d2 | `gemini-3.1-flash-lite` | confirmed | stable since 2026-05-07; shutdown listed for 2027-05-07; replacement `gemini-3.5-flash-lite` | same |
| d3 | Current Flash names | confirmed | stable: `gemini-3.8-flash`, `gemini-3.6-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite` | https://aistudio.google.com/docs/models |
| e1 | Email enumeration protection | confirmed | on by default only for projects created on or after 2023-09-15; older projects enable it in Auth settings | https://docs.cloud.google.com/identity-platform/docs/admin/email-enumeration-protection |
| e2 | Its effect | confirmed | `fetchSignInMethodsForEmail` returns nothing; sign-up on an existing email still returns `EMAIL_EXISTS`; reset is silent for unknown emails | same |
| e3 | Blocking functions | confirmed | need the Identity Platform upgrade; handler must answer within 7 seconds; no separate fee | https://firebase.google.com/docs/auth/extend-with-blocking-functions |
| f1 | App Check from a non-Google backend | confirmed | JWKS at `https://firebaseappcheck.googleapis.com/v1/jwks`; header `X-Firebase-AppCheck`; `iss` uses the project number | https://firebase.google.com/docs/app-check/custom-resource-backend |
| f2 | ID-token verification without the Admin SDK | confirmed | RS256; `aud` is the project id; `iss` is `https://securetoken.google.com/<project id>`; revocation is not checked | https://firebase.google.com/docs/auth/admin/verify-id-tokens |

Consequences: Firebase stays inside free tiers at the current scale once the aggregate
trigger is fixed. The AI analysis model must be replaced now. Muto cannot pass review
without block-user and a moderation response path. Data localization is an open legal
question that only the owner can close.

---

## 13. Design research

Source quality: the "AI look" material is practitioner opinion. NN/g, W3C and Flutter
documentation are primary. Material 3 and Apple HIG pages rendered only as outlines.

### 13.1 Tells of generated or generic UI, as checkable rules

| Tell | Rule | Source |
|---|---|---|
| Decorative gradients | no gradient fills on surfaces, buttons or headers | https://world.hey.com/kostac/spot-the-slop-a-ui-designer-s-guide-to-fixing-ai-defaults-4c448c9c |
| Glow or blur behind content | no `BackdropFilter` or large blurred shadows outside an allow-list | https://builtin.com/articles/ai-design-slop-era |
| Uniform radius, padding and card height | few radii; exactly one primary element per screen | same as first row |
| Cards around everything | a container only for one self-contained item; none nested | https://developer.android.com/develop/ui/compose/components/card |
| Three equal tiles as the main content | lists first | https://builtin.com/articles/ai-design-slop-era |
| No typographic decisions | no inline font sizes outside the theme | first source |
| Copy that fits any product | every empty, error and onboarding string names the specific object | https://builtin.com/articles/ai-design-slop-era |
| Missing states | each list screen ships loading, empty and error | first source |
| Illustration plus two generic lines | one sentence and one action | https://www.nngroup.com/articles/empty-state-interface-design/ |
| Uninformative errors | name what failed and one fix | https://builtin.com/articles/ai-design-slop-era |
| Same fade on everything | motion only for state change | first source |
| Coloured left stripe on panels | none | first source |
| Low contrast on tinted surfaces | body text 4.5:1, large text 3:1, for every seed | https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html |

### 13.2 Light and fast feel

| Technique | Rule | Source |
|---|---|---|
| Touch response | visible reaction within 100 ms; over 1 s needs a working state; over 10 s needs progress and cancel | https://www.nngroup.com/articles/response-times-3-important-limits/ |
| Skeletons | for page or list loads of about 1 to 10 s; under 1 s show nothing; the skeleton mirrors the real layout | https://www.nngroup.com/articles/skeleton-screens/ |
| Durations | Flutter `Durations.short3` 150 ms, `short4` 200 ms, `medium1` 250 ms | https://api.flutter.dev/flutter/material/Durations-class.html |
| Reduce motion | `MediaQuery.disableAnimations`; the Flutter page says it does not reflect the iOS setting | https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html |
| Haptics | light, on key confirmations only; selection feedback is not a confirmation | https://api.flutter.dev/flutter/services/HapticFeedback-class.html |
| Frame budget | 16 ms per frame at 60 Hz, measured in profile mode on the weakest supported device | https://docs.flutter.dev/perf/best-practices |
| AI output label | one plain text label near the output | https://cloudscape.design/patterns/genai/output-label/ |

No official cold-start target exists; the budget must come from a measured baseline.

### 13.3 Organising many services

- Tab bars work up to about five destinations; hidden navigation cut discoverability by more
  than 20% (https://www.nngroup.com/articles/mobile-navigation-patterns/,
  https://www.nngroup.com/articles/hamburger-menus/).
- A service hub with recents, pinned items and search scales without new tabs
  (https://miniprogram.alipay.com/docs/miniprogram/design/service-center).
- Hosted features share one shell: the same top bar, back behaviour and primary-button
  position (https://core.telegram.org/bots/webapps).
- Progressive disclosure: at most two levels
  (https://www.nngroup.com/articles/progressive-disclosure/).

### 13.4 Feeds

- Infinite scroll suits homogeneous browsing; restore the scroll position on return
  (https://www.nngroup.com/articles/infinite-scrolling-tips/).
- No source supports a ranking recipe for a small campus feed. Chronological with a short
  pinned section is a simplification, not a sourced rule.
- Do not show "no results" while loading
  (https://www.nngroup.com/articles/empty-state-interface-design/).

### 13.5 Flutter techniques

Lazy lists (`ListView.builder`), `const` subtrees, a `child:` on animated builders, no
intrinsic passes in lists, avoid `saveLayer` (`Opacity`, `ShaderMask`), `RepaintBoundary`
around animating islands, decode images at display size (`cacheWidth`), no shader warm-up
(Impeller), measure with `addTimingsCallback` in profile mode
(https://docs.flutter.dev/perf/best-practices, https://docs.flutter.dev/perf/impeller,
https://docs.flutter.dev/perf/metrics). Deferred components split downloads on Android and
web only; iOS is not documented (https://docs.flutter.dev/perf/deferred-components).

### 13.6 Where the research disagrees with the design rules

| Topic | Research | Resolution taken in `DESIGN.md` |
|---|---|---|
| Spinners | fine for a single button or small module | inline spinner allowed inside a button; pages and lists use skeletons or cached content |
| Shimmer | endorsed as an activity signal | banned as a gradient; skeletons are static |
| Service hub grid | the reference hub is an icon grid | list rows |
| AI label icon | a sparkle icon is the common convention | text only |
| Motion | Material allows up to 400 ms and more | 150, 200, 250 ms only |
| Touch targets | WCAG minimum is 24 px | 48 dp |
| iOS reduce motion | not covered by `disableAnimations` | read `MediaQuery.disableAnimations` and `accessibleNavigation`; device check listed as an open item |

---

## 14. Open unknowns

Each is either assigned to a task that measures it or to the owner in `USER_ACTIONS.md`.

| Unknown | Closes in |
|---|---|
| Whether Android builds today with the current toolchain | SDK task |
| Real Firestore usage per day | owner (Firebase console), then the cost task |
| Whether App Check is enforced for Firestore or Auth in the console; share of traffic with valid tokens | owner, before App Check enforcement |
| Whether email enumeration protection and a password policy are on | owner |
| API key restrictions; whether the shipped iOS bundle id matches the placeholder | owner |
| Count of unverified accounts and of users on old app versions | owner (console and store analytics) |
| Client IP source inside callables | measured on the staging project in the email-code task |
| Whether old clients survive a closed `email_index` write | checked in the rules task before closing writes |
| Whether production Clavis has bookings under legacy student ids | owner or the Clavis identity task (read-only query) |
| Which process runs the EventsBot workers in production; the EventsBot domain | owner |
| Whether any offsite backup works today | backup task |
| Applicability of data localization to this app | owner (legal advice) |
| Whether NUmer tolerates courses with no timetable slot; units of `credits` | first Gradus task (spot check in code) |
| Whether Gradus shipped standalone with user data | owner |
| Cold-start baseline and target device | observability task |
| iOS reduce-motion flag in Flutter | device check in the motion task |
| The EventsBot Telegram Mini App screens | not needed for the plan (the Mini App stays as is) |
