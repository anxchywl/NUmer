# P4-10: Events package: `numer_ui`, token provider, base URL

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 6 h
**Repo / working dir:** EventsBot (`/Users/anx/events_bot`) @ `main`   **Depends on:** P3-02

## Goal
First of three Events package tasks (D-42 split P4-10 into P4-10, P4-16 and P4-17): the
Flutter package `events_feature` (`flutter_events/`) draws with `numer_ui`, gets a fresh
Firebase ID token from the host for every request, takes its API base URL from the host,
and loses the screens nothing opens.

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` section F and D-42
  (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `/Users/anx/numer_app/packages/numer_ui/MIGRATION.md` (whole file)
- `/Users/anx/numer_app/docs/DESIGN.md` sections 5.4, 9 and 9.5
- `flutter_events/pubspec.yaml`, `lib/main.dart`, `lib/app.dart` (414 lines),
  `lib/core/constants.dart` (38), `lib/core/api_client.dart:60-140` (`_uri`, `_headers`,
  `_request`) and the rest of that file by name, `lib/core/auth_store.dart` (115),
  `lib/core/exceptions.dart`, `lib/core/dev_session.dart`
- `.github/workflows/ci.yml:144-200` (the `flutter` job), `flutter_events/README.md`

## Context
- Line numbers are from EventsBot `main` at `a5a44ef`. Find code by name if it moved.
- The package is `events_feature` in `flutter_events/`; it has no `scripts/verify.sh`. The
  CI `flutter` job runs in `flutter_events/`: `flutter pub get`, `dart format
  --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test
  --no-pub`, and a release build with `--dart-define=API_BASE_URL=https://events.example.edu
  --dart-define=ENABLE_STANDALONE_DEV_ACCESS=false`. Its change filter names `app_ui`
  (`ci.yml:173`).
- Today the host passes `EventsHostSession(accessToken)` (`app.dart:38-43`);
  `_bootstrapHostSession` (`:127-173`) calls `bootstrapSession(token)` and keeps the token
  in memory (`AuthStore.save(..., persist: false)`), and `api_client.dart:75-82` reads
  `AuthStore.token` for every header. A 401 marks the session expired
  (`AuthStore.expireIfCurrent`) and `EventsFeature` calls `onSessionExpired`
  (`VoidCallback`).
- The token contract (NUmer D-42), identical in every module:
  `typedef EventsIdToken = Future<String> Function({bool forceRefresh});` awaited for every
  request in host mode, never stored; on a 401 call `Future<bool> Function()
  onSessionExpired` once; on true repeat the same request once with a new `idToken()`; on
  false, or a second 401, take today's expired path. Standalone mode keeps today's stored
  development token.
- The base URL today is the top-level `final String kBaseUrl` from `--dart-define
  API_BASE_URL` (`constants.dart:16-38`). In host mode the host passes it; the standalone
  app keeps the define and its debug fallbacks.
- Screens with no construction site (`grep -rn "<Name>(" lib test` finds only the class):
  `features/stub/stub_screen.dart`, `features/calendar/calendar_screen.dart`,
  `features/moderation/pending_events_screen.dart`. `AppCalendar` and `AppCalendarEvent`
  are also used by `events_screen.dart` (`:478`, `:502-508`, `:822-843`), so they move into
  the package (`MIGRATION.md`, "Removed names") before `app_ui` goes.
- Size of the migration: 285 `AppColors.` and 98 `AppTextStyles.` references in about 20 files.
  `event_manager_screen.dart` (2830 lines), `submit_screen.dart` (1994),
  `event_detail_screen.dart` (1739) and `events_screen.dart` (1464) hold most. The rename
  is mechanical: `AppColors.x` -> `AppColors.of(context).x`; where no `BuildContext` is in
  scope (a `const` field, a top-level helper) pass the colour in from the nearest build
  method.
- `intl: ^0.19.0` (`pubspec.yaml:17`) conflicts with NUmer's `intl: ^0.20.2`; Gradus and
  Muto use `intl: any`.
- The dev host seed for `NumerTheme.build` is `Colors.indigo`.

## Steps
1. `flutter_events/pubspec.yaml`: replace the `app_ui` path entry with the `numer_ui` git
   entry (`url: https://github.com/anxchywl/NUmer.git`, `path: packages/numer_ui`, `ref:
   numer-ui-v0.1.0`); `intl: any`. `flutter pub get`.
2. Copy `app_ui/lib/calendar/app_calendar.dart` and `app_calendar_event.dart` into
   `flutter_events/lib/features/shared/calendar/`, switch `events_screen.dart` to them, and
   restyle them with `numer_ui` names in step 3. Then delete the three screens of Context and
   anything only they import, and delete `app_ui/`.
   Remove `app_ui` from `ci.yml:173` and from docs (`README.md`, `flutter_events/README.md`,
   `docs/INFRASTRUCTURE.md`; `grep -rn "app_ui" --include='*.md' .`).
3. Apply `MIGRATION.md` steps 1 to 4 to every file under `flutter_events/lib` and
   `flutter_events/test`, file by file, running `flutter analyze --no-pub` after each of
   the four large files. Every `AppPrimaryButton`, `AppSecondaryButton` or `AppTextButton`
   that passes `isLoading` also passes `loadingHint: AppLocalizations.get('loading')`
   (add `'loading': 'Loading'` to the `en` map of `core/localization.dart` if absent; P4-16
   moves all strings). Replace `AppTheme.lightTheme` and `.darkTheme` in `app.dart`
   (`EventsApp`) with `NumerTheme.build(seed: Colors.indigo, brightness: ...)`, and drop
   `themeMode: ThemeMode.light`.
4. Base URL: in `core/constants.dart` replace `final String kBaseUrl = _resolveBaseUrl();`
   with `abstract final class EventsApi { static String baseUrl = ''; static String
   resolveStandalone() => <body of _resolveBaseUrl>; }` and keep the release-mode
   `StateError`. `_uri` (`api_client.dart:68`) reads `EventsApi.baseUrl`; a request with an
   empty base URL throws `StateError('the events base url is not set')`. `main.dart` sets
   `EventsApi.baseUrl = EventsApi.resolveStandalone()` before `runApp`. Update the doc
   comment at `constants.dart:5-15` into one-line comments that follow the comment rule.
5. Token provider:
   - `EventsHostSession({required EventsIdToken idToken, required String accountId,
     required Future<bool> Function() onSessionExpired})`; export `EventsIdToken`.
   - `EventsFeature({required EventsHostSession session, required Uri baseUrl})`: in
     `initState` set `EventsApi.baseUrl = baseUrl.toString()` (strip a trailing `/` so
     paths keep their leading one) and `AuthStore.useHost(session)`. Remove the old
     `onSessionExpired` `VoidCallback` parameter; the session carries it.
   - `AuthStore.useHost(EventsHostSession? host)` keeps the host in a static field;
     `AuthStore.clear()` also clears it. In host mode `AuthStore.token` is never set;
     `AuthStore.saveHost({required String role, String? firstName, required int userId})`
     stores the profile in memory, and `isLoggedIn` is true when a host is set and a profile
     was saved. `expireIfCurrent` and `_requestTokens` stay for standalone mode; in host
     mode a 401 that survives the retry calls a new `AuthStore.expireHost()` that bumps
     `sessionExpiryChanges`.
   - Every other reader of the token or the base URL moves too:
     `core/realtime_updates.dart:48-54` awaits `host.idToken()` for each connect in host mode
     (and calls `expireHost()` on a 401) and builds its URL from `EventsApi.baseUrl`;
     `uploadCover` (`api_client.dart:~292-330`) builds its `MultipartRequest` inside the
     closure given to `_request`, so it gets the header and the retry;
     `models/analytics_model.dart:16` and `models/event_model.dart:140` read
     `EventsApi.baseUrl`.
   - `api_client.dart`: `_headers` becomes `Future<Map<String, String>> _headers({bool
     auth = false})`: in host mode `'Bearer ${await host.idToken()}'`, otherwise today's
     `AuthStore.token`. `_get`, `_post`, `_patch`, `_delete` and the multipart upload build
     their headers inside the closure passed to `_request`, so `_request` can send it a
     second time. In `_request`, when the response is 401, the request was authenticated
     and a host is set, call `host.onSessionExpired()` once; on true resend once and return
     the second response; on false return the 401 so today's path (`_throwFor`,
     `expireIfCurrent`) runs. `_rememberRequestToken` and `expireIfCurrent` keep working
     for standalone mode; in host mode a 401 that survives the retry marks the session
     expired through `AuthStore` the same way.
   - `_bootstrapHostSession`: drop the `accessToken` checks; call `bootstrapSession()`
     with no token argument (it uses `_headers(auth: true)`); keep the profile save with
     `AuthStore.saveHost(...)`. `didUpdateWidget` re-bootstraps only when
     `accountId` changes, and then calls `AuthStore.clear()` first.
6. `lib/main.dart` keeps the standalone path (`EventsApp`, dev session); it compiles with
   the new constants.
7. Tests (`flutter_test`, hand-written `http.Client` fakes through
   `setApiClientForTesting`):
   - `test/api_client_host_test.dart`: in host mode `idToken` is awaited once per request
     and is the bearer; a 401 with `onSessionExpired() == true` sends twice with the second
     token and calls it once; with `false` it sends once and raises
     `UnauthorizedException`; two 401s send twice, call once and raise; a request with no
     base URL throws `StateError`.
   - `test/app_bootstrap_test.dart` (extend): a new `EventsHostSession` with the same
     `accountId` and a different `idToken` does not re-run the bootstrap request; a
     different `accountId` does, and clears the stored profile first.
   - Every existing test compiles against the new constructors and passes; the cases in
     `test/app_bootstrap_test.dart:396-514` that used `EventsHostSession(accessToken: ...)`,
     a blank token or the `onSessionExpired` `VoidCallback` become the same cases with an
     `idToken` fake and `onSessionExpired` returning false.
   - `test/realtime_updates_host_test.dart`: in host mode a connect awaits `idToken` once and
     sends it as the bearer.
8. Run the CI `flutter` job commands in `flutter_events/`, including the release build with
   the two defines, and the `MIGRATION.md` step 6 grep from `flutter_events/`.

## Non-goals
- No move of strings to ARB (P4-16). No host chrome, filter rows or focus mode (P4-17).
- No backend change. No change to the Mini App or `frontend/`.
- No behaviour change beyond the token, the base URL and the deleted screens.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart`. No new colour, radius, text style, font or icon package. Every icon-only control has a tooltip.
- A loading button shows only its spinner and passes `loadingHint`.
- The token is never written to disk, a log or a field that outlives one request in host mode.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings (convert the `///` you touch), debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] The CI `flutter` job commands pass in `flutter_events/`, including the release build.
- [ ] The `MIGRATION.md` step 6 grep prints only `AppColors.of` and `AppTextStyles.of` lines.
- [ ] `grep -rn "kBaseUrl\|accessToken" flutter_events/lib` prints nothing; `grep -rn "AuthStore.token" flutter_events/lib` shows only standalone paths; `app_ui/` and the three screens are gone; `AppCalendar` lives under `lib/features/shared/calendar/`.
- [ ] The tests of step 7 exist and pass.
- [ ] Screenshots from the standalone app against a local backend (starting the backend locally with the repo's `docker compose` is allowed; nothing remote): the events list, an event detail, the submit form, the coordinator dashboard; light and dark, EN.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` F-0 (the `numer-ui-v0.1.0` tag).
- None after it; the release tag follows P4-17.

## Deliverable
Branch `numer2/p4-10-events-package`, one commit, message `feat: move events to numer_ui and a token provider` (subject line only). Do not push.
Report: files changed, each command's output, the grep output, screenshots, anything left for P4-16 or P4-17.

## Stop and ask if
- `flutter pub get` cannot resolve `numer_ui` at `numer-ui-v0.1.0`.
- A colour reference has no `BuildContext` reachable without changing a public signature.
- One of the three screens of Context turns out to be constructed somewhere.
