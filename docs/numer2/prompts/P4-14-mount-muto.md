# P4-14: Mount Muto: registry, flag

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-20, P3-11, P4-11

## Goal
Show "Marketplace" in the Campus tab for users whose `muto` flag is on, inside NUmer's
module scaffold, started only when opened and within the download-size budget.

## Read first
- `AGENTS.md`, `docs/numer2/DESIGN.md` sections 3.3, 4.4, 9.5, 10 and 12
- `docs/numer2/DECISIONS.md` D-24, D-27, D-42
- `lib/features/events/` and `lib/features/clavis/` (P4-11, P4-08: descriptor, body,
  lazy-start test), `lib/app/modules/module_registry.dart`
- In Muto at tag `v0.2.0`: `muto_feature/lib/muto_feature.dart`,
  `lib/src/presentation/muto_feature_widget.dart` (`MutoFeature`, `MutoHostSession`,
  `MutoChrome`), `lib/src/data/remote/remote_dependencies.dart` (`createRemoteDependencies`),
  `lib/src/config/muto_config.dart`, `muto_feature/pubspec.yaml`

## Context
- Line numbers are from `main` at `e031f97`; phase 3 and phase 4 files are found by name.
- `MutoFeature(session: MutoHostSession(idToken:, accountId:, onSessionExpired:),
  dependencies: createRemoteDependencies(baseUri: ...), config: MutoConfig.remote(baseUri:
  ...), chrome: MutoChrome.host, beforeFirstListing: ...)`. In host chrome Muto draws its
  own tabs and "New listing" button under NUmer's app bar.
- `muto_feature` depends on `muto_ui` by a relative path inside the Muto repository
  (`muto_feature/pubspec.yaml:16-17`).
- Campus order is Events, Marketplace, Piano room: the registry becomes `[gradusModule,
  eventsModule, mutoModule, clavisModule]`.
- `beforeFirstListing` comes from P4-20; P4-15 fills it, so this task leaves it unset.
- The verified-student sentence is Muto's own string (`contactUnavailableUnverified`,
  changed in P4-20); this task checks it shows for an unverified test account.
- Image packages (`cached_network_image`, `image_picker`) are new to NUmer and are the main
  size risk (`DESIGN.md` 10).
- Strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `moduleMutoTitle` | Marketplace | Маркетплейс | Маркетплейс |
  | `moduleMutoSubtitle` | Buy and sell between students | Покупка и продажа между студентами | Студенттер арасында сату және сатып алу |

## Steps
1. `pubspec.yaml`: add `muto_feature` by git (`url: https://github.com/anxchywl/Muto.git`,
   `path: muto_feature`, `ref: v0.2.0`); `flutter pub get`. If pub refuses the relative path
   dependency on `muto_ui` inside the git package, add under `dependency_overrides` a
   `muto_ui` git entry with the same `url` and `ref` and `path: muto_ui`, and say so in the
   report. Then `cd ios && pod install` and keep `ios/Podfile.lock`; check that the photo and
   camera purpose strings P4-11 added are in `ios/Runner/Info.plist`. Do not start before
   the Muto tag `v0.2.0` exists (F-1).
2. `lib/features/muto/`: barrel `muto.dart` exporting `mutoModule`; `muto_module.dart`
   with top-level `mutoTitle`, `mutoSubtitle`, `buildMutoModule` (`NumerModuleScaffold(title:
   l10n.moduleMutoTitle, body: const MutoModuleBody())`) and `const ModuleDescriptor
   mutoModule = ModuleDescriptor(id: 'muto', ..., icon: Icons.storefront_outlined, section:
   ModuleSection.campus, flagId: 'muto', needsBaseUrl: true, builder: buildMutoModule)`;
   `muto_module_body.dart` building the session and dependencies once in `initState`
   (token contract as P4-04).
3. Registry per Context; `registry_order_test.dart` to `['gradus', 'events', 'muto',
   'clavis']`.
4. Strings: add the two keys; `flutter gen-l10n`.
5. Tests: `test/features/muto/muto_lazy_start_test.dart` (pattern of the Events one); a test
   that the Campus root lists Events, Marketplace, Piano room in that order when all three
   flags and base URLs are set.
6. Run `./scripts/verify.sh`.
7. Size: `scripts/measure_size.sh` before and after; report both numbers and the
   difference against the 1.0 MB budget, and the share of the two image packages from the
   `--analyze-size` summary.
8. Screenshots against the staging Muto backend with the flag on for the test account:
   Campus with three modules, the browse grid, a listing detail with its menu, My listings
   with "New listing", an unverified account's listing detail with the contact sentence;
   light and dark, EN and RU; one at text scale 1.3.

## Non-goals
- No community rules screen or review checklist (P4-15). No change to Muto.
- No marketplace items in the news feed (D-21).

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel. Direction is `features -> core -> shared`.
- The module starts nothing before it is opened (`DESIGN.md` 10).
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. Never add a new path to the baseline.
- Catch only the specific failure you handle.
- No secrets in code or `--dart-define`; the base URL comes from `config/app`.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `muto` to the feature list in `AGENTS.md`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The tests of step 5 exist and pass.
- [ ] The report gives both `apkDownloadBytes` values, the difference and the image packages' share.
- [ ] Screenshots of step 8 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- `USER_ACTIONS.md` F-5 (storage bucket) and F-7 (`modules.muto.baseUrl`).
- Keep the `muto` flag on the `allow` list until P4-19 is deployed and listed and P4-15 is signed off (PLAN gates).

## Deliverable
Branch `numer2/p4-14-mount-muto`, one commit, message `feat: mount the marketplace in campus` (subject line only). Do not push.
Report: files changed, test output, the size numbers, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot resolve `muto_feature` at `v0.2.0`, even with the `muto_ui` override.
- The size grows by more than 1.0 MB.
