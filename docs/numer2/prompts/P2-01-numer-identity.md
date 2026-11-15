# P2-01: `numer_identity` library

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-02

## Goal
Every campus module backend must accept the same bearer token: a Firebase ID token issued to
a NUmer user. Write one small Python library that verifies it, so the four backends cannot
drift apart on a security check. It lives in the NUmer repo and is consumed by git tag.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-05 and D-07
- `docs/numer2/RESEARCH.md` section 3.5
- https://firebase.google.com/docs/auth/admin/verify-id-tokens (the section on verifying with a third-party JWT library)

## Context
- Firebase ID tokens are RS256 JWTs. Public keys are X.509 certificates served as a JSON
  object `{kid: pem}` at
  `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`,
  with a `Cache-Control: max-age` that says how long to cache them.
- For project id `P`: `aud` is `P`, `iss` is `https://securetoken.google.com/P`. `sub` is
  the uid. Other claims used: `exp`, `iat`, `auth_time`, `email`, `email_verified`, `name`,
  `firebase.sign_in_provider`, `firebase.tenant`, and the custom claim `numer_roles` (a list
  of strings such as `muto:admin`).
- Module backends are async FastAPI services on Python 3.12, linted with ruff and typed with
  mypy strict. They run `uv sync --frozen` in Docker.
- The backends hold no Firebase service account, so the library never calls Firebase; it
  only fetches public keys.
- Consumers will depend on it as
  `numer-identity = { git = "https://github.com/anxchywl/NUmer", subdirectory = "backend/numer_identity", tag = "identity-v0.1.0" }`.
  The NUmer repository is public.
- The Google key URL is the one address this library hard-codes; that is allowed.
- Installing Python packages from the public index is allowed in this task.

## Steps
1. Create the package:

   ```
   backend/numer_identity/pyproject.toml
   backend/numer_identity/README.md
   backend/numer_identity/src/numer_identity/__init__.py
   backend/numer_identity/src/numer_identity/claims.py
   backend/numer_identity/src/numer_identity/errors.py
   backend/numer_identity/src/numer_identity/keys.py
   backend/numer_identity/src/numer_identity/roles.py
   backend/numer_identity/src/numer_identity/verifier.py
   backend/numer_identity/src/numer_identity/http.py
   backend/numer_identity/src/numer_identity/testing.py
   backend/numer_identity/src/numer_identity/py.typed
   backend/numer_identity/tests/
   backend/numer_identity/scripts/verify.sh
   ```
   `pyproject.toml`: name `numer-identity`, version `0.1.0`, `requires-python = ">=3.12"`,
   dependencies `pyjwt[crypto]>=2.10` and `httpx>=0.28`, a `dev` group with `pytest`,
   `pytest-asyncio`, `pytest-cov`, `ruff`, `mypy`; ruff line length 88; mypy `strict = true`;
   build backend `hatchling` with the `src` layout.
2. `errors.py`: `class TokenInvalid(Exception)` with a `code: str` attribute, one of
   `malformed`, `too-large`, `algorithm`, `unknown-key`, `signature`, `issuer`, `audience`,
   `expired`, `not-yet-valid`, `auth-time`, `subject`, `email-not-verified`, `provider`,
   `tenant`; `class KeysUnavailable(Exception)`.
   `claims.py`: a frozen, slotted dataclass `FirebaseClaims(uid, issuer, email, email_verified,
   name, sign_in_provider, auth_time, issued_at, expires_at, roles: frozenset[str], raw:
   Mapping[str, Any])`. Declare `email`, `name` and `raw` with `field(repr=False)` so printing
   the object never shows personal data.
   `roles.py`: `parse_roles(value: object) -> frozenset[str]`: a list of strings gives those
   strings; anything else, or a list containing a non-string, gives the empty set.
3. `keys.py`:
   - `class KeySource(Protocol): async def get(self, kid: str) -> RSAPublicKey | None`;
   - `StaticKeySource(keys: Mapping[str, RSAPublicKey])`;
   - `GoogleX509KeySource(client: httpx.AsyncClient | None = None, url=..., clock=time.time)`:
     one in-memory cache; lifetime from `max-age`, clamped to 300 to 86400 seconds, 3600 when
     the header is absent; a refresh runs under one `asyncio.Lock` so concurrent callers share
     it; a forced refresh for an unknown `kid` happens at most once per 60 seconds (the
     initial load and refreshes at expiry do not count toward that limit: on a cold cache an
     unknown `kid` is answered after the single initial load; on a warm cache the first
     unknown `kid` causes one extra request and a second one within 60 seconds causes none);
     when a refresh fails, keys are served for up to 86400 seconds past their lifetime, a
     warning is logged, and no new refresh is attempted for 30 seconds; with no usable key at
     all, raise `KeysUnavailable`; request timeout 3 seconds; `async def aclose()`.
