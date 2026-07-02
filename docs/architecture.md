# Repository Architecture

NUmer is a single Flutter package (not a monorepo) organized **by feature, not by type**.
The goal is that every file has one obvious home and a developer or AI agent can understand
a domain by opening one folder.

## Top-level `lib/` layout

```
lib/
  main.dart      # entrypoint only — runApp(NumerBootstrapApp(...))
  app/           # the app shell specific to NUmer (not reusable)
  core/          # cross-cutting infrastructure (side effects, singletons)
  shared/        # pure, reusable UI + helpers (no business logic)
  features/      # the product — one self-contained folder per domain
  l10n/          # generated localization (do not hand-edit)
```

- **`app/`** — composition root: `app_state.dart` (the global `ChangeNotifier`) plus, over
  time, bootstrap/router/root-widget extracted from `main.dart`.
- **`core/`** — headless infrastructure used by features: `data/` (Hive local DB, `storage`,
  `sync_service`, `user_storage`), `notifications/`, `firebase_options.dart`,
  `startup_metrics.dart`. Core never imports a feature.
- **`shared/`** — domain-agnostic UI in `widgets/` (toast, loading screen, avatar, color
  picker, etc.). If it references a domain model or does I/O, it does **not** belong here.
- **`features/`** — see below.

## Anatomy of a feature

```
features/<name>/
  <name>.dart      # barrel: the feature's public surface. Import a feature ONLY via this.
  models/          # domain types
  data/            # services / repositories
  screens/         # full-page routes
  widgets/         # widgets used only inside this feature
```

**Grow-as-needed:** a feature starts flat. Introduce a subfolder (`screens/`, `data/`, …)
only when that category reaches ~3 files. Small features (`ai_analysis`, `courses`) stay flat.

Current features: `auth`, `account`, `habits`, `groups`, `connections`, `courses`,
`sessions`, `stats`, `history`, `ai_analysis`, `home`.

## Dependency rule

```
features  →  core  →  shared
```

One direction only. `core` and `shared` must never import a feature. A feature imports
another feature only through its barrel (`features/<other>/<other>.dart`), never its
internal files.

## Conventions

- **Imports:** absolute `package:numer_app/...` across features; relative within a feature.
- **Filenames:** `*_screen.dart`, `*_service.dart`, `*_sheet.dart` — greppable by suffix.
- **Tests:** mirror the tree under `test/features/<name>/`; app-level smoke tests in `test/smoke/`.

## Boundaries that stay where the tooling needs them

- `functions/` is a separate, independently deployable Node/TypeScript project (Cloud Functions).
- `android/`, `ios/`, `macos/` keep their native structure. The iOS Live Activity
  (`ios/SessionLiveActivityExtension`, `ios/Shared`) is logically owned by the `sessions`
  feature — see `lib/features/sessions/README.md`.
- `pubspec.yaml`, `l10n.yaml`, `firebase.json`, `firestore.*` stay at repo root.

## Creating a new feature

1. `mkdir lib/features/<name>` and add an empty `lib/features/<name>/<name>.dart` barrel.
2. Add files flat; add subfolders only at ~3 files of a kind.
3. `export` the public surface from the barrel.
4. Register its route/provider in `app/`.
5. Add tests under `test/features/<name>/`.
6. Reuse from `shared/` (UI) and `core/` (infra); never copy another feature's file.

## Known follow-ups (deferred, intentionally not done in the restructure)

- Decompose the large `app/app_state.dart` god object into per-feature controllers.
- Split `main.dart` into `app/bootstrap.dart`, `app/router.dart`, `app/app.dart`.
- Break up `core/data/storage.dart`'s dependency on a feature service (`ai_analysis`).
- Repair/unskip `test/features/account/accent_color_picker_test.dart` (pre-existing failure).
