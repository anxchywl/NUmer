# P2-06: EventsBot backend: Firebase bridge

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 8 h
**Repo / working dir:** EventsBot (`anxchywl/EventsBot`) @ `main`   **Depends on:** P2-01 (tag `identity-v0.1.0` pushed)

## Goal
EventsBot has a "superapp bridge" that accepts a generic JWT, maps users by subject alone and
never demotes a role. Turn it into a Firebase bridge: verify NUmer's ID tokens with the
shared library, key users by issuer and subject, attach to an existing account that verified
the same university email, and take the role from the token on every request. The Telegram
Mini App and bot keep working unchanged.

## Read first
- `AGENTS.md` (this repo's rules are binding)
- `backend/SUPERAPP_BRIDGE.md`
- `backend/app/config.py` lines 50-110
- `backend/app/web/superapp_bridge.py` (all of it)
- `backend/app/web/flutter_auth.py` (all of it)
- `backend/app/models/user.py`, `backend/app/models/__init__.py`
- `backend/alembic/versions/` (the two newest files)
- `backend/app/services/users.py` lines 20-35, `backend/app/web/auth.py` lines 300-350
- `tests/backend/test_flutter_auth_tokens.py`, `tests/backend/test_config_superapp_guard.py`, `tests/integration/test_superapp_bridge_db.py`, `tests/integration/conftest.py`
- `docker/docker-compose.prod.yml`, `docker/Dockerfile.production`, `.env.example`, `deploy/setup-server.sh`

## Context
- NUmer signs users in with Firebase. This backend must accept the Firebase ID token as the
  bearer token and verify it with the shared library `numer_identity` (in the NUmer repo,
  consumed by git tag).
- Library surface: `FirebaseVerifier(project_id=..., key_source=GoogleX509KeySource(...))`,
  `await verifier.verify(token) -> FirebaseClaims(uid, issuer, email, email_verified, name,
  roles, ...)`; `TokenInvalid` (answer 401) and `KeysUnavailable` (answer 503);
  `numer_identity.testing` gives `make_test_keypair`, `sign_token`, `valid_claims`,
  `StaticKeySource` so tests need no network.
- Dependency line for `pyproject.toml`:
  `numer-identity = { git = "https://github.com/anxchywl/NUmer", subdirectory = "backend/numer_identity", tag = "identity-v0.1.0" }`
  under `[tool.uv.sources]`, plus `"numer-identity"` in `dependencies`.
- The Docker image is built with `uv sync --frozen` from `python:3.12-slim`, which has no
  `git`. A git dependency needs `git` in the stage that runs `uv sync`.
- Production Firebase project id: `numer-60744`. It is configuration, never a code default.
- Test helpers: `sign_token` signs RS256 only; `unsigned_token` and `hs256_token` build the
  forged tokens for the negative tests.
- The NUmer repository is public, so `uv lock`, CI and the image build can fetch the
  library without a credential. Contacting github.com and the package index for that is
  allowed in this task.
- If Flutter is not installed, run only the backend part of `./scripts/verify.sh` and say so
  in the report.

- Every Flutter route goes through `require_flutter_user`
  (`backend/app/web/flutter_auth.py:63-91`): it tries the bridge first, then (only when
  `FLUTTER_NATIVE_AUTH_ENABLED`, a debug-only switch that is off in production) a native
  HS256 token. Admin routes use `require_flutter_admin` (`:95-100`), which reads the user's
  stored `role`.
- The bridge today (`backend/app/web/superapp_bridge.py`): `decode_superapp_token` (42-66)
  with optional issuer and audience; `resolve_or_create_superapp_user` (93-130) keyed on
  `users.superapp_user_id` under an advisory lock (100-106); `_role_from_claims` (80-88)
  returns `None` when the claim is absent and the caller then leaves the stored role alone
  (123-126), so a removed role never demotes; line 116 sets `is_verified=True`
  unconditionally. `SUPERAPP_*` settings are not set in production, so the bridge is inert
  there.
- Users: `users.telegram_id` is real for Telegram users and negative for Flutter-only users;
  `users.email` with `is_verified` is set by the bot's own email-code flow; a partial unique
  index allows one verified user per email (`backend/app/models/user.py:50-55`).
- Telegram surfaces derive admin from `ADMIN_IDS` and the stored `role`
  (`backend/app/services/users.py:26-29`). That stays as it is.
- The Alembic head at the time of writing is `20260721_0001`
  (`backend/alembic/versions/20260721_0001_add_poster_storage_message_id.py`). Confirm with
  `alembic heads` and use whatever single head it prints.
- The user's stored role is read directly, as `user.role`, in
  `backend/app/web/routers/flutter_events.py`, `flutter_analytics.py` and `flutter_auth.py`
  (the last one also reports the role to the client).
- `try_superapp_user(authorization, session)` receives neither the app nor the request.
- `docker/Dockerfile.production` has a single stage.
- The repo has no migration test today, and the shared `db_session` fixture uses one
  connection in one rolled-back transaction, so it cannot show a race.
- Firebase allows one account per email address, so two Firebase users with the same
  verified address should not exist; the bridge still must not let a second one in.
- The new module has no module docstring and adds no logging (this repo's rules).
- An existing integration test asserts that an email collision does not merge accounts
  (`tests/integration/test_superapp_bridge_db.py:49`). This task deliberately changes that
  policy for verified university addresses.

## Steps
1. Add the dependency as given in Context and regenerate `backend/uv.lock`. `docker/Dockerfile.production`: Split the Dockerfile into two stages with the same `WORKDIR`: a `builder` stage (from the same base image) that installs `git` with `--no-install-recommends`, removes the apt lists, and runs the existing `uv sync --frozen` commands so the virtual environment is created there; and a `runtime` stage that copies the virtual environment from the builder (`COPY --from=builder`), then copies the application files, creates the user and keeps the existing `CMD`, exactly as today. The final image must not contain `git`.
2. `backend/app/config.py`: replace the `SUPERAPP_JWT_*`, `SUPERAPP_USER_ID_CLAIM`,
   `SUPERAPP_ROLE_CLAIM` and `SUPERAPP_ADMIN_ROLE_VALUE` settings and their guards with
   `FIREBASE_AUTH_ENABLED` (default false), `FIREBASE_PROJECT_ID`, `FIREBASE_ROLES_CLAIM`
   (default `numer_roles`), `FIREBASE_ADMIN_ROLE` (default `events:admin`),
   `FIREBASE_VERIFIED_EMAIL_DOMAIN` (default `nu.edu.kz`). When enabled, a non-empty project id
   is required. Keep the rule that debug-only switches need `LOG_LEVEL=DEBUG`.
3. Add `backend/app/models/identity.py`: `UserIdentity(id, user_id -> users.id ON DELETE
   CASCADE, provider_issuer, provider_subject, created_at)` with a unique constraint on
   `(provider_issuer, provider_subject)` and an index on `user_id`. Register it where the other
   models are registered.
   Add one Alembic revision on top of the current head, named in the repo's style with a date
   after the head's: it creates the table and its indexes and nothing else (no backfill: the
   old bridge was never enabled in production, and its subjects were not Firebase uids). Leave
   `users.superapp_user_id` in place. The downgrade drops the table.
4. Rewrite `backend/app/web/superapp_bridge.py` as `backend/app/web/firebase_bridge.py` (update
   imports) keeping the public functions `try_superapp_user` (rename to `try_firebase_user`)
   and the 403 for blocked users:
   - the verifier and its key source are module-level values in `firebase_bridge.py`, created
     by `await start_firebase_bridge(settings)` and closed by `await stop_firebase_bridge()`,
     both called from the lifespan in `backend/app/web/main.py`; when `FIREBASE_AUTH_ENABLED`
     is false they are never created; tests set them directly with a `StaticKeySource`;
   - build the verifier with `require_verified_email=False` and check
     `claims.email_verified is True` in the bridge wherever the email matters;
   - verify the bearer token; `TokenInvalid` means "not a Firebase token": return `None` so the
     native path may still be tried when it is enabled; `KeysUnavailable` raises 503;
   - inside the existing advisory lock, re-keyed on `firebase:<issuer>:<uid>`:
     1. find `user_identities` by `(issuer, uid)`; if found, use that user;
     2. else, if the token's email is verified and ends with `@<domain>`: take a second
        advisory lock on `firebase-email:<lower-cased email>`, then find the user with the same
        email (lower case) and `is_verified` true. Attach a new identity row to that user only
        if exactly one exists and it has no `user_identities` row for this issuer yet;
     3. otherwise create a user (negative `telegram_id` as today, `first_name` from
        `claims.name` cut to the column length, `is_verified` true only when the email is
        verified and at the university domain, `email` stored only when no other user owns it)
        and its identity row;
   - on an existing or attached user write only `last_active_at`. Never write `first_name`,
     `last_name`, `username`, `photo_url`, `language_code`, `password_hash`, `role` or
     `telegram_id` of an existing user;
   - never set `is_verified` to true for an address outside the domain or an unverified one;
   - compute the effective role: `admin` when `FIREBASE_ADMIN_ROLE` is in `claims.roles`, else
     `user`. Do not write it to `users.role`. Attach it to the returned user object as a
     transient, unmapped attribute named `effective_role` (never `role`, which the session
     would write back on commit).
5. `backend/app/web/flutter_auth.py`: add `def is_admin(user) -> bool`, which returns `user.effective_role == 'admin'` when that attribute is set and `user.role == 'admin'` otherwise, and `def role_of(user) -> str` on the same rule. `require_flutter_admin` uses `is_admin`. In `backend/app/web/routers/flutter_events.py`, `flutter_analytics.py` and `flutter_auth.py`, replace every direct read of `user.role` with `is_admin(user)` or `role_of(user)`. Rename the imports and patches of `try_superapp_user` and `decode_superapp_token` in the code and tests that use them.
6. Rewrite `backend/SUPERAPP_BRIDGE.md` for Firebase: the token contract, user resolution order, role rule, the settings, and the cutover checklist. Name NUmer as the host there and in every other document that names the old host or the `SUPERAPP_JWT_*` settings (`README.md`, `docs/INFRASTRUCTURE.md`, `docs/PRODUCT.md`, `flutter_events/README.md`). Update `.env.example` and `docker/docker-compose.prod.yml` (both service blocks). In `deploy/setup-server.sh` require `FIREBASE_PROJECT_ID` only when `FIREBASE_AUTH_ENABLED=true`.
7. Tests:
   - `tests/backend/test_flutter_auth_tokens.py`: replace the superapp cases with Firebase
     tokens minted by `numer_identity.testing`: valid; expired; wrong audience; wrong issuer;
     HS256; unknown kid; a blocked user gets 403 and does not fall through; bridge disabled
     returns `None`.
   - `tests/backend/test_config_firebase_guard.py` (replacing only the superapp cases of the
     old guard test file; the tests of the debug switches in that file stay): enabled without
     a project id is rejected; the debug switches still need `DEBUG`.
   - `tests/integration/test_firebase_bridge_db.py` (replacing the superapp one): provisioning
     is idempotent under two concurrent first requests (this one test opens two engines with
     `NullPool`, commits, uses `asyncio.gather`, and deletes its rows afterwards); the same uid
     under another issuer is a
     different user; a verified university email attaches to the existing verified user and
     creates no new user and does not change that user's name; an unverified email, or an
     address at another domain, never attaches and is not marked verified; a second Firebase
     uid with the same university email gets its own new user and does not reach the first
     one's account; role is admin with the claim and user on the next request without it, on
     an admin route and in the profile response, and `users.role` is unchanged in the database
     both times; a Telegram user with stored `role = 'admin'` who was attached by email is not
     admin on Flutter routes without the claim; a subject longer than 128 characters is
     rejected before any write.
   - `tests/integration/test_firebase_identity_migration.py`: with Alembic's command API
     against the test database, downgrade to the previous head and upgrade to `head`; the
     `user_identities` table is absent and then present.
   - `tests/backend/test_alembic_heads.py`: the migration scripts have exactly one head.
8. Run the repo's checks exactly as CI does (`.github/workflows/ci.yml`: ruff, mypy on the listed files, bandit, pytest with the coverage floor, the integration job with Postgres 16, `scripts/check-migrations.sh`).

## Non-goals
- Do not change any Telegram, Mini App or bot code path, `ADMIN_IDS`, or the stored `role` semantics for Telegram users.
- Do not add Telegram account linking (a later task).
- Do not drop `users.superapp_user_id`.
- Do not merge two existing user rows.
- Do not change the Flutter package.
- Do not deploy and do not run a migration against any real database.

## Constraints
- Follow this repo's own `AGENTS.md`: layering (domain, application, infrastructure, api), settings only in `config.py`, no bare `except`, no docstrings.
- Production must refuse the development adapter and development tokens, as it does today.
- Do not log tokens, emails or personal data.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- The Alembic revision is additive only: no column dropped, no table rewritten, no lock-heavy statement.

## Acceptance criteria
- [ ] Every CI gate named in step 8 passes locally, with the commands and results in the report.
- [ ] `alembic heads` shows one head.
- [ ] `grep -rn "SUPERAPP_JWT\|superapp_bridge" backend/app` prints nothing.
- [ ] `grep -rn "Jas Wallet" backend` prints nothing.
- [ ] The integration test for demotion asserts the database value of `users.role` directly.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: answer whether the bot process should be running (O-4); back up the database; apply the migration and redeploy with `FIREBASE_AUTH_ENABLED=true` and the project id (`docs/numer2/USER_ACTIONS.md` D-3 in the NUmer repo).

## Deliverable
Branch `numer2/p2-06-events-firebase-bridge`, one commit, message `feat: accept firebase id tokens on flutter routes` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `alembic heads` shows more than one head.
- The tag `identity-v0.1.0` does not exist yet.
- `user.role` is read on a Flutter route outside the three router files named in step 5.
- Attaching by a verified university email turns out to be unwanted by the owner (it is decision D-22 in the NUmer repo; ask if in doubt).
- Postgres 16 is not available for the integration tests.
