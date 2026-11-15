# P1-02: Email-code callables

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-01, P0-06

## Goal
Implement the five callables that replace Firebase's email links with 6-digit codes: two for
verifying an email, three for resetting a password. They decide who may take over an
account, so storage, limits and responses follow the reviewed design exactly.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-18
- `docs/numer2/RESEARCH.md` sections 4.2 and 4.3
- `functions/src/mail/` (all files)
- `functions/src/shared/validation.ts`, `functions/src/shared/admin.ts`
- `functions/test/emulator/` (test style)

## Context
Constants: code life 600 s; resend cooldown 60 s; 5 attempts per code; ticket life 600 s;
password length 8 to 128.

Storage (server-only, already denied in the rules):
- `authCodes/verify_<uid>` and `authCodes/reset_<sha256 hex of normalized email>`: `purpose`,
  `uid` (null for a dummy row), `emailHash`, `codeId`, `codeHash`, `keyVersion`, `attempts`,
  `createdAt`, `expiresAt`, `resendAvailableAt`, `consumedAt`, `ticketHash`,
  `ticketExpiresAt`, `ticketConsumedAt`, `locale`, `ttlAt` (= `expiresAt` + 1 day; the TTL
  policy is on `ttlAt`, never on `expiresAt`).
- `authRateLimits/<sha256 hex of key>_<window start seconds>`: `count`, `expiresAt`.
- `authAudit/<auto id>`: `action`, `uid` or `emailHash`, `ipHash`, `result`, `at`,
  `expiresAt` (= now + 90 days). Never a code, a ticket or an address.

Secret: `AUTH_CODE_SECRET` (key version 1).
Hashing: `HMAC-SHA256(secret, JSON.stringify([purpose, subject, code, codeId]))`, hex.
`subject` is the uid for `verify` and the email hash for `reset`.
Email normalization: `trim().toLowerCase()`. Email shape: at most 254 characters and
`/^[^\s@]+@[^\s@]+\.[^\s@]+$/`.

Errors are `HttpsError(code, message, {reason, ...})`. The client reads `details.reason`.

| Callable | Auth | Input | Success | Errors (`code`: `reason`) |
|---|---|---|---|---|
| `sendEmailVerificationCode` | required | `{locale}` | `{status: 'sent' | 'cooldown' | 'already-verified', resendAvailableAt, expiresAt}` (milliseconds) | `unauthenticated`; `resource-exhausted`: `rate-limited` with `retryAfterSeconds`; `unavailable`: `delivery-failed` |
| `verifyEmailCode` | required | `{code}` | `{verified: true}` | `invalid-argument`: `malformed-code`; `permission-denied`: `invalid-code` with `attemptsLeft`; `deadline-exceeded`: `code-expired`; `resource-exhausted`: `too-many-attempts` or `rate-limited`; `not-found`: `no-active-code` |
| `requestPasswordResetCode` | none | `{email, locale}` | always `{status: 'accepted', resendAvailableAt}` | `invalid-argument`: `invalid-email`; `resource-exhausted`: `rate-limited` |
| `verifyPasswordResetCode` | none | `{email, code}` | `{resetTicket}` | `permission-denied`: `invalid-or-expired-code`; `resource-exhausted`: `too-many-attempts` or `rate-limited` |
| `confirmPasswordReset` | none | `{email, resetTicket, newPassword}` | `{success: true}` | `invalid-argument`: `weak-password`; `permission-denied`: `invalid-or-expired-ticket`; `resource-exhausted`: `rate-limited` |

Limits (fixed windows): sends per email hash 3 per 900 s and 10 per 86400 s; sends per uid 5
per 3600 s; sends per IP hash 10 per 3600 s; verify calls per uid or email hash 20 per
900 s; verify calls per IP hash 30 per 3600 s; all sends 2000 per 86400 s. Limit keys have
the form `<action>:<dimension>:<value>`, for example `send:email:<hash>`. Check the
narrowest limit first and the global one last.

More rules for inputs and edge cases:
- `locale` other than `en`, `ru`, `kk` is treated as `en`.
- `email` not matching the shape, `code` not six digits, a missing or non-string
  `resetTicket` (expected: 43 base64url characters) or `newPassword`: `invalid-argument`
  with reason `malformed-input` (for `requestPasswordResetCode` the reason stays
  `invalid-email`, for `verifyEmailCode` it stays `malformed-code`).
- A verification call whose token has no email: `failed-precondition`, reason `no-email`.
- `already-verified` returns `resendAvailableAt` and `expiresAt` equal to the current time.
- The server checks only the password length. It applies no character rule.
- IP: use `context.rawRequest.ip`; when it is empty, skip the per-IP limits for that call
  (never put all such callers in one bucket). The IP limits are a secondary control; App
  Check is the main one for the unauthenticated callables. The global send cap can be
  exhausted by an attacker who gets past App Check; state this in the report as a known
  limit.
