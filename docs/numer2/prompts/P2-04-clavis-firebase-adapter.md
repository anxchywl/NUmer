# P2-04: Clavis backend: Firebase adapter

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** Clavis (`anxchywl/Clavis`) @ `main`   **Depends on:** P2-01 (tag `identity-v0.1.0` pushed)

## Goal
Clavis's booking backend verifies a self-minted HS256 token today. Add an adapter that
verifies NUmer's Firebase ID tokens, so bookings made from NUmer belong to the signed-in
Firebase user.

## Read first
- `AGENTS.md` (this repo's rules are binding)
- `docs/ARCHITECTURE.md`, `docs/INFRASTRUCTURE.md`, `docs/API.md`
- `backend/app/config.py`
- `backend/app/infrastructure/auth/resolvers.py`
- `backend/app/domain/auth.py`, `backend/app/dependencies.py`, `backend/app/main.py`
- `backend/app/infrastructure/store/sqlite.py` lines 13-45
- `backend/app/commands/issue_token.py`
- `backend/tests/unit/test_auth.py`, `test_config.py`, `test_bookings_api.py`, `test_operator_api.py`
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

- The auth code has the same shape as Gradus: enum `AuthAdapter`
  (`backend/app/config.py:25-27`), setting `AUTH_ADAPTER` (`:36`), factory
  `create_principal_resolver` (`backend/app/infrastructure/auth/resolvers.py:125-130`),
  lifespan wiring (`backend/app/main.py:36-38`).
- Bookings, booking requests and weekly limits are keyed on a `subject` string with no
  issuer (`sqlite.py:18-41`). With one trusted issuer per deployment that is acceptable; the
  subject becomes the Firebase uid. No schema change.
- Operator routes (`backend/app/api/operator.py`) require `is_operator`.
- `issue_token` mints HS256 tokens for the `host` adapter. It stays until `host` is removed.
- Whether production already holds bookings under old student ids is unknown. The owner
  needs a read-only way to find out.
- Clavis stays on SQLite (a recorded decision). Do not add a database URL.
- As in Gradus: `create_principal_resolver(settings)` is synchronous with one argument; the
  lifespan sets `application.state.principal_resolver`; `backend/Dockerfile` has a single
  stage; `deploy/preflight.sh` reads `ENV_FILE` and fails on a dirty tree. Check whether a
  domain error for 503 exists in `backend/app/domain/errors.py`; if it does, use it.

## Steps
1. Add the dependency as given in Context and regenerate `backend/uv.lock`.
2. `backend/app/config.py`: add `firebase` to `AuthAdapter`; settings `FIREBASE_PROJECT_ID`, `FIREBASE_ROLES_CLAIM` (default `numer_roles`), `FIREBASE_OPERATOR_ROLE` (default `clavis:operator`); require the project id when the adapter is `firebase`. The default adapter stays `host`.
3. `backend/app/infrastructure/auth/resolvers.py`: add `FirebasePrincipalResolver` returning `ExternalIdentity(external_issuer=claims.issuer, external_subject=claims.uid, display_name=claims.name, is_operator=operator_role in claims.roles)` with the active account status; map `TokenInvalid` to unauthorized and `KeysUnavailable` to a 503 domain error. Add `create_firebase_resolver(settings, key_source: KeySource | None = None)` returning the resolver and a function that closes the key source. Leave `create_principal_resolver(settings)` unchanged for `host` and `development`; for `firebase` it raises `ValueError`.
4. `backend/app/main.py`: give `create_app` an optional parameter `firebase_key_source` (used by tests). In the lifespan, for the `firebase` adapter, call `create_firebase_resolver`, store the resolver in `application.state.principal_resolver`, and await the close function after `yield`.
5. `backend/app/commands/list_subjects.py` (run as `python -m app.commands.list_subjects`):
   opens the database read-only and prints three numbers: distinct subjects in `bookings`, how
   many of them are 28 characters of `[A-Za-z0-9]` (the usual shape of a Firebase uid), and
   how many are not. It prints no subject value.
6. `backend/Dockerfile`: Split the Dockerfile into two stages with the same `WORKDIR`: a `builder` stage (from the same base image) that installs `git` with `--no-install-recommends`, removes the apt lists, and runs the existing `uv sync --frozen` commands so the virtual environment is created there; and a `runtime` stage that copies the virtual environment from the builder (`COPY --from=builder`), then copies the application files, creates the user and keeps the existing `CMD`, exactly as today. The final image must not contain `git`. Env example and compose: add the three `FIREBASE_*` variables. `deploy/preflight.sh`: in production accept `firebase` with a non-empty project id, or `host` with today's checks.
7. Tests:
   - `backend/tests/unit/test_firebase_auth.py`: the cases valid, wrong audience, wrong issuer,
     expired, HS256, unknown kid, unverified email, keys unavailable (503), operator role
     present and absent.
   - `test_bookings_api.py`: with a Firebase token (app built with
     `create_app(settings, firebase_key_source=StaticKeySource(...))`), a booking is stored
     under the uid, and a second user cannot release it.
   - `test_operator_api.py`: a token with `clavis:operator` reaches an operator route; one
     without gets 403.
   - `test_config.py`: `firebase` without a project id is rejected.
   - a test for `list_subjects` on a temporary database.
   The existing `issue_token` tests stay and still pass with the `host` adapter.
8. Update `docs/INFRASTRUCTURE.md`, `docs/API.md` and `docs/ARCHITECTURE.md`: the `firebase` adapter, the single-issuer assumption behind the bare `subject`, and how to run `list_subjects`. Run `./scripts/verify.sh`.

## Non-goals
- Do not change the SQLite schema or move to Postgres.
- Do not remove `issue_token` or the `host` adapter.
- Do not change booking rules, the clock handling or the Flutter packages.
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
- [ ] `./scripts/verify.sh` exits 0 (backend coverage floor 90).
- [ ] `docker build -t clavis-backend:p204 -f backend/Dockerfile .` succeeds and `docker run --rm --entrypoint sh clavis-backend:p204 -c 'command -v git'` exits 1.
- [ ] `python -m app.commands.list_subjects` prints three integers and no subject on a test database.
- [ ] `grep -rln numer_identity backend/app` lists only files under `backend/app/infrastructure/auth/` and `backend/app/main.py`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: run `list_subjects` in the production container and report the numbers (O-5); then redeploy with the Firebase settings (`docs/numer2/USER_ACTIONS.md` D-3 in the NUmer repo).

## Deliverable
Branch `numer2/p2-04-clavis-firebase-adapter`, one commit, message `feat: verify firebase id tokens` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The tag `identity-v0.1.0` does not exist yet.
- The SQLite store cannot be opened read-only by the command without changing the store class.