4. `verifier.py`: `FirebaseVerifier(*, project_id: str, key_source: KeySource,
   leeway_seconds: int = 30, clock: Callable[[], float] = time.time, roles_claim: str =
   "numer_roles", require_verified_email: bool = True, revocation_check: Callable[[FirebaseClaims],
   Awaitable[None]] | None = None)`. An empty `project_id` raises `ValueError` at construction.
   The verifier never creates or closes a key source; the caller owns it.
   `async def verify(self, token: str) -> FirebaseClaims` checks, in this order, raising
   `TokenInvalid` with the code in brackets:
   1. the token is a `str` [malformed] of at most 4096 bytes [too-large] with three segments
      [malformed];
   2. the unverified header parses [malformed], has `alg == "RS256"` [algorithm] and a
      non-empty `kid` [malformed];
   3. the key source knows the `kid` [unknown-key];
   4. the signature verifies with `algorithms=["RS256"]` only [signature];
   5. `iss` equals `https://securetoken.google.com/<project_id>` [issuer]; `aud` equals
      `project_id` [audience];
   6. `exp` is present and not past, with leeway [expired]; `iat` is present and not in the
      future beyond leeway [not-yet-valid]; `auth_time` is present and not in the future beyond
      leeway [auth-time]; a missing or non-numeric value fails with the same code;
   7. `sub` is a non-empty `str` of at most 128 characters [subject];
   8. `firebase.tenant` is absent [tenant]; `firebase.sign_in_provider` is present and is not
      `anonymous` or `custom` [provider];
   9. when `require_verified_email`, `email_verified is True` (the boolean, not a string)
      [email-not-verified].
   Then build the claims and, if a `revocation_check` was given, await it (its exception
   propagates). Do the claim checks yourself. Use PyJWT only for the signature:
   `jwt.decode(token, key, algorithms=["RS256"], options={"verify_signature": True,
   "verify_exp": False, "verify_nbf": False, "verify_iat": False, "verify_aud": False,
   "verify_iss": False, "verify_sub": False, "verify_jti": False, "require": []})`. Map
   `jwt.InvalidSignatureError` to `signature` and every other `jwt.InvalidTokenError` to
   `malformed`. Catch nothing else.
5. `http.py`: `bearer_token(authorization: str | None) -> str` returns the token of an
   `Authorization: Bearer <token>` header (scheme compared case-insensitively) and raises
   `TokenInvalid("malformed")` otherwise. It reads nothing else.
   `testing.py`: `make_test_keypair() -> tuple[RSAPrivateKey, RSAPublicKey]` (2048 bits);
   `sign_token(claims: Mapping[str, Any], key: RSAPrivateKey, *, kid: str = "test", headers:
   Mapping[str, Any] | None = None) -> str` (RS256 only); `unsigned_token(claims, *, kid)` and
   `hs256_token(claims, secret: bytes, *, kid)`, both assembled by hand (base64url header and
   payload, and for HS256 `hmac.new(secret, signing_input, "sha256")`), because a JWT library
   refuses to forge them; `valid_claims(project_id, uid, now, **overrides) -> dict` with the
   defaults `iss`, `aud`, `sub=uid`, `iat=now`, `auth_time=now`, `exp=now+3600`,
   `email="student@nu.edu.kz"`, `email_verified=True`, `name="Test User"`,
   `firebase={"identities": {}, "sign_in_provider": "password"}` and no roles claim, where an
   override replaces a top-level key and an override of `None` removes it; and a re-export of
   `StaticKeySource`.
   `__init__.py` exports the public names and `__version__`.
