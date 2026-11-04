# NUmer

> A collaborative study-group and personal-productivity app for students — focus timers,
> habit tracking, courses, and social study groups with leaderboards, all offline-first.
> AI insights are paused.

![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-Dart%20%E2%89%A5%203.10-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase)
![Version](https://img.shields.io/badge/version-1.0.3-informational)
![Status](https://img.shields.io/badge/status-live%20on%20App%20Store%20%26%20Play%20Store-success)

**Download:** [App Store](https://apps.apple.com/kz/app/numer-app/id6759787785) · [Google Play](https://play.google.com/store/apps/details?id=app.anx.numer) · 200+ active users

NUmer brings time tracking, habits, calendars, and study groups into one dashboard instead of
a handful of disconnected tools. It works fully offline (Hive-backed, synced to Firebase when
online) and is localized in English, Russian, and Kazakh. The Dart source is organized
**feature-first** so each domain lives in one place.

## Documentation

Everything substantive lives in focused docs — this README is just the entry point.

| Doc | What it covers |
|-----|----------------|
| [docs/PRODUCT.md](docs/PRODUCT.md) | **What** the app does — features and user-facing behavior |
| [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) | **How it runs & ships** — architecture, Firebase, Cloud Functions, build/deploy |
| [AGENTS.md](AGENTS.md) | **How the code is organized** — repo/feature layout, conventions, and rules for AI assistants |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Performance budgets and baselines |
| [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) | Privacy policy |

## Repository structure

```text
numer_app/
├── lib/            # Flutter app source, organized by feature (see AGENTS.md)
├── functions/      # Firebase Cloud Functions (Node.js / TypeScript)
├── android/        # native Android project
├── ios/            # native iOS project (incl. Session Live Activity extension)
├── macos/          # native macOS project
├── assets/         # app icon and static assets
├── test/           # widget and smoke tests
├── docs/           # PRODUCT, INFRASTRUCTURE, PERFORMANCE, privacy policy
├── firestore/      # Firestore security rules and indexes
├── firebase.json · .firebaserc            # Firebase CLI config (must stay at root)
└── pubspec.yaml · l10n.yaml               # Flutter + localization config (must stay at root)
```

## Getting started

### Prerequisites

- Flutter SDK with Dart ≥ 3.10
- Node.js 20+ and the Firebase CLI (`npm i -g firebase-tools`) for the backend
- Platform Firebase config files in place: `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist`

### Setup & run

```bash
git clone https://github.com/anxchywl/NUmer.git
cd NUmer

flutter pub get
(cd functions && npm install)   # Cloud Functions dependencies

flutter run                     # with a simulator/emulator running
```

Full setup (emulators, secrets, deploying rules and functions, release builds) is documented
in [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md).

## Testing & quality

```bash
./scripts/verify.sh
```

It must pass before opening a PR. The script header lists what it does not run.

## Contributing

1. Branch from `main` (`git checkout -b feature/your-change`).
2. Keep each change scoped to a single feature folder under `lib/features/` where possible.
3. Ensure `./scripts/verify.sh` passes.
4. Open a pull request.

AI assistants working in this repo should read [AGENTS.md](AGENTS.md) first.

## License

© NUmer. All rights reserved. See [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) for data
and privacy terms.
