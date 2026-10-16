# P1-10: Docs after auth

**Recommended model:** sonnet   **Effort:** low
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-08, P1-09

## Goal
Sign-up, password reset and account deletion work differently after this phase. Bring the
docs in line so nobody builds on the old link-based flow or the old deletion order.

## Read first
- `AGENTS.md`, `docs/PRODUCT.md`, `docs/INFRASTRUCTURE.md`, `docs/PRIVACY_POLICY.md`
- `functions/src/auth/`, `functions/src/mail/`, `functions/src/account/` (to describe what exists)
- `firestore/firestore.rules`

## Context
Document ownership: `docs/PRODUCT.md` says what the user experiences;
`docs/INFRASTRUCTURE.md` says how it runs (functions, secrets, parameters, collections,
rules stages, deploy order); `AGENTS.md` holds rules for contributors;
`docs/PRIVACY_POLICY.md` is the published policy and changes only as a draft for the owner.

## Steps
1. `docs/PRODUCT.md`: add `## Accounts and verification`: sign-up with email and password, a 6-digit code by email, reset by code, deleting an account and what it removes. Five to ten lines, no implementation detail.
2. `docs/INFRASTRUCTURE.md`: add or update
   - the functions table (all exports, one line each);
   - `## Auth by email code`: the five callables, the limits, the collections and their TTL
     fields, the secret and parameters;
   - `## Email delivery`: the provider interface, parameters, the test script, the DNS records
     needed (as record types, without the owner's domain);
   - `## Account deletion`: the order of steps and the `accountEvents` queue;
   - `## Rules stages`: what stage 1 and stage 2 contain and the condition for deploying
     stage 2;
   - the list of runtime switches: `AGG_INCREMENTAL`,
     `AGG_SHADOW_PERCENT`, `AUTH_ENFORCE_APPCHECK`, `APPCHECK_ENFORCED`,
     `DELETE_REQUIRES_RECENT_AUTH`, `MAIL_PROVIDER`, `MAIL_FROM`.
3. `AGENTS.md`: in the security rules of thumb add: identity and email come from the token, never from client data; codes and tickets are never logged or stored in plain text; a new server-only collection gets a deny rule and a rules test.
4. `docs/PRIVACY_POLICY.md`: write the changes as a draft section at the end titled `Draft changes for review` listing: the email delivery provider, push tokens, crash reports if enabled, and how deletion works. Do not edit the published text above it.
5. Run `./scripts/verify.sh`.

## Non-goals
- Do not include a domain, an address, a key or a project number that is not already in the repo.
- Do not change code.
- Do not describe modules or the new shell.

## Constraints
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -n "sendEmailVerification\|reset link" docs AGENTS.md README.md -r` prints nothing that describes current behaviour.
- [ ] Every export of `functions/src/index.ts` appears in the functions table (compare the two lists in the report).
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approve the privacy policy draft and publish it (`docs/numer2/USER_ACTIONS.md` C-9).

## Deliverable
Branch `numer2/p1-10-docs-after-auth`, one commit, message `docs: describe code based auth, email and deletion` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A fact needed for the docs lives only in a console (for example which TTL policies are enabled).