6. Tests in `backend/numer_identity/tests/`, no network, a frozen clock:

   | # | Token or situation | Expected |
   |---|---|---|
   | 1 | valid, known kid, `email_verified: true` | claims with `uid == sub` |
   | 2 | `alg: none`, empty signature | `algorithm` |
   | 3 | `alg: HS256` signed with the public key PEM as the secret | `algorithm` |
   | 4 | RS256 signed by another key, same kid | `signature` |
   | 5 | unknown kid | one refresh, then `unknown-key`; a second call within 60 s does not refresh |
   | 6 | `aud` of another project | `audience` |
   | 7 | `iss` of another project | `issuer` |
   | 8 | `aud` missing | `audience` |
   | 9 | `exp` 31 s ago | `expired`; 20 s ago is accepted |
   | 10 | `iat` 120 s ahead | `not-yet-valid` |
   | 11 | `auth_time` missing, or 120 s ahead | `auth-time` |
   | 12 | `sub` empty, or 129 characters | `subject` |
   | 13 | `email_verified` false, or the string `"true"` | `email-not-verified` |
   | 14 | provider `anonymous`; a `tenant` present | `provider`; `tenant` |
   | 15 | a `revocation_check` that raises | its exception propagates |
   | 16 | `require_verified_email=False` with an unverified email | accepted |
   | 17 | `numer_roles: ["muto:admin", 7]`, then a string, then absent | empty set each time; `["muto:admin"]` gives that role |
   | 18 | key endpoint returns 500 with a warm cache; with a cold cache | accepted; `KeysUnavailable` |
   | 19 | a 5000-byte token; two segments | `too-large`; `malformed` |
   | 20 | 50 concurrent `verify` calls on a cold cache | exactly one HTTP request |

   Also: `max-age` parsing and clamping; stale keys served after a failed refresh and refused
   after 86400 seconds; 10 sequential `verify` calls after a failed refresh make one HTTP
   request; a non-string token, an unparsable header, a missing `exp`, a missing `iat`, and a
   missing `firebase.sign_in_provider`, each with the code given in step 4; `bearer_token`
   cases; `repr(claims)` contains neither the email nor the name. Use `httpx.MockTransport`
   for the key endpoint. Rows 2 and 3 use `unsigned_token` and `hs256_token`. Set
   `asyncio_mode = "auto"` under `[tool.pytest.ini_options]`.
7. `scripts/verify.sh` in the package: `uv sync --group dev`, `uv run ruff format --check .`, `uv run ruff check .`, `uv run mypy src`, `uv run pytest --cov=numer_identity --cov-fail-under=95`. Add `.github/workflows/identity.yml`: on pull requests and pushes to `main` touching `backend/numer_identity/**`, Python 3.12, run that script. Pin actions by commit SHA, copying the SHAs the existing workflow `.github/workflows/ci.yml` already uses for checkout; for an action that workflow does not use, look up the SHA of its latest release tag and note the tag in a trailing comment. Commit `backend/numer_identity/uv.lock`; add `backend/numer_identity/dist/` and `.venv/` to `.gitignore`.
8. `README.md` in the package: what it checks, the install line for consumers, a 15-line FastAPI usage example (create one verifier in the lifespan, close its key source on shutdown, map `TokenInvalid` to 401 and `KeysUnavailable` to 503), the test helpers, and the release rule (a tag `identity-v<version>` matching `pyproject.toml`).
9. Add `backend/numer_identity/` to the repository layout in `AGENTS.md` (the repo is no longer a single Flutter package) and the new workflow to the CI paragraph of `docs/INFRASTRUCTURE.md`.
10. Run `backend/numer_identity/scripts/verify.sh` and the repo's `./scripts/verify.sh`.

## Non-goals
- Do not use `firebase_admin` or any Google SDK.
- Do not read environment variables in the library; configuration is passed in.
- Do not add account-event helpers (P2-07).
- Do not accept any algorithm other than RS256, and do not make the issuer or audience optional.
- Do not persist keys to disk.

## Constraints
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- Python: no bare `except`, no docstrings, type hints everywhere, comments follow the repo comment rule.
- Never log a token or an email address.

## Acceptance criteria
- [ ] `backend/numer_identity/scripts/verify.sh` exits 0 with coverage at or above 95%.
- [ ] Each of the 20 rows has a test whose name contains its number (`test_v01_...` to `test_v20_...`).
- [ ] `grep -rn "os.environ\|firebase_admin" backend/numer_identity/src` prints nothing.
- [ ] `cd backend/numer_identity && uv build` produces a wheel.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Review, merge, then push the tag `identity-v0.1.0` (`docs/numer2/USER_ACTIONS.md` D-1). The four backend tasks need the tag.

## Deliverable
Branch `numer2/p2-01-numer-identity`, one commit, message `feat: add numer_identity token verification library` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `uv` is not installed and cannot be installed in your environment.
- PyJWT cannot be made to skip its own claim validation while still verifying the signature.
- The documented key endpoint or claim names differ from Context.
