# P4-19: Muto backend: account events handler

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 4 h
**Repo / working dir:** Muto (`/Users/anx/muto`) @ `main`   **Depends on:** P2-05, P2-07, P4-12

## Goal
When a NUmer account is deleted, Muto deletes everything that person put there: listings
and their images, favourites, reports they filed and reports about their listings, blocks,
and the user. Without this the marketplace flag cannot open beyond testers (PLAN phase 4
gates). Split from P4-12 (D-42).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` D-08, D-17, D-42
- NUmer `backend/numer_identity/README.md` "Account events" and the contract in NUmer
  `docs/INFRASTRUCTURE.md` (`/Users/anx/numer_app/...`)
- `backend/app/infrastructure/db/models/{user,listing,community}.py` and the P4-12
  moderation models
- `backend/app/application/image_service.py:311-337` (`release_listing_images`),
  `storage_reconciliation.py`, `backend/app/infrastructure/storage/files.py:22-35`
  (`ImageStorage`), `backend/app/dependencies.py` (`image_storage_from`)
- `backend/app/config.py:75`, `:195-230`, `backend/pyproject.toml:31`,
  `deploy/production.env.example`, `deploy/preflight.sh:40-50`, `.env.example`
- `backend/app/api/router.py`, `api/operations.py` (router style),
  `tests/integration/test_firebase_identity.py`, `tests/conftest.py`

## Context
- Line numbers are from Muto `main` at `9467cc5` plus P4-12. Find code by name if it moved.
- Request, header and library are as in P4-07 Context: `verify_account_event` from
  `numer_identity` 0.2.0; `pyproject.toml:31` pins `identity-v0.1.0`, which lacks it.
- A user is found through `user_identities (provider_issuer, provider_subject)`
  (`models/user.py:53-70`). The issuer of NUmer's tokens is
  `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`.
- Foreign keys that block a plain delete (`ondelete="RESTRICT"`): `listings.owner_id`,
  `reports.reporter_id`, `reports.listing_id`, `image_uploads.redeemed_listing_id` (a
  `redeemed` upload may not null it, check `redemption_matches_state`) and
  `listing_images.image_upload_id`. `image_uploads.owner_id` cascades. Everything else to `users` or `listings` cascades or is set
  null (check P4-12's tables).
- Order of deletion in one transaction (D-42): reports filed by the user and reports on the
  user's listings; `listing_images` of the user's listings; the user's `image_uploads` and
  any upload whose `redeemed_listing_id` is one of the user's listings (collect their
  non-null `storage_key`s first); the user's listings; the user (identities,
  favourites, idempotency keys and blocks cascade; audit rows keep their row with the user
  set null). After the commit, delete each collected key from `ImageStorage`; a key that
  fails to delete is left for the existing `reconcile_storage` command and logged once as
  `account_image_delete_failed` with the key count, never the keys.
- `account.disabled` and an event for another issuer change nothing. Handled ids go into a
  `processed_account_events(id, processed_at)` table so a replay changes nothing.
- CI: `uv run --frozen pytest tests --cov=app --cov-fail-under=80 -q` on Postgres 16;
  `./scripts/verify.sh` runs the unit tests.

## Steps
1. `pyproject.toml:31`: `tag = "identity-v0.2.0"`; `uv lock` in `backend/`.
2. Settings: `account_events_secret: SecretStr | None` (alias `ACCOUNT_EVENTS_SECRET`); in
   the validator at `config.py:195`, `self.environment == AppEnvironment.production` with
   the firebase adapter requires it. Add
   it to `.env.example`, `deploy/production.env.example` and the required list in
   `deploy/preflight.sh` next to `FIREBASE_PROJECT_ID`.
3. Model `ProcessedAccountEvent` and one Alembic revision creating
   `processed_account_events` (`down_revision` = the P4-12 revision).
4. Service `backend/app/application/account_deletion.py`: `async def
   handle_account_event(session, storage, event, *, expected_issuer) -> None` doing the
   order of Context with SQLAlchemy statements, the processed row last, commit, then the
   storage deletes.
5. Router `backend/app/api/account_events.py`: `APIRouter(include_in_schema=False)`, `POST
   /internal/v1/account-events`, 204; no secret -> 503 (`ServiceUnavailableError`); `SignatureInvalid` -> 401
   (`UnauthorizedError`, whose code is the fixed `authentication_required`); replay ->
   204. Include it in `api/router.py`.
6. Docs: `docs/API.md` stays public-only; `docs/INFRASTRUCTURE.md` names the endpoint and
   the secret; `docs/PRODUCT.md` says what a deleted account leaves (audit rows without a
   name).
7. Tests:
   - `tests/integration/test_account_events_api.py` (Postgres, local image storage in a
     temp dir, bodies signed with the library's HMAC): a user with two listings with
     images, a favourite, a report they filed, a report by another user on their listing,
     a block in each direction and an audit row -> 204; all of those rows are gone except
     the audit row, whose user columns are null; their image files are gone from the temp
     dir; another user's listing, favourite and images are unchanged. A replay -> 204 and
     no change. Bad signature and stale timestamp -> 401 and no change. Unknown subject,
     `account.disabled` and another issuer -> 204 and no change. A storage delete that
     raises still answers 204 and leaves the database deleted.
   - `tests/unit/test_config.py` (extend): production with the firebase adapter and no
     secret refuses to start.
   - `tests/integration/test_migrations.py` (extend) for the new revision.
8. Run `./scripts/verify.sh` and the CI pytest command on Postgres 16.

## Non-goals
- No change to moderation, blocking or listings beyond what deletion needs.
- No handling of `account.disabled` beyond acknowledging it (a disabled account is already
  refused by Firebase at its next token).

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- The body is not trusted before the signature check; body, secret, header and storage keys are never logged.
- One migration; no raw SQL outside it; all database work of one event in one transaction.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle (the storage delete catches exactly `ServiceUnavailableError`, `OSError`, `botocore.exceptions.ClientError` and `botocore.exceptions.BotoCoreError`, never `Exception`).
- No secret in code, tests (use a test constant), the repo or CI.
- Do not deploy, do not push, do not connect to any server or bucket.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 and the CI pytest command passes on Postgres 16 with the floor of 80.
- [ ] Every case of step 7 has a test that passes.
- [ ] `alembic heads` shows one head; `grep -rn "identity-v0.1.0" backend/pyproject.toml` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` D-4 step 3 (push `identity-v0.2.0`).
- Approval: back up the database, set `ACCOUNT_EVENTS_SECRET` in Muto's production env, redeploy, then add `{"module": "muto", "url": "https://<muto host>/internal/v1/account-events"}` to `ACCOUNT_EVENT_TARGETS` and deploy functions (F-3).

## Deliverable
Branch `numer2/p4-19-muto-account-events`, one commit, message `feat: handle numer account deletion` (subject line only). Do not push.
Report: files changed, both test commands' output, user actions still pending.

## Stop and ask if
- `uv lock` cannot fetch `identity-v0.2.0`.
- A table that references `users` or `listings` is `RESTRICT` and not listed in Context.
