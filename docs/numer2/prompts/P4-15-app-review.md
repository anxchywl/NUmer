# P4-15: App Review readiness for user content

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-14

## Goal
Make the marketplace pass App Store guideline 1.2 and Google Play's user-generated-content
policy (D-27): community rules a seller accepts once before their first listing, and one
document that tells the owner and a reviewer where every required control is.

## Read first
- `AGENTS.md`, `docs/numer2/DESIGN.md` sections 3.3, 5.3, 5.4, 8 and 12
- `docs/numer2/DECISIONS.md` D-17, D-27, D-42; `docs/numer2/USER_ACTIONS.md` E-2 and F-6
- `lib/features/muto/` (P4-14), `lib/features/account/` Settings (the delete-account and
  About sections from P1-07 and P3-05)
- In Muto at tag `v0.2.0`: `MutoFeature.beforeFirstListing` (P4-20), Muto `docs/PRODUCT.md`
  (block, report, moderation)

## Context
- Line numbers are from `main` at `e031f97`; later files are found by name.
- Where things are after P4-14 and P4-20: report a listing: Campus -> Marketplace ->
  listing -> More -> Report; block a seller: the same menu, or the seller's profile -> More
  -> Block seller; blocked sellers: My listings -> Blocked sellers; operator actions: the
  Reports tab for holders of the Muto operator role; delete the account: Settings ->
  Delete account (P1-07, it reaches every module through account events, P4-07, P4-18,
  P4-19); contact: Settings -> About -> Contact support (the address of E-2).
- Events content is moderated before it is published (coordinators approve requests), so
  the document mentions it in one line.
- Decisions (D-42): acceptance is stored per user and device in `SharedPreferences` under
  `muto_rules_accepted_v1_<uid>`; the Muto flag stays on the `allow` list until the owner
  signs `docs/APP_REVIEW.md` off; the moderation response time is the owner's (F-6) and the
  document leaves its line for the owner.
- Text of the rules screen (pushed screen, `AppBar` title `communityRulesTitle`, body a
  scrollable column of `body` paragraphs; the five rules as a numbered list):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `communityRulesTitle` | Community rules | Правила сообщества | Қауымдастық ережелері |
  | `communityRule1` | Sell only what is yours to sell. | Продавайте только то, что принадлежит вам. | Тек өзіңізге тиесілі нәрсені сатыңыз. |
  | `communityRule2` | No weapons, drugs, alcohol, tobacco, medicines, fakes or anything illegal in Kazakhstan. | Нельзя продавать оружие, наркотики, алкоголь, табак, лекарства, подделки и всё, что запрещено в Казахстане. | Қару, есірткі, алкоголь, темекі, дәрі-дәрмек, жалған тауар және Қазақстанда заңсыз нәрселерді сатуға болмайды. |
  | `communityRule3` | Describe items honestly and use your own photos. | Описывайте вещи честно и используйте свои фото. | Заттарды шынайы сипаттап, өз суреттеріңізді қолданыңыз. |
  | `communityRule4` | Be respectful. No hate, harassment or adult content. | Будьте уважительны. Без ненависти, травли и контента для взрослых. | Құрметпен қараңыз. Өшпенділік, қуғын-сүргін және ересектерге арналған мазмұнға жол жоқ. |
  | `communityRule5` | Meet in public places on campus and check items before you pay. | Встречайтесь в людных местах кампуса и проверяйте вещь до оплаты. | Кампустың көпшілік орындарында кездесіп, төлемес бұрын затты тексеріңіз. |
  | `communityRulesFooter` | We remove listings that break these rules and may suspend accounts. Report a listing from its menu. | Мы удаляем объявления, нарушающие правила, и можем приостановить аккаунт. Пожаловаться можно из меню объявления. | Ережені бұзған хабарландыруларды өшіреміз және аккаунтты тоқтата аламыз. Хабарландыру мәзірінен шағымдануға болады. |
  | `communityRulesAccept` | Accept | Принять | Қабылдау |
  | `mutoCommunityRules` | Community rules | Правила сообщества | Қауымдастық ережелері |

  `moduleMenu` ("More") exists from P4-11.

