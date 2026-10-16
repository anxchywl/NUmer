# P2-02: Module roles as custom claims

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
Module backends take a user's role from the `numer_roles` custom claim of the ID token.
Provide the two ways that claim gets set: a local script for the owner to create the first
administrator, and a callable for administrators afterwards.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-07
- `functions/src/shared/` (validation, admin, app check)
- `functions/scripts/backfill.js` (how scripts initialise the Admin SDK)
- `firestore/firestore.rules` (the server-only blocks)

## Context
- Claim: `numer_roles`, an array of strings, sorted, without duplicates.
- Allowed values, and nothing else: `gradus:operator`, `clavis:operator`, `events:admin`,
  `muto:admin`, `numer:editor`, `numer:admin`.
- Custom claims are limited to 1000 bytes in total and reach a client on its next token
  refresh. Other custom claims a user may have must be preserved.
- Removing a role must take effect soon, so the user's refresh tokens are revoked.

## Steps
1. `functions/src/roles/roles.ts` (pure): `ALLOWED_ROLES`; `normalizeRoles(input: unknown): string[]` throwing `HttpsError('invalid-argument', 'Unknown role.')` for a non-array, a non-string entry or a value outside the list, and returning the sorted unique list; `hasRole(token, role)` reading `token.numer_roles` safely.
2. `functions/src/roles/set_user_roles.ts`: callable `setUserRoles({uid, roles})`:
   - require auth; require `hasRole(context.auth.token, 'numer:admin')`, else
     `permission-denied`;
   - `assertId(uid)`, `normalizeRoles(roles)`;
   - an administrator may not remove `numer:admin` from themselves (`failed-precondition`);
   - read the target's existing custom claims, replace only `numer_roles`, and reject with
     `failed-precondition` if the JSON of the result exceeds 1000 bytes;
   - `setCustomUserClaims`; if any role was removed, `revokeRefreshTokens(uid)`;
   - write `roleAudit/{auto id}`: `{actor, target, before, after, at}`;
   - return `{roles}`.
   Call `requireAppCheck` the way the other callables in the repo do at the time of this task.
3. `functions/scripts/set_roles.js --uid <uid> --roles <comma list> [--dry-run]`: the same normalization (require the built `lib/roles/roles.js`), the same merge, prints before and after. With `--dry-run` it changes nothing. Add the npm script `roles:set`.
4. Export `setUserRoles`; add it to the exports test. In `firestore/firestore.rules` add a deny block for `roleAudit` next to the other server-only blocks, and one assertion to the rules tests that a client cannot read or write it.
5. Tests:
   - `functions/test/unit/roles.test.ts`: normalization sorts and de-duplicates; rejects an
     unknown value, a number, a non-array.
   - `functions/test/emulator/set_user_roles.test.ts` (Auth emulator): a caller without
     `numer:admin` is denied; an administrator sets `['muto:admin']` on a user and the user's
     claims contain it while another existing claim is preserved; removing a role moves
     `tokensValidAfterTime` forward; an administrator cannot drop their own `numer:admin`; one
     audit document is written per call.
6. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`.

## Non-goals
- Do not add a UI for roles.
- Do not store roles anywhere except the custom claim (the audit document is a log, not a source).
- Do not invent new role names.

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
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] `node functions/scripts/set_roles.js --uid x --roles nope --dry-run` exits non-zero.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Run the script once for your own uid with `numer:admin,numer:editor`, then sign out and in (`docs/numer2/USER_ACTIONS.md` D-2).

## Deliverable
Branch `numer2/p2-02-module-roles`, one commit, message `feat: add module roles as custom claims` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The Auth emulator does not return custom claims or `tokensValidAfterTime` to the test.
