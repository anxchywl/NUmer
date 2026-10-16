# P0-04: Split the functions source and add a test harness

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-01, P0-02

## Goal
`functions/src/index.ts` is one file of about 1200 lines with no tests. Split it by area with
identical exports, so later tasks can work in parallel without conflicts, and add unit and
emulator test harnesses for functions and for Firestore rules.

## Read first
- `AGENTS.md`
- `functions/src/index.ts` (all of it)
- `functions/package.json`, `functions/tsconfig.json`
- `firebase.json`
- `firestore/firestore.rules` (only to know it exists; do not edit)
- `scripts/verify.sh`, `.github/workflows/ci.yml` (both created by P0-02)

## Context
- Exports today (9): `onStudySessionWrite`, `onCourseWrite`, `onGroupMemberDelete`,
  `deleteGroup`, `deleteGroupCallable`, `deleteAccountCallable`, `joinPrivateGroup`,
  `getMemberSubjectStats`, `sendNudge`. Deployed function names are the export names, so they
  must not change.
- P0-01 removed `analyzeCourseAi` and all Gemini code. If `analyzeCourseAi` or
  `GoogleGenerativeAI` is still in the file, stop: P0-01 has not been merged.
- `functions/package.json` has `firebase-admin` and `firebase-functions` (`^7.0.2`, used
  through the v1 import); scripts `build` (`tsc`), `backfill`,
  `backfill:email`; `main` is `lib/index.js`.
  Compiled code moves one directory deeper after the split.
- The client's emulator switch expects Firestore on port 8080 and Functions on 5001
  (`lib/main.dart:102`).
- Emulator tests need Java on the machine (use the version the pinned `firebase-tools`
  requires; Java 17 satisfies current releases).
- Installing packages from the public npm registry, and letting `firebase-tools` download
  its emulator binaries, is allowed in this task. No deploy and no real project.

## Steps
1. Create this layout and move code into it without changing any function body:

   ```
   functions/src/index.ts                       re-exports only
   functions/src/shared/admin.ts                the single admin.initializeApp(), exports db and auth
   functions/src/shared/app_check.ts            requireAppCheck (still a no-op), isEmulator
   functions/src/shared/periods.ts              startOfDay, PeriodKey, resolvePeriodRange
   functions/src/aggregates/update_user_aggregates.ts
   functions/src/aggregates/triggers.ts         onStudySessionWrite, onCourseWrite
   functions/src/groups/cleanup.ts              deleteQueryBatch, deleteUserCollections, deleteGroupCascade, removeUserMemberships (all exported)
   functions/src/groups/triggers.ts             onGroupMemberDelete, deleteGroup
   functions/src/groups/callables.ts            deleteGroupCallable, joinPrivateGroup, getMemberSubjectStats
   functions/src/account/delete_account.ts      deleteAccountCallable
   functions/src/nudges/send_nudge.ts           sendNudge
   ```
   Any other top-level symbol goes to the file of its only user, or to `functions/src/shared/`
   when two areas use it. No file may exceed 400 lines; if one would, split it by function
   into the same folder.
2. Function bodies move unchanged. Text that is moved as is,
   including log lines with emoji and error text returned to clients, stays as it is; list
   such places in the report for later tasks.
3. `functions/src/index.ts` contains only export lines, each written on one line: `export { a, b } from './<area>/<file>';`.
4. Add dev dependencies pinned to exact versions (the current stable release of each, written
   without `^`): `jest`, `ts-jest`, `@types/jest`, `firebase-functions-test`,
   `@firebase/rules-unit-testing`, `firebase-tools`. `firebase-functions-test` is not used by
   this task's tests; the tasks that follow use it to wrap triggers and callables.
   Add `functions/jest.config.js` (`preset: 'ts-jest'`, `testEnvironment: 'node'`, `testMatch`
   `<rootDir>/test/unit/**/*.test.ts`) and `functions/jest.emulator.config.js` (the same preset
   and environment, `testMatch` `<rootDir>/test/emulator/**/*.test.ts` and
   `<rootDir>/test/rules/**/*.test.ts`, `testTimeout: 30000`). Keep `tsconfig.json` building
   `src` only, and confirm after `npm run build` that `lib/index.js` still exists.
5. Add scripts to `functions/package.json`:
   `"test": "jest"`,
   `"test:emulator": "firebase emulators:exec --only firestore,auth --project demo-numer \"jest --config jest.emulator.config.js --runInBand\""`.
   Both are run from the `functions/` directory.
6. In `firebase.json` add an `emulators` block: firestore port 8080, auth port 9099, functions port 5001, `ui.enabled: false`. Change nothing else in the file.
7. Add tests:
   - `functions/test/unit/exports.test.ts`: the sorted keys of `require('../../src/index')`
     equal the 9 names above. Importing the index initialises the Admin SDK but makes no
     Firestore call; add no mocks.
   - `functions/test/rules/smoke.test.ts`: with `initializeTestEnvironment({projectId:
     'demo-numer', firestore: {rules: fs.readFileSync('../firestore/firestore.rules', 'utf8')}})`
     (the path is relative to `functions/`), an unauthenticated client cannot write `users/u1`;
     `u1` can write `users/u1`.
8. In `scripts/verify.sh` replace the functions step with `(cd functions && npm ci && npm run build && npm test)`. Add `emulator tests (run: cd functions && npm run test:emulator)` to the header list of what it does not run.
9. In `.github/workflows/ci.yml` add a job `functions-emulator` (Node 20, Java 17) that runs `cd functions && npm ci && npm run test:emulator`.
10. Run `npm run build`, `npm test`, `npm run test:emulator` and `./scripts/verify.sh`.

## Non-goals
- Do not change any function's behaviour, name, trigger path, options or log text.
- Do not fix bugs you notice while moving code; list them in the report.
- Do not edit `firestore/firestore.rules`.
- Do not delete `getMemberSubjectStats` or `deleteGroup` (that is P0-07).

## Constraints
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test` exits 0.
- [ ] `cd functions && npm run test:emulator` exits 0.
- [ ] `find functions/src -name '*.ts' -exec wc -l {} +` shows no file above 400 lines (ignore the `total` row).
- [ ] `grep -cvE "^export \{[^}]+\} from '\./" functions/src/index.ts` prints 0 once blank lines are removed from the count (the file holds only one-line exports).
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The report lists each moved top-level symbol with its new file, and states that no function body changed.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p0-04-split-functions`, one commit, message `refactor: split functions by area and add test harness` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `analyzeCourseAi` or `GoogleGenerativeAI` is still in `index.ts`.
- Java is not installed (the emulator cannot start).
- Two areas share mutable module-level state that a split would duplicate.
- `firebase-functions` `^7` does not expose the v1 API the tests need.