- Known and accepted: someone who knows an address can request a reset for it and so
  replace a pending code.
- Secrets per callable: the two verification callables need `AUTH_CODE_SECRET` and
  `MAIL_API_KEY`; the three reset callables need `AUTH_CODE_SECRET` only (their mail goes
  through the queue).
- `AUTH_ENFORCE_APPCHECK=on` is deliberate: only app versions that contain the new flow call
  these three functions.
- Structure every callable as `functions...https.onCall((data, context) => handleX(data,
  context, deps))` with an exported `handleX` and a `deps` object `{mail: MailSender, now: ()
  => number}`. Tests call `handleX` directly in the test process with a fake sender and a
  controllable clock; the functions emulator is not started.

App Check: the three unauthenticated callables are created with
`runWith({enforceAppCheck: process.env.AUTH_ENFORCE_APPCHECK !== 'off', secrets: [...]})`.
Tests run with it off.

## Steps
1. `functions/src/auth/codes.ts` (pure): `generateCode()` =
   `crypto.randomInt(0, 1_000_000)` left-padded to 6; `newCodeId()` = 16 random bytes hex;
   `hashCode(secret, purpose, subject, code, codeId)`; `generateTicket()` = 32 random bytes
   base64url; `hashTicket(secret, docId, ticket)` =
   `HMAC-SHA256(secret, JSON.stringify(['ticket', docId, ticket]))`; `safeEqualHex(a, b)` using
   `crypto.timingSafeEqual` after a length check; `sha256Hex(s)`; `normalizeEmail`;
   `isValidEmail`; `isSixDigits`.
2. `functions/src/auth/rate_limits.ts`: `hit(key: string, limit: number, windowSeconds: number):
   Promise<{allowed: boolean, retryAfterSeconds: number}>`. One transaction on the document for
   the current window (`windowStart = floor(now / window) * window`): if `count >= limit` return
   not allowed with the seconds to the window end; else increment and set `expiresAt` to the
   window end plus one hour. `hitAll(checks[])` runs them in order and returns the first
   refusal.
3. `functions/src/auth/challenge.ts`:
   - `replaceChallenge(docId, fields)`, one transaction: if a live document exists whose
     `resendAvailableAt` is in the future, write nothing and return
     `{cooldown: true, resendAvailableAt, expiresAt}`; otherwise set the document (no merge)
     with a fresh `codeId`, `attempts: 0` and the timestamps, and return
     `{cooldown: false, codeId, ...}`. Only a caller that wrote sends an email.
   - `checkCode(docId, purpose, subject, code): Promise<'ok' | 'none' | 'expired' | 'locked' |
     {invalid: attemptsLeft} | {ok: true, resetTicket}>` in one transaction: missing or
     consumed gives `none`; `attempts >= 5` gives `locked`; past `expiresAt` gives `expired`;
     otherwise increment `attempts` first, then compare; on a mismatch return the attempts
     left; on a match set `consumedAt` and, when `purpose` is `reset`, create the ticket and
     store `ticketHash` and `ticketExpiresAt` in the same transaction. A row with `uid: null`
     never matches.
   - `releaseCode(docId, codeId)` and `releaseTicket(docId)`: clear `consumedAt` or
     `ticketConsumedAt` again, used when the step after a successful check fails.
4. `functions/src/auth/email_verification.ts`:
   - `sendEmailVerificationCode`: email and uid from `context.auth` only. Already verified
     (`context.auth.token.email_verified` or the Admin user record) returns `already-verified`.
     Then `replaceChallenge`; a `cooldown` result is returned as status `cooldown` and nothing
     is sent or counted. Otherwise apply the send limits (uid, email hash, global); if one
     refuses, delete the document you just wrote (only if its `codeId` is still yours) and
     throw `rate-limited`. Then render and send inline through `deps.mail`. If the send throws
     `MailDeliveryError`, delete the document under the same `codeId` condition and throw
     `unavailable` / `delivery-failed`.
   - `verifyEmailCode`: format check, the verify limit, `checkCode`; on `ok` call
     `admin.auth().updateUser(uid, {emailVerified: true})`; if that call fails, `releaseCode`
     and throw `HttpsError('internal', 'Try again.')`; map the other results to the table.
