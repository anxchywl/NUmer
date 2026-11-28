# P4-13: Muto package: `numer_ui`, token provider, host chrome

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 6 h
**Repo / working dir:** Muto (`/Users/anx/muto`) @ `main`   **Depends on:** P3-02

## Goal
Make `muto_feature` and `muto_ui` mountable inside NUmer: NUmer's design language through
`numer_ui`, a fresh Firebase ID token for every request with state keyed on the user, its
sections as tabs under NUmer's app bar, "New listing" as the one floating action, and focus
mode in its two text sheets. Block and report UI is P4-20 (D-42 split).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` section F and D-42
  (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `/Users/anx/numer_app/packages/numer_ui/MIGRATION.md` (whole file)
- `/Users/anx/numer_app/docs/DESIGN.md` sections 3.3, 5.3, 5.6, 5.7, 5.10, 9 and 9.5
- `muto_feature/lib/muto_feature.dart`, `lib/src/presentation/muto_feature_widget.dart`
  (156 lines), `lib/src/presentation/shell/muto_shell.dart` (357),
  `lib/src/application/session_controller.dart`, `lib/src/application/muto_scope.dart`,
  `lib/src/data/remote/{remote_auth,remote_api_client,remote_dependencies}.dart`,
  `lib/src/presentation/shared/focus_mode.dart`, `lib/src/presentation/report/report_sheet.dart`,
  `lib/src/presentation/editor/listing_editor_sheet.dart` (1410),
  `lib/src/presentation/shared/contact_buttons.dart` (356)
- `muto_app/lib/host_app.dart`, `scripts/verify.sh`, `.github/workflows/ci.yml:40-50,190-210`

## Context
- Line numbers are from Muto `main` at `9467cc5`. Find code by name if it moved.
- Packages: `muto_app -> muto_feature -> muto_ui -> app_ui`. 173 `AppColors.` and 57
  `AppTextStyles.` references in `muto_feature` and `muto_ui`.
- Today the host passes `MutoHostSession(accessToken)`; `MutoScope` is keyed on the token
  (`muto_feature_widget.dart:64-71`); `SessionController.resolve(accessToken)` starts a
  session and `RemoteAuthState.beginSession(token)` bumps `sessionNamespace`, which every
  request sends as `account_session` to keep caches per session
  (`remote_api_client.dart:74`). A 401 clears the token and throws `UnauthorizedFailure`
  (`:157-161`); the session then calls `onSessionExpired` (`VoidCallback`,
  `session_controller.dart:103`).
- The token contract (NUmer D-42), identical in every module:
  `typedef MutoIdToken = Future<String> Function({bool forceRefresh});` awaited for every
  request, never stored; on a 401 call `Future<bool> Function() onSessionExpired` once; on
  true repeat the same request once with a new `idToken()`; on false, or a second 401,
  throw `UnauthorizedFailure` as today. State is keyed on `accountId` (the Firebase uid):
  `sessionNamespace` changes only when the account changes.
- Shell (`muto_shell.dart:127-165`): an `IndexedStack` of one `Navigator` per destination
  and a bottom bar; students get Browse, Favorites, My listings, operators get Browse and
  Reports; the compose button shows on the root of My listings only (`:133-135`). Host
  chrome (D-42, `DESIGN.md` 9.5): the role is known only after the session resolves, so
  the package draws a text-only `TabBar` under NUmer's app bar with Browse, Favorites, My
  listings, and for operators also Reports (all users start on Browse; who may publish
  stays `session.canPublish`); "New listing" is a `NumerFab(icon:
  Icons.add, label: strings.newListing, ...)` on the My listings tab root only. In host
  chrome, listing detail, seller profile and the editor are pushed on the root navigator
  so they cover the module screen (`DESIGN.md` 3.3), each re-wrapped in `MutoScope` and
  `MutoLocalizationsScope`.
- Contact channels (`contact_buttons.dart:45-75`): brand colours `socialTelegram`,
  `socialWhatsapp` and brand icons. `DESIGN.md` 9.5: rows with a generic icon
  (`AppIcons.send` for Telegram, `AppIcons.chat` for WhatsApp, `AppIcons.email`,
  `AppIcons.phone`) and the channel name as the row title.
- Focus mode (`MIGRATION.md` table): `report/report_sheet.dart` (one field,
  `AppBottomSheet.show`) and `editor/listing_editor_sheet.dart` (stepped, its own
  `showModalBottomSheet` on the nested navigator). Muto's `shared/focus_mode.dart` is
  deleted.
- The dev host seed for `NumerTheme.build` is `Colors.indigo`.

## Steps
1. Replace the `app_ui` entry in `muto_ui/pubspec.yaml` (and in `muto_feature` and
   `muto_app` if they name it) with the `numer_ui` git entry (`url:
   https://github.com/anxchywl/NUmer.git`, `path: packages/numer_ui`, `ref:
   numer-ui-v0.1.0`). `flutter pub get` in each package.
2. Apply `MIGRATION.md` steps 1 to 4 to every file under `muto_ui`, `muto_feature` and
   `muto_app` (`lib` and `test`). Buttons that pass `isLoading` pass `loadingHint` (add a
   `loadingHint` key: EN "Loading", RU "Загрузка", KK "Жүктелуде" if absent). `host_app.dart:72-73`
   uses `NumerTheme.build(seed: Colors.indigo, brightness: ...)`.
3. Delete `app_ui/`; remove it from `PACKAGES`-style loops and filters in
   `scripts/verify.sh`, `.github/workflows/ci.yml:46`, `:199`, and from `AGENTS.md:16-25,97`,
   `README.md:38,44`, `docs/ARCHITECTURE.md:24-29,106` (the chain becomes `muto_app ->
   muto_feature -> muto_ui -> numer_ui`, with `numer_ui` from the NUmer repository by tag).
4. Token provider: `MutoHostSession({required MutoIdToken idToken, required String
   accountId, required Future<bool> Function() onSessionExpired})`; export `MutoIdToken`.
   `RemoteAuthState` holds the host session: `beginSession(String accountId)` bumps the
   namespace only for a new account; `_headers` awaits `idToken()`; `_send` resends once on
   a 401 per the contract. The token parameter goes from the whole resolve chain:
   `SessionRepository.resolve()` (`domain/repositories/session_repository.dart`), its remote
   and mock implementations, `RemoteApiClient.resolveSession()` and
   `SessionController.resolve()`, whose `_reportedForToken` de-duplication keys on the
   account id instead. `MutoFeature.onSessionExpired` (`VoidCallback`) is removed; after the
   contract gives up (false, or a second 401) `SessionController` moves to its expired state
   as today and calls nothing more. `MutoScope` is keyed on `accountId`. The mock repository
   and `muto_app` keep working with a session whose `idToken` returns their development
   token.
   Listing images: today `RemoteImageLocator.locate` (`remote_repositories.dart:276-288`)
   bakes `_api.authorizationHeaders()` into a `CachedNetworkImageProvider`
   (`presentation/images/listing_image_provider.dart:11-17`), which cannot hold an async,
   unstored token. Replace it with `presentation/images/authorized_image_provider.dart`: an
   `ImageProvider<AuthorizedImageKey>` whose key is the URI plus `sessionNamespace`, and whose
   `loadImage` awaits `idToken()`, fetches the file with
   `DefaultCacheManager().getSingleFile(uri, key: <uri>#<namespace>, headers: {'Authorization':
   'Bearer <token>'})` and decodes it. Add `flutter_cache_manager` (already in the lock through
   `cached_network_image`) as a direct dependency at the locked version. `ImageLocation`
   carries no headers any more.
5. Host chrome: `MutoFeature` gains `this.chrome = MutoChrome.own` (`enum MutoChrome { own,
   host }`, exported). In `host`, `MutoShell` builds a `DefaultTabController` with a
   `Column(TabBar, Expanded(TabBarView))` of the destinations of Context (each still its
   own `Navigator` so tab stacks survive switching), wraps it in a `Scaffold` whose
   `floatingActionButton` is the `NumerFab` on the My listings root, and pushes detail,
   seller and editor routes on the root navigator per Context. `own` keeps today's shell.
6. Contact channels per Context: each channel is a `NumerRow(leading: AppIcon(<generic>),
   title: <channel name>, onTap: <today's action>)` in one `NumerBlock`; delete the brand
   colour and brand icon switches.
7. Focus mode for the two sheets per `MIGRATION.md`: the report sheet is a `NumerSheetBody`
   with one field opened by `showNumerFormSheet`; the editor keeps its body inside
   `showNumerFormSheet` and uses the stepped-flow fallback, its `doneLabel` the existing
   "Done" string or a new `done` key (EN "Done", RU "Готово", KK "Дайын"). Both re-wrap
   `MutoScope` and `MutoLocalizationsScope`. Delete `shared/focus_mode.dart` and its test.
8. Tests:
   - `muto_feature/test/data/remote_api_client_test.dart` (extend or create): the token is
     awaited per request; a new token with the same `accountId` keeps `account_session`;
     a new `accountId` changes it; the 401 cases of the contract (true: two requests, one
     call; false: one request, `UnauthorizedFailure`; two 401s: two requests, one call).
   - `muto_feature/test/presentation/host_shell_test.dart`: host chrome as a student shows
     three tabs and the FAB only on My listings; as an operator four tabs; no bottom bar;
     opening a listing covers the tabs (the `TabBar` is no longer in the visible route).
   - Focus-mode tests for both sheets (title hidden with keyboard insets; Done restores).
   - `contact_buttons` test: one row per channel with its name, no brand colour.
       - `test/presentation/authorized_image_provider_test.dart`: the provider awaits
      `idToken` at load time and sends it; two providers for the same URI and namespace are
      equal; a new namespace gives a new key.
    - Every icon-only control you touched has a non-empty tooltip or semantics label.
9. Run the `MIGRATION.md` step 6 grep from the repo root and `./scripts/verify.sh` (coverage
   floor 70 for `muto_feature`).

## Non-goals
- No block, report-status or operator-action UI (P4-20). No backend change.
- `muto_ui`'s `filter_pill.dart`, `meta_chip.dart` and `selectable_chip.dart` stay as they
  are in this task (DESIGN 11 is checked in NUmer's `lib/` only); a later design pass
  replaces them.
- No change to listing rules, caching or the image pipeline.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart`; the two-column photo grid stays (allowed for listings, `DESIGN.md` 5.10). No new colour, radius, text style, font or icon package. Every icon-only control has a tooltip.
- Every sheet or dialog with a text field uses focus mode; a loading button shows only its spinner and passes `loadingHint`.
- Every user-facing string in the three ARB files.
- The token is never written to disk, a log, a cache key or a field that outlives one request.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings (convert the `///` you touch), debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 with the coverage floor of 70.
- [ ] The `MIGRATION.md` step 6 grep prints only `AppColors.of` and `AppTextStyles.of` lines.
- [ ] `grep -rn "accessToken\|socialTelegram\|socialWhatsapp" muto_feature/lib muto_ui/lib` prints nothing; `app_ui/` and `shared/focus_mode.dart` are gone.
- [ ] The tests of step 8 exist and pass.
- [ ] Screenshots from `muto_app` (sample backend) in host chrome: browse grid, a listing detail, my listings with the FAB, the editor while typing, the report sheet while typing, the contact rows; light and dark, EN and RU.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` F-0 (the `numer-ui-v0.1.0` tag).
- None after it; the release tag follows P4-20.

## Deliverable
Branch `numer2/p4-13-muto-package`, one commit, message `feat: move muto to numer_ui and a token provider` (subject line only). Do not push.
Report: files changed, verify output, the grep outputs, screenshots, anything left for P4-20.

## Stop and ask if
- `flutter pub get` cannot resolve `numer_ui` at `numer-ui-v0.1.0`.
- A compat name the code uses is missing from `numer_ui` and not listed in `MIGRATION.md`.
- Pushing detail routes on the root navigator breaks a flow that returns a result to a tab (for example the editor's saved listing).
