# P0-15: Staging project and emulator workflow

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-14

## Goal
Auth, rules and email changes need a place to be tried that is not production. Make it
possible to deploy functions and rules to a staging Firebase project, and to run the app
against staging or the local emulators, with no way to hit production by accident.

## Read first
- `AGENTS.md`
- `docs/INFRASTRUCTURE.md` (setup, emulator and deploy sections)
- `.firebaserc`, `firebase.json`, `.gitignore`
- `lib/core/firebase_options.dart`
- `lib/app/bootstrap.dart`
- `functions/.env.example`

## Context
- Production is Firebase project `numer-60744`. Staging is project `lendings-killer`
  (display name "NUmer Staging"); the owner gives its values in the task message. They are not secrets, but they are not committed.
- `lib/core/firebase_options.dart` builds `FirebaseOptions` in Dart as `static const` values
  and takes the API keys from `--dart-define` (`FIREBASE_ANDROID_API_KEY`,
  `FIREBASE_IOS_API_KEY`). Firebase client API keys are not secrets; passing them by
  `--dart-define` or `--dart-define-from-file` is allowed here and is the one exception to
  the rule about secrets in defines.
- The native files `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` are git-ignored. On Android the native file also
  initialises the default Firebase app, so Dart options for another project conflict with
  it. The native file and the Dart options must therefore be switched together.
- `--dart-define=USE_FIRESTORE_EMULATOR=true` points Firestore at `localhost:8080` and
  Functions at `localhost:5001`. Auth has no emulator switch yet. `bootstrap.dart` reads
  `FirebaseAuth.instance.currentUser` early; the Auth emulator must be selected before any
  use of Auth.
- The emulator workflow is used in debug builds with no `APP_ENV` (which defaults to
  `production` options). That must keep working. The generic rule "development mechanisms
  are refused when `APP_ENV=production`" applies here to release builds only.
- Functions read parameters from `functions/.env.<project id>` files, which are git-ignored.
- App Check is activated in release builds; a staging release build needs the staging apps
  registered for App Check. Staging is normally run in debug.

## Steps
1. `.firebaserc`: add the alias `staging` with the project id given in the task message, next to the existing default.
2. `lib/core/firebase_options.dart`:
   - `enum FirebaseEnv { production, staging }` and a top-level
     `FirebaseEnv firebaseEnvFrom(String value)` that returns the enum for `production` and
     `staging` and throws `StateError` for anything else;
   - `const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'production')`, exported;
   - `production`: exactly today's options;
   - `staging`: options built in getters (not `const`) from the defines
     `STAGING_FIREBASE_PROJECT_ID`, `STAGING_FIREBASE_SENDER_ID`,
     `STAGING_FIREBASE_STORAGE_BUCKET` (shared), `STAGING_FIREBASE_ANDROID_APP_ID`,
     `STAGING_FIREBASE_ANDROID_API_KEY` (Android), `STAGING_FIREBASE_IOS_APP_ID`,
     `STAGING_FIREBASE_IOS_API_KEY`, `STAGING_FIREBASE_IOS_BUNDLE_ID` (iOS and macOS). When a
     shared define or one for the current platform is empty, throw a `StateError` naming it.
3. `lib/app/bootstrap.dart`: when `USE_FIRESTORE_EMULATOR` is true, call `await FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` immediately after `Firebase.initializeApp` and before anything reads `FirebaseAuth`. Throw a `StateError` when the emulator switch is on in a release build (`kReleaseMode`) with `appEnv == 'production'`. Debug builds may use the emulator with any `APP_ENV`.
4. `scripts/use_firebase_env.sh <production|staging>`: copies
   `android/app/google-services.<env>.json` to `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.<env>.plist` to `ios/Runner/GoogleService-Info.plist`. It
   exits 1 with a clear message when a source file is missing. Add exactly these lines to
   `.gitignore`: `android/app/google-services.production.json`,
   `android/app/google-services.staging.json`,
   `ios/Runner/GoogleService-Info.production.plist`,
   `ios/Runner/GoogleService-Info.staging.plist`, `env/*.json`, `!env/*.example.json`.
