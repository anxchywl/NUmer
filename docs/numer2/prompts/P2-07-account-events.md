# P2-07: Account events fan-out

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P2-01, P1-07, P0-04

## Goal
When a NUmer account is deleted, every module backend must delete its part too (an App
Store requirement). P1-07 writes an event document; this task delivers it to each module
with a signature and retries, and gives the modules a library function to verify it.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-08
- `functions/src/account/purge_user.ts` (where the event is written)
- `functions/src/mail/resend_sender.ts` (the `fetch` with timeout pattern)
- `backend/numer_identity/` (package layout, tests, README)
- `firestore/firestore.indexes.json`

## Context
- Event document: `accountEvents/{id}` with `{type: 'account.deleted', issuer, subject,
  occurredAt, status: 'pending'}`. Server-only collection.
- Delivery: `POST <module url>` with the JSON body
  `{"id": ..., "type": ..., "issuer": ..., "subject": ..., "occurredAt": "<ISO 8601>"}` and
  the header `X-Numer-Signature: t=<unix seconds>,v1=<hex>` where the hex is
  `HMAC-SHA256(secret, "<t>.<raw body>")`. Any 2xx answer is success. Handlers are
  idempotent on `id`.
- Targets: at most three (`clavis`, `events`, `muto`; Gradus stores nothing). Their URLs
  come from the parameter `ACCOUNT_EVENT_TARGETS`, a JSON array of
  `{"module": "...", "url": "https://..."}` kept in the functions env file, never in the
  repo. Secrets have fixed names: `ACCOUNT_EVENTS_SECRET_CLAVIS`,
  `ACCOUNT_EVENTS_SECRET_EVENTS`, `ACCOUNT_EVENTS_SECRET_MUTO`.
- Retry for 72 hours with backoff 15 min, 30 min, 1 h, 2 h, 4 h, then every 6 h; after 72
  hours mark the target failed and log an error. The scheduler runs every 15 minutes, so
  real spacing rounds up to that.
- P1-07 creates the event as `accountEvents/deleted_<uid>` without `nextAttemptAt`.
- A Firestore trigger is not retried by default and the emulator does not run scheduled
  functions, so the retry logic must be callable on its own and must not depend on the
  first delivery attempt having finished.
- Tests call the logic in the test process; the functions emulator is not started. The test
  harness (`npm test`, `npm run test:emulator`, `functions/test/unit/exports.test.ts`) comes
  from P0-04.

## Steps
1. `functions/src/account/event_signature.ts` (pure): `signEvent(secret, timestampSeconds,
   rawBody): string` returning the header value; `nextAttemptAt(attempts, now): Date`
   implementing the backoff, where `attempts` counts the attempt just made (1 gives 15
   minutes, 2 gives 30, 3 gives 60, 4 gives 120, 5 gives 240, 6 or more gives 360);
   `serializeEvent(id, data): string` producing the body with `JSON.stringify` (no spaces),
   keys in the order given in Context, and `occurredAt` as
   `data.occurredAt.toDate().toISOString()`.
2. `functions/src/account/event_delivery.ts`:
   - `loadTargets(raw: string | undefined, options: {allowLoopbackHttp: boolean})`: empty or
     unset means no targets; rejects a module name outside the three, a duplicate, and any URL
     whose `new URL(url).protocol` is not `https:` (with `allowLoopbackHttp`, `http:` is also
     accepted for the hosts `127.0.0.1` and `localhost`; the functions pass
     `process.env.FUNCTIONS_EMULATOR === 'true'`);
   - `deliverPending(eventRef, targets, now, fetchImpl = fetch)`: first, if the document has no
     `nextAttemptAt`, write `nextAttemptAt = now + 15 minutes`, so an interrupted run is picked
     up by the retry. Then, for each target not yet delivered, in parallel
     (`Promise.allSettled`), post with a 10 second timeout, reading that target's secret from
     `process.env` at call time; record per target in the document under `deliveries.<module>`:
     `{status: 'delivered' | 'pending' | 'failed', attempts, lastAttemptAt, lastHttpStatus}`;
     set the document's `status` to `delivered` when every target is delivered, to `failed`
     when 72 hours have passed since `occurredAt` (logging
     `functions.logger.error('account_event_delivery_failed', {id, module})` once per failed
     target), else `pending` with `nextAttemptAt`. Write the result in a transaction that
     re-reads the document and never turns a target or the event from `delivered` or `failed`
     back to `pending`. With no targets the event becomes `delivered` at once. Never log the
     body or a secret.
   - `retryDueEvents(db, now, targets, fetchImpl = fetch)`: queries `accountEvents` where
     `status == 'pending'` and `nextAttemptAt <= now`, limit 20, and calls `deliverPending` for
     each.
