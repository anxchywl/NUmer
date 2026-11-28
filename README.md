# NUmer

> A collaborative study-group and personal-productivity app for students — focus timers,
> habit tracking, courses, and social study groups with leaderboards, all offline-first.
> AI insights are paused.

![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-Dart%20%E2%89%A5%203.10-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase)
![Status](https://img.shields.io/badge/status-live%20on%20App%20Store%20%26%20Play%20Store-success)

**Download:** [App Store](https://apps.apple.com/kz/app/numer-app/id6759787785) · [Google Play](https://play.google.com/store/apps/details?id=app.anx.numer) · 200+ active users

NUmer brings time tracking, habits, calendars, study groups and campus news into one app
instead of a handful of disconnected tools. It works fully offline (Hive-backed, synced to
Firebase when online) and is localized in English, Russian, and Kazakh. The Dart source is organized
**feature-first** so each domain lives in one place.

## Documentation

Everything substantive lives in focused docs — this README is just the entry point.

| Doc | What it covers |
|-----|----------------|
| [docs/PRODUCT.md](docs/PRODUCT.md) | **What** the app does — features and user-facing behavior |
| [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) | **How it runs & ships** — architecture, Firebase, Cloud Functions, build/deploy |
| [AGENTS.md](AGENTS.md) | **How the code is organized** — repo/feature layout, conventions, known debt, and rules for contributors |
| [docs/DESIGN.md](docs/DESIGN.md) | Design language, implemented in `packages/numer_ui` |
| [infra/RUNBOOK.md](infra/RUNBOOK.md) | Host hardening runbook |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Performance budgets and baselines |
| [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) | Privacy policy |

## Build and test

Run `./scripts/verify.sh` before opening a pull request; setup, run, release and deploy
commands are in [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md).

## Contributing

1. Branch from `main` (`git checkout -b feature/your-change`).
2. Keep each change scoped to a single feature folder under `lib/features/` where possible.
3. Open a pull request.

AI assistants working in this repo should read [AGENTS.md](AGENTS.md) first.

## License

© NUmer. All rights reserved. See [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md) for data
and privacy terms.
