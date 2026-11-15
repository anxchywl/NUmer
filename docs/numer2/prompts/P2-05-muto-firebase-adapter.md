# P2-05: Muto backend: Firebase adapter

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** Muto (`anxchywl/Muto`) @ the default branch   **Depends on:** P2-01 (tag `identity-v0.1.0` pushed)

## Goal
Muto's production resolver rejects every token. Add an adapter that verifies NUmer's
Firebase ID tokens, and fix the user upsert so that a token without a phone or Telegram
name no longer erases what the user saved.

## Read first
- `AGENTS.md` (this repo's rules are binding)
- `docs/ARCHITECTURE.md` (identity and roles), `docs/INFRASTRUCTURE.md`
- `backend/app/config.py`
- `backend/app/infrastructure/auth/resolvers.py`
- `backend/app/domain/auth.py`
- `backend/app/application/identity.py` (all of it)
- `backend/app/dependencies.py`, `backend/app/main.py`
- `backend/app/infrastructure/db/models/user.py`
- `backend/tests/unit/test_auth.py`, `backend/tests/integration/test_listings_api.py`
- `deploy/preflight.sh`, `deploy/production.env.example`, `docker/docker-compose.production.yml`, `backend/Dockerfile`

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

- Enum `AuthAdapter` (`backend/app/config.py:19-21`), setting `AUTH_ADAPTER` (`:37`, default
  `host`), factory `create_principal_resolver` (`resolvers.py:50-53`), which returns a
  resolver that rejects everything unless the adapter is `development`.
- `ExternalIdentity` (`backend/app/domain/auth.py:14-24`) has the fields `external_issuer`,
  `external_subject`, `account_status` (required), `is_verified`, `display_name`, `email`,
  `phone`, `telegram_username`, `is_admin`. Read the class for the exact names and order.
- `resolve_principal` (`backend/app/application/identity.py:11-66`) provisions a user by
  `(issuer, subject)` under an advisory lock, and on every request overwrites
  `display_name`, `email`, `telegram_username`, `phone`, `is_verified` and `account_status`
  from the identity (`:48-53`). A Firebase token has no phone and no Telegram name, so each
  request would set them to null, and because the Firebase resolver always reports an
  active account, a user suspended in the database would be reactivated by their next
  request.
- `create_principal_resolver(settings)` is synchronous with one argument; the lifespan in
  `backend/app/main.py` sets the resolver; `backend/Dockerfile` has a single stage.
- Muto has no backend layer-boundary test. `./scripts/verify.sh` runs the unit tests only;
  the 80% coverage floor is enforced by the CI command
  `pytest tests --cov=app --cov-fail-under=80`, which needs Postgres.
- Admin status is taken from the identity on every request and never stored (`:65`).
- Verified students are those with a verified `@nu.edu.kz` address; other verified addresses
  may use the app but are not marked verified.
- Muto's backend has no JWT library today; `numer_identity` brings it.

## Steps
1. Add the dependency as given in Context and regenerate `backend/uv.lock`.
2. `backend/app/config.py`: add `firebase` to `AuthAdapter`; settings `FIREBASE_PROJECT_ID`, `FIREBASE_ROLES_CLAIM` (default `numer_roles`), `FIREBASE_ADMIN_ROLE` (default `muto:admin`), `FIREBASE_VERIFIED_EMAIL_DOMAIN` (default `nu.edu.kz`); require the project id when the adapter is `firebase`. The default adapter stays `host`.
3. `backend/app/infrastructure/auth/resolvers.py`: add `FirebasePrincipalResolver` returning
   `ExternalIdentity(external_issuer=claims.issuer, external_subject=claims.uid,
   account_status=<the active status>, is_verified=<the email is not None and ends with "@" +
   domain, compared in lower case>, display_name=claims.name, email=claims.email, phone=None,
   telegram_username=None, is_admin=admin_role in claims.roles)`. The domain setting is
   lower-cased and stripped of a leading `@` in `config.py`. Map `TokenInvalid` to the
   unauthorized error and `KeysUnavailable` to a 503 (use the module's existing domain error
   for an unavailable service if there is one; otherwise add one and its mapping).
   Add `create_firebase_resolver(settings, key_source: KeySource | None = None)` returning the
   resolver and a function that closes the key source. Leave
   `create_principal_resolver(settings)` unchanged for the other adapters; for `firebase` it
   raises `ValueError`.
4. `backend/app/application/identity.py`: change the update at lines 48-53 so that
   `display_name`, `telegram_username` and `phone` are written only when the identity supplies
   a non-null value; `email` and `is_verified` are always written from the identity;
   `account_status` is written only when the user is created, never on an existing user. A
   new user is created with whatever the identity has. Keep the advisory lock and the
   suspended check unchanged.
5. `backend/app/main.py`: give `create_app` an optional parameter `firebase_key_source` (used by tests). In the lifespan, for the `firebase` adapter, call `create_firebase_resolver`, store the resolver where the lifespan stores it today, and await the close function before the database is closed.
6. `backend/Dockerfile`: Split the Dockerfile into two stages with the same `WORKDIR`: a `builder` stage (from the same base image) that installs `git` with `--no-install-recommends`, removes the apt lists, and runs the existing `uv sync --frozen` commands so the virtual environment is created there; and a `runtime` stage that copies the virtual environment from the builder (`COPY --from=builder`), then copies the application files, creates the user and keeps the existing `CMD`, exactly as today. The final image must not contain `git`. Env example and compose: add the new settings. `deploy/preflight.sh`: when `AUTH_ADAPTER=firebase` require a non-empty `FIREBASE_PROJECT_ID`; in production require `AUTH_ADAPTER=firebase`; keep every existing check.
7. Tests:
   - `backend/tests/unit/test_firebase_auth.py`: valid; wrong audience; wrong issuer; expired;
     HS256; unknown kid; unverified email; keys unavailable gives 503; `muto:admin` gives
     `is_admin`; an address at another domain gives `is_verified` false.
   - `backend/tests/integration/test_firebase_identity.py` (Postgres, following the pattern of
     `test_listings_api.py`: `asyncio.run`, a truncating fixture, and the app built with
     `create_app(settings, firebase_key_source=StaticKeySource(...))`): the first request
     creates one `users` row and one `user_identities` row; a second request reuses them; two
     concurrent first requests (two sessions from separate engines, `asyncio.gather`) create
     one user; the same subject under another issuer creates a second user; a user suspended
     with `UPDATE users SET account_status = 'suspended'` gets 403 and the column is still
     `suspended` afterwards; `is_admin` is never written to the database; a user whose row has a phone and a Telegram name keeps both after
     a request whose token has neither; a token without a name does not erase the stored name.
8. Update `docs/ARCHITECTURE.md` (identity section), `docs/INFRASTRUCTURE.md` (including how to run the integration tests), `deploy/production.env.example` and the development compose default, for the adapter and the upsert rule. Run `./scripts/verify.sh` and the integration tests the way `docs/INFRASTRUCTURE.md` describes.

## Non-goals
- Do not add block-user or moderation (a later task).
- Do not change listings, images, reports or the Flutter packages.
- Do not store roles.
- Do not fix `deploy/restore.sh` or `deploy/Caddyfile` here (P2-09).
- Do not deploy.

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

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] With Postgres available, the CI coverage command (`pytest tests --cov=app --cov-fail-under=80`, with the database variable CI uses) exits 0, and the integration test file passes, including the two no-erase cases and the suspended case.
- [ ] `docker build -t muto-backend:p205 -f backend/Dockerfile .` succeeds and `docker run --rm --entrypoint sh muto-backend:p205 -c 'command -v git'` exits 1.
- [ ] `grep -rln numer_identity backend/app` lists only files under `backend/app/infrastructure/auth/` and `backend/app/main.py`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: redeploy Muto with the Firebase settings (`docs/numer2/USER_ACTIONS.md` D-3 in the NUmer repo).

## Deliverable
Branch `numer2/p2-05-muto-firebase-adapter`, one commit, message `feat: verify firebase id tokens and keep saved contact fields` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The tag `identity-v0.1.0` does not exist yet.
- The app lets a user edit `display_name` in Muto itself (then the token must not overwrite it either; report and wait).
- Postgres is not available for the integration tests.
