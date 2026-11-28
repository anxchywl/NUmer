# P3-13: Docs after shell

**Recommended model:** sonnet   **Effort:** low
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-17

## Goal
Make the repository's docs describe the app as phase 3 left it: the five-tab shell, Study,
Home with news, Settings behind the avatar, `numer_ui`, the module registry. The design
language becomes a permanent doc at `docs/DESIGN.md`.

## Read first
- `AGENTS.md`, `README.md`, `docs/PRODUCT.md`, `docs/INFRASTRUCTURE.md`
- `docs/DESIGN.md`, `docs/numer2/DECISIONS.md` D-20, D-21, D-24, D-33, D-34
- The tree as it is: `find lib packages -maxdepth 3 -type d | sort`
- `lib/app/modules/`, `lib/core/modules/`, `lib/app/shell/shell_tabs.dart`,
  `packages/numer_ui/MIGRATION.md`

## Context
- Each doc owns its subject once (`AGENTS.md` "Docs"). `PRODUCT.md` says what the app does;
  `AGENTS.md` how code is organised and the rules; `README.md` the short tour and the tree;
  `INFRASTRUCTURE.md` how it runs (P3-08 already added the feed functions).
- Earlier phase 3 tasks updated docs piecemeal; this task makes them consistent and complete.

## Steps
1. `git mv` the design doc from `docs/numer2/` to `docs/DESIGN.md`. Replace every link to the old path:
   `grep -rln "numer2/DESIGN\.md" AGENTS.md README.md docs scripts packages` and, in each
   file, `numer2/DESIGN\.md` becomes `DESIGN.md` with the path made relative to that file
   (from `docs/numer2/` it is `../DESIGN.md`; from `docs/numer2/prompts/` it is
   `../../DESIGN.md`; from the root `docs/DESIGN.md`). Check each replaced link resolves.
2. `docs/PRODUCT.md`: the navigation (Home, Habits, Study, Groups, and Campus when a campus
   module is on; Settings from the avatar), what Home shows (streak, running session, today,
   upcoming, news), what Study holds (courses with the timer sheet, Statistics, History,
   Course analysis coming soon), News and announcements, and that timer and alarm screens
   are gone. Remove sentences that describe the old tabs.
3. `AGENTS.md`:
   - the `packages/numer_ui/` entry: tokens, components, theme, `compat.dart` for modules;
     UI follows `docs/DESIGN.md`;
   - the feature list: add `study`, `campus`, `news`; `home` is the today screen;
   - `core/` and `app/` entries: `core/identity/`, `core/modules/`, `core/upcoming/`,
     `app/modules/`;
   - a section "Adding a module" after "Creating a new feature": one `ModuleDescriptor` in
     `lib/app/modules/module_registry.dart`, a host folder `lib/features/<module>/`, a flag in
     `config/app`, lazy builder returning `NumerModuleScaffold`, no work at startup, tokens
     through `ModuleSession`. Where "Creating a new feature" step 4 says tabs are added in
     `shell_tabs.dart`, say that modules never add tabs.
4. `README.md`: the tree matches `find lib -maxdepth 2 -type d` and lists `packages/numer_ui`.
5. Run `./scripts/verify.sh` (docs only; it must still pass).

## Non-goals
- No code change. No rewrite of `DECISIONS.md`, `RESEARCH.md` or old prompts beyond the link
  fix. Phase 6 rewrites the docs for the finished superapp.

## Constraints
- English; each doc owns its subject once; no server address, secret or personal data in a doc.
- Do not deploy, do not push.
- Size (`AGENTS.md` "Size", D-33) does not apply to Markdown; leave the size baseline alone.

## Acceptance criteria
- [ ] `grep -rn "numer2/DESIGN\.md" .  --include=*.md` prints nothing; every rewritten link resolves.
- [ ] `docs/PRODUCT.md` names the five tabs and no removed screen.
- [ ] `AGENTS.md` has the "Adding a module" section and lists `study`, `campus`, `news`.
- [ ] `./scripts/verify.sh` exits 0.

## User actions
- None.

## Deliverable
Branch `numer2/p3-13-docs-after-shell`, one commit, message `docs: describe the phase 3 shell` (subject line only). Do not push.
Report: files changed and the list of rewritten links.

## Stop and ask if
- A doc contradicts the code and you cannot tell which is right.