5. `functions/src/auth/password_reset.ts`:
   - `requestPasswordResetCode`: validate; the send limits (email hash, IP hash, global). Look
     up `admin.auth().getUserByEmail`. For an existing, enabled user: `replaceChallenge` with
     the uid, then `enqueueMail(email, 'reset', locale, {code})`. For anyone else:
     `replaceChallenge` with `uid: null` and a random hash, then
     `enqueueMail(null, 'reset', locale, {})`. A `cooldown` result from `replaceChallenge`
     skips the enqueue in both branches. Both branches perform the same writes and return
     `{status: 'accepted', resendAvailableAt}`.
   - `verifyPasswordResetCode`: the verify limits; `checkCode`; on a match return the
     `resetTicket` it created. `none`, `expired` and invalid all return
     `invalid-or-expired-code`; `locked` returns `too-many-attempts`.
   - `confirmPasswordReset`: validate; in one transaction load the document, require a matching
     `ticketHash`, an unexpired and unconsumed ticket, and a non-null `uid`, then set
     `ticketConsumedAt`; any failure is `invalid-or-expired-ticket`. Then
     `admin.auth().updateUser(uid, {password, emailVerified: true})`; if it fails,
     `releaseTicket` and throw `HttpsError('internal', 'Try again.')` (never the provider's
     message). Then `admin.auth().revokeRefreshTokens(uid)` and
     `enqueueMail(email, 'passwordChanged', locale, {})`.
6. `functions/src/auth/audit.ts`: `audit(action, {uid?, emailHash?, ipHash?, result})` writes one `authAudit` document. Call it once per callable invocation with the outcome. The IP hash is `sha256Hex(secret + ':' + (context.rawRequest.ip || ''))` cut to 32 characters.
7. Export the five callables from `functions/src/index.ts`; add them to the exports test. Add `AUTH_ENFORCE_APPCHECK=on` to `functions/.env.example`.
8. Tests. Unit (`functions/test/unit/auth_codes.test.ts`): 1000 generated codes are 6 digits
   and include at least one starting with 0 within 100000 tries using a seeded stub of
   `randomInt`; the same inputs hash equally; changing any one of purpose, subject, code,
   codeId changes the hash; `safeEqualHex` rejects different lengths.

   Emulator (`functions/test/emulator/auth_*.test.ts`, fake mail sender, Auth emulator users):
   - verification: send then verify succeeds and the Auth user is verified; the code is found
     nowhere in Firestore in plain text (scan every document of `authCodes`, `mailQueue`,
     `authAudit`); a second send inside 60 s returns `cooldown` and sends nothing; a wrong code
     returns `invalid-code` with `attemptsLeft: 4`; the fifth wrong code leaves the next call
     `too-many-attempts` even with the right code; a code past `expiresAt` (move the clock by
     rewriting the document) returns `code-expired`; a new send makes the old code invalid;
     six concurrent wrong guesses leave `attempts` at 5 or less; with the clock moved 61
     seconds forward between sends, the fourth send in 15 minutes returns `rate-limited`; two
     concurrent sends produce exactly one email; a failing mail sender returns
     `delivery-failed` and leaves no document; a failing `updateUser` leaves the code usable.
   - reset (the queue trigger is not run in these tests): the responses for an existing and an
     unknown email are deeply equal and both write one `authCodes` and one `mailQueue`
     document; verify with the right code returns a ticket;
     the ticket works once; a second use returns `invalid-or-expired-ticket`; a 7-character
     password returns `weak-password` and does not consume the ticket; after success the user
     can sign in with the new password, is marked verified, and
     `tokensValidAfterTime` moved forward; a dummy row never yields a ticket; an unknown email
     with any code returns `invalid-or-expired-code`.
9. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`.

## Non-goals
- Do not change the client (P1-04, P1-05).
- Do not disable or edit Firebase's own email templates or flows.
- Do not read or write `email_index`.
- Do not store a code, a ticket or an email address in plain text anywhere, including logs and audit rows. The exceptions are `mailQueue.to` and `mailQueue.vars.code`, which exist only until the queue trigger has handled the document.
- Do not add Redis or any package.

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
- Every decision about a code or ticket happens inside a Firestore transaction.
- The reset request must not branch in any observable way on whether the account exists: same writes, same response, no awaited provider call.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0, with every test of step 8 present.
- [ ] No `functions.logger` call in `functions/src/auth` receives a variable holding a code, ticket, password or address: list every logger call of the folder in the report (`grep -rn -A3 "logger\." functions/src/auth`) with what it logs.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The report contains a table mapping each row of the limits list to the test that covers it.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Create `AUTH_CODE_SECRET` in both projects; add TTL policies on `authCodes.ttlAt`, `authRateLimits.expiresAt`, `mailQueue.expiresAt`, `authAudit.expiresAt`; deploy to staging first (`docs/numer2/USER_ACTIONS.md` C-3).

## Deliverable
Branch `numer2/p1-02-email-code-callables`, one commit, message `feat: add email code callables for verification and reset` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `runWith({enforceAppCheck})` is not accepted by the installed `firebase-functions` v1 API.
- The Auth emulator does not expose `tokensValidAfterTime` or `emailVerified` updates the tests need.
- A requirement in the table conflicts with another (report both; do not choose).