5. Create `env/staging.example.json` with the eight `STAGING_FIREBASE_*` keys and `APP_ENV`, all values empty except `"APP_ENV": "staging"`. The real file is `env/staging.json`, used with `flutter run --dart-define-from-file=env/staging.json`.
6. `scripts/deploy_staging.sh`: reads `.firebaserc` from the current directory and extracts the
   alias with
   `sed -n 's/.*"staging"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .firebaserc` (no `jq`,
   no node). It exits 1 with a message when the alias is missing or equals `numer-60744`, or
   when `functions/.env.<staging id>` does not exist. Otherwise it runs
   `(cd functions && npm run build)` and then
   `firebase deploy --only functions,firestore:rules,firestore:indexes --project <staging id>`.
   It accepts no arguments. Support an environment variable `DRY_RUN=1` that prints the deploy
   command instead of running it.
7. `docs/INFRASTRUCTURE.md`: add a section `## Environments` with a three-row table (emulator,
   staging, production): how to run the app against each, how to deploy to each, and where the
   env files live. Include `firebase emulators:start --only auth,functions,firestore` and, for
   an Android device or emulator, `adb reverse tcp:8080 tcp:8080` (and the same for 5001 and
   9099). State that production deploys are done by the owner by hand, and that a staging
   release build needs App Check registered for the staging apps. Remove any sentence
   elsewhere in the file that this section now contradicts.
8. Add `test/core/firebase_options_env_test.dart` for `firebaseEnvFrom`: `production`, `staging`, and a `StateError` for any other value. Run `./scripts/verify.sh` and `shellcheck scripts/use_firebase_env.sh scripts/deploy_staging.sh`.

## Non-goals
- Do not add Android product flavors or iOS schemes.
- Do not commit any app id, API key or project number of either project beyond what is already tracked.
- Do not change production behaviour: a build with no defines must behave exactly as before, including the emulator workflow in debug.
- Do not deploy anything. Never run `scripts/deploy_staging.sh` in the repository root without `DRY_RUN=1`.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- No file may contain a server address, a real domain that is not already public in a module repo, a credential or a key.
- Scripts are POSIX-friendly bash with `set -euo pipefail`, pass `shellcheck`, and never act on production data by default.
- The executor does not connect to any server. The deliverable is code and documentation that the owner runs.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `flutter analyze` and `./scripts/verify.sh` exit 0.
- [ ] In a temporary directory holding a copy of `.firebaserc` with the alias removed, `bash <repo>/scripts/deploy_staging.sh` exits 1 with a message. In the repository root, `DRY_RUN=1 bash scripts/deploy_staging.sh` prints the deploy command with the staging id (create an empty `functions/.env.<staging id>` first and delete it afterwards).
- [ ] `shellcheck` passes for both scripts.
- [ ] `git check-ignore android/app/google-services.staging.json ios/Runner/GoogleService-Info.staging.plist env/staging.json` prints all three paths, and `git check-ignore env/staging.example.json` prints nothing.
- [ ] The `Environments` section exists in `docs/INFRASTRUCTURE.md`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Create the staging project and hand over its values; copy the current native config files to `google-services.production.json` and `GoogleService-Info.production.plist`, and place the staging ones beside them as `*.staging.*` (`docs/numer2/USER_ACTIONS.md` B-10).
- Register App Check for the staging apps, or run staging in debug only.
- Run the app once against staging on a device and confirm sign-up works there.

## Deliverable
Branch `numer2/p0-15-staging-project`, one commit, message `chore: add staging environment and emulator workflow` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The task message does not contain the staging project values.
- `lib/core/firebase_options.dart` is regenerated by a tool on build (then hand edits would be lost).
- `shellcheck` is not installed.
- On Android, Dart options for staging still conflict with the native default app after the native file is switched.
