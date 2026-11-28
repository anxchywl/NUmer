# P4-01: Gradus package: `numer_ui`, token provider, host chrome

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** Gradus (`/Users/anx/gradus`) @ `main`   **Depends on:** P3-02

## Goal
Make `gradus_feature` mountable inside NUmer: it draws with NUmer's design language through
`numer_ui`, asks the host for a fresh Firebase ID token on every request, and keeps its
controller when only the token changes.

## Read first
- `AGENTS.md` of this repo (binding), and NUmer's `docs/numer2/DECISIONS.md` section F and
  D-42 (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `/Users/anx/numer_app/packages/numer_ui/MIGRATION.md` (the whole file; it is the recipe)
- `/Users/anx/numer_app/docs/DESIGN.md` sections 5.4, 5.7, 7.2, 9 and 9.5
- `gradus_feature/lib/gradus_feature.dart` (94 lines), `lib/src/config/gradus_session.dart`
  (38), `lib/src/config/gradus_scope.dart` (76), `lib/src/data/http_syllabus_importer.dart`
  (198), `lib/src/presentation/focus_mode.dart` (196), `course_form.dart`,
  `assignment_form.dart`, `semester_form.dart`, `gradus_screen.dart:40-160`
- `gradus_app/lib/main.dart` (112), `scripts/verify.sh`, `.github/workflows/ci.yml:110-150`

## Context
- Line numbers are from Gradus `main` at `b341230`. Find code by name if it moved.
- Today `GradusSession` holds `accessToken` and `accountId`. `_GradusFeatureState.didUpdateWidget`
  (`gradus_feature.dart:64-73`) disposes the controller when the token changes, and
  `GradusScope` is keyed on the token (`gradus_feature.dart:87`) and notifies on it
  (`gradus_scope.dart:73-75`). Firebase tokens rotate hourly, so inside NUmer this would
  throw away the loaded transcript every hour.
- The token contract (NUmer D-42), identical in every module:
  `typedef GradusIdToken = Future<String> Function({bool forceRefresh});` is called before
  every request and never stored. On a 401 the package calls
  `Future<bool> Function() onSessionExpired` once; when it returns true it repeats the same
  request once with a new `idToken()`; when it returns false, or the repeat is a 401 again,
  it raises the failure it raises today for that status (`SyllabusImportProblem.unavailable`
  through `_problemOf`). It never calls `onSessionExpired` twice for one request.
- `numer_ui` lives in the NUmer repository at `packages/numer_ui`. Modules depend on it by
  git tag `numer-ui-v0.1.0` (D-42). The NUmer remote is `https://github.com/anxchywl/NUmer.git`.
- `GradusChrome.host` already exists (`gradus_session.dart:19`) and `GradusScreen` returns
  its body without a `Scaffold` in that mode (`gradus_screen.dart:143`). Nothing to build
  there; NUmer passes it (P4-04).
- `creditsRatio` has RU and KK values (`app_ru.arb:72`, `app_kk.arb:72`) and only metadata in
  EN (`app_en.arb:235`). Nothing in `lib/` or `test/` uses it: delete it.
- The three forms use the module's own `SheetFocusMode`; `MIGRATION.md` "Focus mode" moves
  them to `NumerSheetFocusMode`, `NumerSheetBody` and `showNumerFormSheet`. Those sheets
  open on the root navigator, which is above `GradusStringsScope` and `GradusScope`, so
  every builder re-wraps its form in both, exactly as `_openCourse`
  (`gradus_screen.dart:105-118`) does for the pushed route.
- `AGENTS.md:20`, `README.md:35`, `docs/INFRASTRUCTURE.md:83` and `scripts/verify.sh:2` say
  verify runs everything CI runs. CI also runs the Android debug build, shellcheck, the
  Docker build, gitleaks and deployment validation (`ci.yml` jobs other than the test job).
- The dev host needs a seed colour for `NumerTheme.build`: use `Colors.indigo`, NUmer's
  default (`/Users/anx/numer_app/lib/app/app_theme.dart:12`).

## Steps
1. `gradus_feature/pubspec.yaml` and `gradus_app/pubspec.yaml`: replace the `app_ui` path
   entry with
   ```yaml
   numer_ui:
     git:
       url: https://github.com/anxchywl/NUmer.git
       path: packages/numer_ui
       ref: numer-ui-v0.1.0
   ```
   Run `flutter pub get` in both.
2. Apply `MIGRATION.md` steps 1 to 4 to every Dart file under `gradus_feature/lib`,
   `gradus_feature/test`, `gradus_app/lib` and `gradus_app/test`. The seven
   `AppColors.primary` uses (`course_form.dart:580`, `gradus_screen.dart:310` and `:342`,
   `gradus_widgets.dart:185`, `:348`, `:353`, `:398`) become `AppColors.of(context).primary`;
   `course_form.dart:580` reads one name and drops the `isLight` choice. The
   `AppPrimaryButton(color: ...)` at `gradus_widgets.dart:230-236` drops `color` (it becomes
   `destructive: true` if the colour was an error colour). No Gradus button passes
   `isLoading`, so no `loadingHint` is needed. The `AppLoader()` at `gradus_screen.dart:162`
   becomes `AppLoader(page: true)`. `test/boundaries/layer_boundaries_test.dart` names
   `package:app_ui/` among the imports `domain` may not use: change it to
   `package:numer_ui/`.
3. Focus mode: apply `MIGRATION.md` "Focus mode" to `course_form.dart`,
   `assignment_form.dart` and `semester_form.dart`. Replace the four `showModalBottomSheet`
   calls that open them (`gradus_screen.dart:43`, `:82`, `course_detail_screen.dart:39`,
   `:70`) with one new helper, `lib/src/presentation/scoped_sheet.dart`: `Future<T?>
   showGradusFormSheet<T>(BuildContext context, {required WidgetBuilder form})`, which reads
   `GradusScope.of(context)` once and calls `showNumerFormSheet` with a builder returning
   `GradusStringsScope(child: GradusScope(session: ..., controller: ..., child:
   form(context)))`. `doneLabel` is the existing key `done` (`app_en.arb:70`). Delete
   `lib/src/presentation/focus_mode.dart` and its test.
4. `confirm_dialog.dart`: keep `confirmDestructiveAction(context, {required String
   message})` and make its body `showNumerConfirm(context, title: message, confirmLabel:
   strings.delete, destructive: true)` (read `strings` before the call; the sheet's cancel
   label is `numer_ui`'s own).
5. Delete `app_ui/`. Remove `app_ui` from the package loops and the path filter in
   `scripts/verify.sh:21` and `.github/workflows/ci.yml:45`, `:121`, `:131`, `:137`, and the
   `(cd app_ui && flutter test --no-pub)` line at `:143`. Replace the `AppTheme.lightTheme`
   and `AppTheme.darkTheme` in `gradus_app/lib/main.dart:33-34` with
   `NumerTheme.build(seed: Colors.indigo, brightness: Brightness.light)` and `.dark`.
6. Token provider in `gradus_session.dart`: add the typedef `GradusIdToken`. `GradusSession`
   becomes `const GradusSession({required this.idToken, required this.accountId,
   required this.onSessionExpired})` with `final GradusIdToken idToken`, `final String
   accountId`, `final Future<bool> Function() onSessionExpired`; `isPresent` is
   `accountId.isNotEmpty`. Remove `accessToken` everywhere. Export `GradusIdToken` from
   `gradus_feature.dart`, and widen two exports so NUmer can supply its own repository
   (P4-04): `src/domain/repositories.dart` shows `GradeScaleRepository, SyllabusImporter,
   TranscriptRepository`, and a new line exports
   `src/data/in_memory_transcript_repository.dart` showing `StaticGradeScaleRepository`.
7. `HttpSyllabusImporter` takes `required GradusIdToken idToken` and `required Future<bool>
   Function() onSessionExpired` instead of `accessToken`. In `importFromFile`, move the POST
   into a private `Future<http.Response> _post(List<int> bytes, String contentType, String
   key)` that awaits `idToken()` for its header (any exception thrown by `idToken()` becomes
   `SyllabusImportFailure(SyllabusImportProblem.unavailable)`); compute the idempotency key once before the
   first attempt so the repeat sends the same key. On a 401 apply the contract in Context.
   `createSyllabusImporter` in `gradus_scope.dart:30-33` takes the same two parameters.
8. Keys: in `gradus_feature.dart` the controller is recreated only when `accountId` changes
   (drop the token comparison at line 67), and the `GradusScope` key is
   `ValueKey(widget.session.accountId)`. `GradusScope.updateShouldNotify` compares
   `accountId` instead of `accessToken`. The comment at line 86 becomes `// a new account
   remounts the subtree, discarding the previous one`.
9. `gradus_app/lib/main.dart:72-90`: build the session from the development token as
   `GradusSession(idToken: ({forceRefresh = false}) async => token, accountId: role.name,
   onSessionExpired: () async => false)` and pass the same two functions to
   `createSyllabusImporter`.
10. Delete `creditsRatio` and `@creditsRatio` from the three ARB files; run
    `flutter gen-l10n` in `gradus_feature`.
11. Docs: in `AGENTS.md:20`, `README.md:35`, `docs/INFRASTRUCTURE.md:83` and
    `scripts/verify.sh:2` say that verify runs the formatting, analysis, tests and coverage
    floors of CI, and not the Android build, shellcheck, the Docker build, gitleaks or the
    deployment validation. Replace `app_ui` with `numer_ui` in `AGENTS.md` "Packages" and in
    `docs/ARCHITECTURE.md:22-40` and `docs/INFRASTRUCTURE.md:21`: `numer_ui` comes from the
    NUmer repository by git tag; product concepts never go into it. Remove the sentence
    about `app_ui/test/token_parity_test.dart` and the `app_ui/test` row of
    `docs/ARCHITECTURE.md:463`, and fix `AGENTS.md:25,31-36,141`.
12. Tests (hand-written fakes, `flutter_test`):
    - `gradus_feature/test/gradus_feature_test.dart`: pump `GradusFeature` with a
      hand-written subclass of `GradusDependencies` whose `createController` override counts
      calls and returns a controller whose `dispose` is counted; rebuild it with a new `GradusSession` whose
      `idToken` returns a different string and the same `accountId`: the controller is
      created once and not disposed; rebuild with a different `accountId`: a second
      controller is created and the first disposed.
    - `gradus_feature/test/data/http_syllabus_importer_test.dart` (extend the existing
      file): `idToken` is called once per request and its value is the bearer header; a 401
      then `onSessionExpired() == true` repeats once with the new token and the same
      `Idempotency-Key`, and `onSessionExpired` is called exactly once; a 401 with
      `onSessionExpired() == false` raises `SyllabusImportProblem.unavailable` with one
      request sent; two 401s in a row raise it with two requests sent and one
      `onSessionExpired` call.
    - Update every test that built `GradusSession(accessToken: ...)`
      (`config/gradus_session_test.dart`, `presentation/course_detail_screen_test.dart:40`,
      `presentation/gradus_screen_test.dart:57,80`, and any the analyzer names).
    - Each migrated form: a widget test that focuses a field with a non-zero
      `MediaQuery.viewInsets.bottom` and asserts the title is hidden and a "Done" button
      shows; tapping Done shows the title again.
13. Run the `MIGRATION.md` step 6 grep from the repo root, then `./scripts/verify.sh`.

## Non-goals
- No change to the domain, the controller's behaviour, the backend or the GPA rules.
- No NUmer code; the Hive repository and the mount are P4-02 to P4-04.
- Do not add `GradusChrome` values or change `PreferencesTranscriptRepository`.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart` (which re-exports `numer_ui.dart`). No new colour, radius, text style, font or icon package; no `TextStyle(` or raw `Color` in feature code. Every icon-only control has a tooltip.
- Every sheet or dialog with a text field uses focus mode (`MIGRATION.md` "Focus mode"). A loading button shows only its spinner and passes `loadingHint`.
- Every user-facing string is in `app_en.arb`, `app_ru.arb` and `app_kk.arb` under `gradus_feature/lib/src/l10n/arb/`; run `flutter gen-l10n`.
- The token is never written to disk, a log, a key or a field that outlives one request.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 with the coverage floor of 85 for `gradus_feature`.
- [ ] The `MIGRATION.md` step 6 grep prints only `AppColors.of` and `AppTextStyles.of` lines.
- [ ] `grep -rn "accessToken" gradus_feature gradus_app --include='*.dart'` prints nothing.
- [ ] `app_ui/` and `gradus_feature/lib/src/presentation/focus_mode.dart` are gone; `grep -rn "app_ui" . --include='*.yaml' --include='*.yml' --include='*.sh' --include='*.md' --include='*.dart'` prints nothing (outside `.claude/`).
- [ ] The tests of step 12 exist and pass; the controller test asserts one creation across a token change.
- [ ] `grep -rn "creditsRatio" gradus_feature/lib` prints nothing.
- [ ] Screenshots of the GPA screen, the course form while typing and the confirm sheet, from `gradus_app`, light and dark, EN and RU, attached.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: in NUmer, `git tag numer-ui-v0.1.0 <main commit> && git push origin numer-ui-v0.1.0` (`USER_ACTIONS.md` F-0).
- After review: `git tag v0.2.0 && git push origin v0.2.0` in Gradus.

## Deliverable
Branch `numer2/p4-01-gradus-package`, one commit, message `feat: move gradus to numer_ui and a token provider` (subject line only). Do not push.
Report: files changed, verify output, the grep outputs, screenshots, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot resolve `numer_ui` at `numer-ui-v0.1.0` (the tag is not pushed).
- A compat name the code uses is missing from `numer_ui` and not listed in `MIGRATION.md`.
- A form cannot be expressed as a `NumerSheetBody` and does not fit the stepped-flow fallback in `MIGRATION.md`.
