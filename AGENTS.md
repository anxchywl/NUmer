# AGENTS.md

Welcome, AI Agent! This file tells you how to work in the **NUmer** codebase safely — how the
code is organized and the rules you must not break. Read it first, then the doc that matches
your task:

- **What the app does** → [docs/PRODUCT.md](file:///Users/anx/numer_app/docs/PRODUCT.md)
- **How it runs & ships** (offline-first data flow, Firebase, Cloud Functions, build/deploy)
  → [docs/INFRASTRUCTURE.md](file:///Users/anx/numer_app/docs/INFRASTRUCTURE.md)

---

## Repository Layout (read this first)

NUmer is a Flutter app plus a small Python library for the module backends. The Dart code
under `lib/` is organized **by feature, not by type**, so every file has one obvious home
and a domain can be understood by opening one folder.

```
lib/
  main.dart              # entrypoint only — calls startApp()
  app/                   # app shell specific to NUmer (not reusable)
  core/                  # cross-cutting INFRA (side effects, singletons)
  shared/                # PURE reusable UI — no business logic, no feature imports
  features/              # the product — one self-contained folder per domain
  l10n/                  # generated localization — do not hand-edit
packages/
  numer_ui/              # design tokens and components shared with modules
backend/
  numer_identity/        # python Firebase ID-token verifier for module backends
```

- **`app/`** — composition root: `bootstrap.dart` (startup and providers), `numer_app.dart`
  (root widget and `MaterialApp`), `app_theme.dart`, `auth_gate.dart`,
  `update_required_screen.dart`, `routes.dart`, `shell/` (tab shell and navigation bars) and
  `app_state.dart` (the global `ChangeNotifier`).
- **`core/`** — headless infrastructure used by features: `config/` (remote flags and the
  minimum build), `data/` (Hive local DB, `storage`, `sync_service`, `user_storage`),
  `notifications/`, `observability/` (crash reporting), `firebase_options.dart`,
  `startup_metrics.dart`. Core never imports a feature.
- **`shared/`** — domain-agnostic UI in `widgets/` (toast, loading screen, color
  picker). If it references a domain model or does I/O, it does **not** belong here.
- **`packages/numer_ui/`** — the design language of
  [docs/numer2/DESIGN.md](file:///Users/anx/numer_app/docs/numer2/DESIGN.md) as code: tokens
  and components, depending only on `flutter`. New and changed UI takes them from
  `package:numer_ui/numer_ui.dart`.
- **`backend/numer_identity/`** — the one place module backends verify a NUmer bearer
  token; consumed by git tag `identity-v<version>`, with its own `scripts/verify.sh`
  (see its README).

Each feature under `lib/features/<name>/` owns everything for its domain and exposes a
single barrel `<name>.dart`:

```
features/<name>/
  <name>.dart      # public surface — import a feature ONLY via this barrel
  models/          # domain types
  data/            # services / repositories
  screens/         # full-page routes
  widgets/         # widgets used only inside this feature
```

**Grow-as-needed:** a feature starts flat; add a subfolder only once a category reaches ~3
files. Small features (`ai_analysis`, `courses`) stay flat.

Current features: `auth`, `account`, `habits`, `groups`, `courses`,
`sessions` (timer/alarms), `stats`, `history`, `ai_analysis` (paused, coming-soon screen
only), `home`, and
`connections` (built but intentionally hidden — see the marker in `lib/app/shell/shell_tabs.dart`).

**Dependency rule (one direction):** `features → core → shared`. `core`/`shared` must never
import a feature; a feature imports another feature only via its barrel
(`features/<other>/<other>.dart`), never its internal files.

**Conventions:** absolute `package:numer_app/...` imports across features, relative within a
feature; filenames are greppable by suffix (`*_screen.dart`, `*_service.dart`, `*_sheet.dart`);
tests mirror the tree under `test/features/<name>/`, with app-level smoke tests in `test/smoke/`.

### Comment style

Write a comment only where the *why* is not obvious from the code. Never explain what the
code does; names and structure do that.

```dart
// good: host may not register our delegate, so the feature scopes its own
// bad:  This method loads the listings from the repository.
```

- one line, concise, all lowercase, no trailing punctuation
- keep real code identifiers in their true case (`pomodoroStart`, `LocalSession`)
- `//` only: no docstrings (`///`) and no multi-line comment blocks
- no commented-out code and no stream-of-consciousness notes

### Key locations

- **Global App State**: [lib/app/app_state.dart](file:///Users/anx/numer_app/lib/app/app_state.dart) — central `ChangeNotifier` (sessions, settings, timers, alarms).
- **Local Storage Interface**: [lib/core/data/storage.dart](file:///Users/anx/numer_app/lib/core/data/storage.dart) — wraps Hive boxes; read/write local models here.
- **Synchronization Engine**: [lib/core/data/sync_service.dart](file:///Users/anx/numer_app/lib/core/data/sync_service.dart) — connectivity, full syncs, local-remote resolution.
- **A feature** (e.g. habits): everything lives under [lib/features/habits/](file:///Users/anx/numer_app/lib/features/habits/) — models, `data/habit_service.dart`, screens, widgets.
- **Native session Live Activity**: `ios/SessionLiveActivityExtension` + `ios/Shared` — owned by the `sessions` feature (see its README).
- **Backend** (Cloud Functions, Firestore rules/data model): see [docs/INFRASTRUCTURE.md](file:///Users/anx/numer_app/docs/INFRASTRUCTURE.md).

### Creating a new feature

1. `mkdir lib/features/<name>` and add an empty `lib/features/<name>/<name>.dart` barrel.
2. Add files flat; add subfolders only at ~3 files of a kind.
3. `export` the public surface from the barrel.
4. Wire it up in `app/`: providers in `bootstrap.dart`, routes in `routes.dart` and
   `numer_app.dart`, tabs in `shell/shell_tabs.dart`.
5. Add tests under `test/features/<name>/`.
6. Reuse from `shared/` (UI) and `core/` (infra); never copy another feature's file.

---

## Core Development Rules for Agents

### 0. Scope changes to one feature folder
Most tasks map to a single `lib/features/<name>/` folder — work there and stay there.
Read that feature's `<name>.dart` barrel first to learn its surface. Put new shared UI in
`shared/`, new infra in `core/`; never place business logic in `shared`/`core`, and never
reach into another feature's non-barrel files.

### 1. Maintain the Offline-First Contract
**Never write directly to Firestore from UI screens.**
- Always mutate local Hive objects via [storage.dart](file:///Users/anx/numer_app/lib/core/data/storage.dart).
- Ensure models are written with `dirty = true` and `updatedAt = DateTime.now()`.
- Let `SyncService` propagate changes asynchronously. Writing directly to Firestore disrupts the synchronization sequence and will cause sync loops or overwrite conflicts.

### 2. State Hydration Checklist
If you modify `AppState`, ensure your changes:
- Are loaded during the `_performLoad` routine in `AppState.load()` (e.g. read from local Storage).
- Call `notifyListeners()` when mutated.
- Save their updated state persistently to Hive or `SharedPreferences`.

### 3. Modifying Data Models
When adding fields to models (e.g. `Course`, `Habit`, `Person`):
- Update their `toJson()` and `fromJson()` serialize methods.
- Ensure compatibilities with existing schemas. Hive database schema modifications might require incremental type adapter IDs or migration logic.

### 4. Firestore Security Rules Compliance
Before making changes that involve writing or reading collections:
- Check if your collections are protected. In `firestore/firestore.rules`, user data (like `habits`, `connections`, `courses`, `sessions`) is owner-read-write. The exceptions: `/groups` follow group roles; any signed-in user may get (not list) a `/users` profile; `sessions`, `courses`, `aggregates` and `/publicProfiles` are readable by co-members, decided by the server-written `/groupIndex`. Server-written collections (`groupIndex`, `publicProfiles`, `mailQueue`, `roleAudit` and the rest listed in [docs/INFRASTRUCTURE.md](file:///Users/anx/numer_app/docs/INFRASTRUCTURE.md)) are denied to client writes; a new one needs its own deny block.
- If you add a subcollection under `/users/{userId}/`, you **must** update `firestore.rules` to allow owner access.

### 5. Multi-lingual Support
NUmer is fully localized into English (`en`), Russian (`ru`), and Kazakh (`kk`).
- When writing UI components, retrieve strings from `AppLocalizations.of(context)`.
- Localization keys are declared in translation files.

---

## Verify before reporting

Run `./scripts/verify.sh` and report its real output. A task is not done until it passes.
The script does not run device builds, emulator tests or deploys.

## Code conventions

- **Comments**: see [Comment style](#comment-style)
- **Language**: English for code, comments, docs and commits
- **Commits**: conventional prefix (`feat`, `fix`, `refactor`, `docs`, `chore`, `test`), lowercase, imperative, no period, subject line only, no trailers
- **Size**: a source file stays under 400 lines and a function under about 60; when a file grows past that, split it by responsibility (one widget, section or service per file). `scripts/check_file_size.sh` enforces it: files in `scripts/file_size_baseline.txt` predate the rule and may only shrink, and a file that shrinks lowers its entry in the same commit
- **Shape**: follow the file's existing patterns; early returns; small single-purpose functions; short descriptive names; `lower_snake_case.dart` with `*_screen.dart`, `*_service.dart`, `*_sheet.dart` suffixes
- **Leftovers**: no debug prints, commented-out code, temporary variables or emoji
- **Errors**: catch the specific failure you handle; never catch broadly or swallow
- **Scope**: no unrequested features, abstractions, dependencies or error handling; edit existing files where possible
- **Tests**: `flutter_test` with hand-written fakes, no mocking package; tests mirror the source tree; functions and rules are tested against the emulator
- **Coverage**: NUmer: the floor is the baseline measured in P0-02, rounded down, and may only rise. Module repos keep their own floors
- **Docs**: each doc owns its subject once; a change that makes `AGENTS.md`, `README.md` or `docs/*` wrong fixes them in the same commit

## Agent Gotchas

- **Hive adapters are hand-written** — this project does **not** run `build_runner`
  (`hive_generator`/`build_runner` are intentionally not dependencies). If you add a Hive
  type, write its `TypeAdapter` by hand (see the `Local*Adapter` classes in
  `core/data/entities.dart`) with a unique `typeId`; changing an existing `typeId` or field
  order breaks persisted data.
- **Setup, emulator, secrets, deploy** are all in
  [docs/INFRASTRUCTURE.md](file:///Users/anx/numer_app/docs/INFRASTRUCTURE.md) — don't
  reinvent commands here.