## Steps
1. `lib/features/muto/community_rules_screen.dart`: `CommunityRulesScreen({required bool
   askToAccept})`. With `askToAccept`, a full-width primary button `communityRulesAccept`
   pinned at the bottom above the safe area pops `true`; back pops `false`. Without it,
   no button.
2. `lib/features/muto/community_rules_gate.dart`: `Future<bool> confirmCommunityRules(
   BuildContext context, SharedPreferences prefs, String uid)`: returns true when the key
   is set; otherwise pushes the screen with `askToAccept: true` on the root navigator and,
   on `true`, writes the key and returns true.
3. `MutoModuleBody` passes `beforeFirstListing: () => confirmCommunityRules(...)`.
   `buildMutoModule` adds one action, `IconButton(icon: const Icon(Icons.more_vert),
   tooltip: l10n.moduleMenu)` opening a `MenuAnchor` with the row `mutoCommunityRules`,
   which pushes the screen with `askToAccept: false`.
4. In `_clearUserPreferences` (`lib/features/auth/data/local_user_data.dart:21-36`) add
   `await prefs.remove('muto_rules_accepted_v1_$uid');` next to the `fcm_saved_token_$uid`
   line, so the key goes whenever this user's local data is erased (sign-out with nothing
   unsynced, or account deletion) and the rules are shown again after that.
5. Strings: add the keys of the table; `flutter gen-l10n`.
6. `docs/APP_REVIEW.md` (owned by this file alone), with these sections:
   - "Where to find it": a table of the controls of Context with the path a reviewer taps.
   - "Review notes": a paste-ready paragraph for App Store Connect and Play Console: what
     the marketplace is, that only signed-in students post, report and block paths,
     operator moderation, the contact address (`<support address from E-2>`), account
     deletion in Settings; one line on pre-moderated Events.
   - "Test account": the steps to create a reviewer account on production (sign up with a
     test address, verify by code, the owner adds the uid to the `muto` and `events`
     `allow` lists, and removes it after review) and what to type in the stores' test
     account fields. No password in the file.
   - "Moderation duty": `Response time: <owner fills>`, who answers, and how a report
     reaches them (the operator Reports tab).
   - "Sign-off": a checklist the owner ticks: reviewed on iOS and Android, response time
     filled, contact address live, age-rating answers updated, then the `muto` flag may
     leave the `allow` list.
   Link it from `docs/INFRASTRUCTURE.md` where releases are described.
7. Tests:
   - `test/features/muto/community_rules_gate_test.dart`: not accepted -> the screen opens
     with the button; accept -> true and the key set; back -> false and no key; accepted
     -> true without a screen; another uid is asked again.
   - `test/features/muto/community_rules_screen_test.dart`: five rules and the footer
     render in EN and RU; no button without `askToAccept`.
8. Run `./scripts/verify.sh`.
9. Screenshots: the rules screen with and without the button, the module menu; light and
   dark, EN and RU; one at text scale 1.3.

## Non-goals
- No change to Muto or its backend. No store listing edits (owner, F-6).
- No rules for Events or other modules.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel. Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/` stays under 400 lines. A file listed in `scripts/file_size_baseline.txt` may only shrink. Never add a new path to the baseline.
- No secret, password or personal address in the repository; placeholders stay as written.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The tests of step 7 exist and pass.
- [ ] `docs/APP_REVIEW.md` has the five sections of step 6 and every path in "Where to find it" was tapped through on a debug build (say so in the report).
- [ ] Screenshots of step 9 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- `USER_ACTIONS.md` F-6: fill the response time and contact address in `docs/APP_REVIEW.md`, paste the review notes into both stores, update the age ratings, tick the sign-off. Only then widen the `muto` flag.

## Deliverable
Branch `numer2/p4-15-app-review`, one commit, message `feat: add community rules and the app review checklist` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `MutoFeature` has no `beforeFirstListing` in the tagged package.
- A control listed in Context cannot be reached on a debug build.
