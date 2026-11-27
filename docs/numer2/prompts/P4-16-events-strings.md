# P4-16: Events package: strings to ARB in EN, RU and KK

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** EventsBot (`/Users/anx/events_bot`) @ `main`   **Depends on:** P4-10

## Goal
Second of the three Events package tasks (D-42). Every user-facing string of
`events_feature` comes from ARB files with the same keys in English, Russian and Kazakh,
follows the language NUmer runs in, and names NUmer (not the old host) when the session
ends.

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DESIGN.md` section 8 (copy rules) and
  `docs/numer2/DECISIONS.md` D-42 (`/Users/anx/numer_app/docs/numer2/...`)
- `flutter_events/lib/core/localization.dart` (570 lines: the `en`, `ru` and `kk` maps and
  `AppLocalizations.get`)
- Gradus's pattern: `/Users/anx/gradus/gradus_feature/l10n.yaml` and
  `/Users/anx/gradus/gradus_feature/lib/src/l10n/gradus_strings.dart` (39 lines)
- `flutter_events/lib/app.dart` (the startup and session screens), 
  `flutter_events/lib/features/submit/event_form_validation.dart`

## Context
- Line numbers are from EventsBot `main` at `a5a44ef` plus P4-10. Find code by name.
- `AppLocalizations.currentLanguage` is the constant `'en'`, so the package shows English
  only today. The `en` map has 216 keys, `ru` 159 and `kk` 155; 57 keys have no Russian
  value and 61 no Kazakh value. About 230 call sites use `AppLocalizations.get('<key>')`,
  138 distinct keys; some run where no `BuildContext` exists (`api_client.dart:117-121`).
- Because of those context-free uses, the generated class is reached through a static
  `EventsL10n.current`, which `EventsStringsScope` sets from the resolved locale on every
  build (D-42). Widgets may also use `EventsStrings.of(context)`.
- About 45 English literals sit outside the map (for example `app.dart:169`, `:214`,
  `:323`, `:370-371`, `:383`, `:401`, `event_form_validation.dart:72-120`). Two of them name
  the old host "Jas Wallet" (`app.dart:214`, `:371`).
- Copy rules (`DESIGN.md` 8): sentence case, no exclamation marks, the reader is "you", a
  sentence ends with a period, labels and titles do not.
- Fixed texts for the session screens (D-42):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `sessionEndedTitle` | Signed out of Events | Выход из Событий | Іс-шаралардан шықтыңыз |
  | `sessionEndedBody` | Your NUmer session has ended. Go back and open Events again. | Сеанс NUmer завершён. Вернитесь назад и снова откройте События. | NUmer сеансы аяқталды. Артқа оралып, Іс-шараларды қайта ашыңыз. |
  | `startFailed` | Events could not start. Try again. | Не удалось открыть События. Попробуйте снова. | Іс-шаралар ашылмады. Қайталап көріңіз. |

## Steps
1. `flutter_events/l10n.yaml` copied from Gradus with `arb-dir: lib/l10n/arb`,
   `template-arb-file: events_en.arb`, `output-localization-file: events_localizations.dart`,
   `output-class: EventsLocalizations`, `output-dir: lib/l10n/generated`,
   `nullable-getter: false`. `pubspec.yaml`: `flutter_localizations` from the SDK and
   `flutter: generate: true`.
2. Create `lib/l10n/arb/events_en.arb`, `events_ru.arb`, `events_kk.arb`. Keys: every key
   of the old maps that is still used in `lib/` after P4-10 (drop the unused ones), plus one
   new key per literal of Context (camelCase names that say what the text is, for example
   `eventDateInPast`), plus the three keys of the table. Values: the old map's value where
   it exists. Where Russian or Kazakh is missing, write it yourself following `DESIGN.md` 8
   and list every such key with its three values in the report for the owner to review.
   Replace "Jas Wallet" with "NUmer" in any text that keeps a host name.
3. `lib/l10n/events_strings.dart` (pattern of `gradus_strings.dart`): `typedef
   EventsStrings = EventsLocalizations;`, `EventsStringsScope` resolving the ambient
   locale to `en`, `ru` or `kk` (fallback `en`), and `abstract final class EventsL10n {
   static EventsLocalizations current = lookupEventsLocalizations(const Locale('en')); }`.
   `EventsStringsScope.build` sets `EventsL10n.current =
   lookupEventsLocalizations(<resolved>)` before returning the override.
4. Wrap the tree in `EventsStringsScope`: in `EventsFeature.build` (host) and in
   `EventsApp`'s `home` (standalone).
5. Replace every `AppLocalizations.get('<key>')` with `EventsL10n.current.<key>` (a
   ternary over two keys becomes a ternary over two getters) and every literal of Context
   with its new key. Delete `lib/core/localization.dart`.
6. `app.dart` session screens: the host-mode `_SessionRequiredScreen` shows
   `sessionEndedTitle` and `sessionEndedBody`; the startup error shows `startFailed`. The
   standalone development texts become keys too.
7. Tests:
   - `test/l10n_parity_test.dart`: the three ARB files have the same key set and every
     placeholder of a key appears in all three values.
   - `test/no_literals_test.dart`: scans `lib/**/*.dart` except `lib/l10n/generated/` and
     fails on a string literal passed to `Text(`, `text:`, `label:`, `title:`, `hintText:`,
     `labelText:`, `tooltip:`, `message:`, `semanticsLabel:` or returned from a validator
     in `event_form_validation.dart`; an allow-list file `test/no_literals_allow.txt` may
     hold only non-language strings (route names, keys), each with the file and line.
   - `test/events_strings_scope_test.dart`: under `Locale('ru')` a known key renders its
     Russian value and `EventsL10n.current` is Russian; under `Locale('de')` it is English.
8. Run the CI `flutter` job commands in `flutter_events/`, after `flutter gen-l10n`.

## Non-goals
- No layout, colour or chrome change (P4-17). No backend or bot text.
- No new strings beyond the literals that exist and the three of the table.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- Every user-facing string in all three ARB files with identical keys; copy rules of `DESIGN.md` 8.
- Never hand-edit `lib/l10n/generated/`.
- A file you create stays under 400 lines (an ARB file is data and is exempt); a file over 400 lines that you edit does not grow (D-42).
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] The CI `flutter` job commands pass in `flutter_events/`, including the release build.
- [ ] `grep -rn "AppLocalizations.get\|Jas Wallet" flutter_events/lib` prints nothing; `lib/core/localization.dart` is gone.
- [ ] The three tests of step 7 exist and pass.
- [ ] The report lists every Russian and Kazakh value you wrote, key by key.
- [ ] Screenshots of the events list and the submit form in RU and KK, and the session-ended screen in EN.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Review the listed Russian and Kazakh values (as in `USER_ACTIONS.md` B-1).

## Deliverable
Branch `numer2/p4-16-events-strings`, one commit, message `feat: move events strings to arb files` (subject line only). Do not push.
Report: files changed, each command's output, the translation list, screenshots.

## Stop and ask if
- A key is built at run time from data (for example `get('status_$value')`) and cannot become a getter without a lookup table.
- A string comes from the server and is shown as is; leave it and list it.
