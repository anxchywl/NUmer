# P0-01: Pause AI analysis behind a coming-soon screen

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** none

## Goal
The `analyzeCourseAi` callable calls a Gemini model that was shut down on 2026-06-01, so every
analysis fails and the app shows a built-in sample analysis as if it were real. The owner has
decided to pause the feature: the entry points stay, the screen says the feature is coming
soon, and the callable and every piece of Gemini code are removed. AI analysis returns later
as its own task (P5-07).

## Read first
- `AGENTS.md`
- `lib/features/ai_analysis/ai_analysis.dart`, `ai_analysis_screen.dart`, `ai_analysis_service.dart`
- `lib/core/data/storage.dart` lines 1-20 and 835-960 (the analysis cache)
- `lib/features/home/home.dart` lines 440-510 (the two buttons that open the screen)
- `functions/src/index.ts` lines 1-100 (imports and API key loading), 186-310 (fallback analysis), 1123-1199 (the callable)
- `functions/package.json`

## Context
- Entry points: `home.dart:457` (iOS action pill) and `home.dart:495` (Android FAB) push
  `AiAnalysisScreen`. Both stay as they are.
- `ai_analysis_service.dart` holds the models (`AiTopic`, `AiRecommendation`,
  `AiCourseAnalysis`, `AnalysisPeriod`), reads reflections from Firestore, builds the prompt,
  calls the callable and returns `_getMockAnalysis` on failure.
- `lib/core/data/storage.dart:13` imports the service only for the local analysis cache
  (`getCourseAnalysis`, `saveCourseAnalysis`, `_metaAnalysisLog`, `_metaAnalysisContent`,
  `_analysisLocalTtl`, about lines 841-960). Removing the cache also removes one of the
  `core` imports of a feature.
- The ARB key `courseAnalysis` already exists and is the screen title.
- Server: `analyzeCourseAi` (`functions/src/index.ts:1123`) is the only user of
  `GoogleGenerativeAI`, of the `GEMINI_API_KEY` loading code (`process.env` plus a
  `.env.local` fallback, about lines 25-90), of `MAX_PROMPT_LENGTH` and of
  `buildFallbackAnalysis` with its helpers and types. Check this with grep before deleting.
- Installed app versions keep calling `analyzeCourseAi`. Once it is deleted they get an error
  and show their sample analysis, as they have since June. Accepted by the owner.
- Copy rules: `docs/numer2/DESIGN.md` section 8. The empty-state rule allows one sentence and
  one action; here the app bar back button is the action, so the body has no button.
- `npm` against the public registry is allowed. No deploy.

## Steps
1. Rewrite `lib/features/ai_analysis/ai_analysis_screen.dart` as a `StatelessWidget`
   `AiAnalysisScreen` (same class name, `const` constructor): a `Scaffold` whose `AppBar`
   title is `AppLocalizations.of(context)!.courseAnalysis`, and whose body is
   `Center(child: Padding(padding: EdgeInsets.all(24), child: Text(l10n.aiAnalysisComingSoon,
   textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge)))`. No icon, no
   gradient, no button, no spinner.
2. Delete `lib/features/ai_analysis/ai_analysis_service.dart`. In `ai_analysis.dart` keep only
   `export 'ai_analysis_screen.dart';`.
3. In `lib/core/data/storage.dart` delete the import at line 13, `getCourseAnalysis`,
   `saveCourseAnalysis`, `_metaAnalysisLog`, `_metaAnalysisContent`, `_analysisLocalTtl` and
   any private helper used only by them. Leave the cached values already stored on devices
   alone.
4. Add the ARB key `aiAnalysisComingSoon`:
   - EN `Course analysis is coming soon.`
   - RU `Анализ курса скоро появится.`
   - KK `Курс талдауы жақында пайда болады.`
   Then, for every other key referenced in the old screen or service, run
   `grep -rn "\.<key>\b" lib --include=*.dart` excluding `lib/l10n/`; delete the key and its
   `@<key>` metadata from all three ARB files when nothing else uses it. Keep `courseAnalysis`.
   Run `flutter gen-l10n`.
5. Add `test/features/ai_analysis/ai_analysis_screen_test.dart`: pump `AiAnalysisScreen` in a
   `MaterialApp` with `AppLocalizations.localizationsDelegates` and `supportedLocales`, for
   `en` and `ru`; expect the coming-soon text, the title, and no `CircularProgressIndicator`,
   `FilledButton`, `ElevatedButton` or `TextButton`.
6. Server, `functions/src/index.ts`: delete the `analyzeCourseAi` export and every symbol only
   it uses (the list under Context), including the `@google/generative-ai` import. Then
   `cd functions && npm uninstall @google/generative-ai`.
7. If `docs/INFRASTRUCTURE.md`, `docs/PRODUCT.md`, `README.md` or `AGENTS.md` mention the AI
   analysis, Gemini or `GEMINI_API_KEY`, change them to say the feature is paused and the
   callable removed.

## Non-goals
- Do not change the two entry buttons on Home, their icons or their position.
- Do not touch any other function, and do not split `index.ts` (that is P0-04).
- Do not delete cached analysis values from Hive or `SharedPreferences` on devices.
- Do not edit `firestore/firestore.rules`.
- Do not build any part of the future AI analysis.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `grep -rni "gemini\|generative-ai\|analyzeCourseAi" functions/src functions/package.json` prints nothing.
- [ ] `grep -rn "analyzeCourseAi\|AiAnalysisService\|_getMockAnalysis\|ai_analysis_service" lib test` prints nothing.
- [ ] `grep -n "features/" lib/core/data/storage.dart` no longer lists `ai_analysis`.
- [ ] `cd functions && npm ci && npm run build` exits 0.
- [ ] `flutter analyze` exits 0 and `flutter test` passes, including the new screen test.
- [ ] `grep -c "\"aiAnalysisComingSoon\"" lib/l10n/app_en.arb lib/l10n/app_ru.arb lib/l10n/app_kk.arb` prints 1 for each file.
- [ ] The report lists every ARB key removed, with the grep that showed it unused.
- [ ] Screenshots of the screen in light and dark mode, in EN and RU, attached to the report.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Delete the deployed callable: `firebase functions:delete analyzeCourseAi --project numer-60744` (`docs/numer2/USER_ACTIONS.md` B-0).
- Optional: `firebase functions:secrets:destroy GEMINI_API_KEY --project numer-60744`, and revoke the key in Google AI Studio.

## Deliverable
Branch `numer2/p0-01-pause-ai-analysis`, one commit, message `feat: pause ai analysis behind a coming soon screen` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, screenshots, anything you could not verify, and user actions still pending.

## Stop and ask if
- Anything outside `analyzeCourseAi` uses the Gemini key loader, `MAX_PROMPT_LENGTH` or `buildFallbackAnalysis`.
- `AiCourseAnalysis`, `AnalysisPeriod` or another type from the service is used outside `lib/features/ai_analysis/` and the storage cache.
- `flutter analyze` or `flutter test` fails before your change (report the output).