3. `functions/src/account/events.ts`:
   - `onAccountEventCreated`: Firestore `onCreate` on `accountEvents/{id}`, with
     `runWith({secrets, timeoutSeconds: 120})`, calling `deliverPending`;
   - `retryAccountEvents`:
     `functions.runWith({secrets, timeoutSeconds: 540}).pubsub.schedule('every 15 minutes')`,
     calling `retryDueEvents`.
   Export both; add them to the exports test. Add the composite index (`status` ascending,
   `nextAttemptAt` ascending) to `firestore/firestore.indexes.json`.
4. Library, `backend/numer_identity/src/numer_identity/account_events.py`:
   `@dataclass(frozen=True, slots=True) class AccountEvent(id, type, issuer, subject,
   occurred_at)`; `class SignatureInvalid(Exception)`;
   `verify_account_event(*, secret: str, signature_header: str | None, raw_body: bytes, now:
   float, tolerance_seconds: int = 300) -> AccountEvent`. It parses the header (a non-integer
   `t` is rejected; several `v1=` values may be present, so a secret can be rotated), rejects
   a timestamp when `abs(now - t) > tolerance_seconds`, accepts when any `v1` value equals the
   expected HMAC under `hmac.compare_digest`, then parses the JSON and requires the five keys
   as non-empty strings (`occurred_at` stays a string, as sent) and `type` to be
   `account.deleted` or `account.disabled`. Export it from the package, bump the version to
   `0.2.0` in `pyproject.toml` and `__version__` (add a test that the two are equal), and add
   a README section with a 12-line FastAPI handler example that answers 200
   for an event id it has already processed.
5. Tests:
   - `functions/test/unit/event_signature.test.ts`: a known secret, timestamp and body string
     give a fixed expected header (compute it once with Node's `crypto` and paste the value;
     the vector is pinned by the final body string); the backoff sequence; `loadTargets`
     accepts https, rejects http, and accepts loopback http only with the option.
   - `backend/numer_identity/tests/test_account_events.py`: the same fixed vector verifies (the
     two implementations agree); a changed body, a wrong secret, a timestamp 301 seconds old, a
     missing header and a malformed header are each rejected; an unknown `type` is rejected.
   - `functions/test/emulator/account_events.test.ts` with a local HTTP server as the module,
     calling `deliverPending` and `retryDueEvents` directly: one target answering 200 gives
     `delivered` and a valid signature at the server; a target answering 500 leaves `pending`
     with `nextAttemptAt` about 15 minutes ahead, and `retryDueEvents` with the clock moved
     forward, after the server recovers, gives `delivered`; an event whose first delivery
     never ran (it has only the initial `nextAttemptAt`) is delivered by `retryDueEvents`; with `occurredAt` 73 hours ago and a failing
     target the status becomes `failed`; two targets where one fails keep the delivered one
     delivered and retry only the other; no targets gives `delivered`.
6. Add `ACCOUNT_EVENT_TARGETS=[]` to `functions/.env.example`. In `docs/INFRASTRUCTURE.md` add `## Account events` after the Firebase section (the contract, the header, the retry schedule, what a module handler must do) and add the two functions to the Cloud Functions table. Run both verify scripts and `npm run test:emulator`.

## Non-goals
- Do not write module handlers (each module's integration task does).
- Do not put a module URL or a secret value into the repo.
- Do not emit `account.disabled` anywhere yet; only the type is defined.
- Do not change `purge_user.ts` beyond what is needed to keep its event document compatible.

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
- Python in `backend/numer_identity`: mypy strict, ruff, no docstrings, coverage stays at or above 95%.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] `backend/numer_identity/scripts/verify.sh` exits 0.
- [ ] The same signature vector appears in the TypeScript test and the Python test.
- [ ] `grep -rnE "https?://[a-z0-9]" functions/src/account` prints nothing.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Create one secret per module in Firebase and in each module's env file; set `ACCOUNT_EVENT_TARGETS` in the functions env file when the first module handler is deployed; push the tag `identity-v0.2.0` (`docs/numer2/USER_ACTIONS.md` D-4).

## Deliverable
Branch `numer2/p2-07-account-events`, one commit, message `feat: deliver signed account events to modules` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The v1 scheduled-function API is not available in the installed `firebase-functions`.
- A function cannot declare a secret that does not exist yet in the project without failing deploy (then report which deploy order is needed).
