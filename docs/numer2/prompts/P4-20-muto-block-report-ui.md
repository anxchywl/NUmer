# P4-20: Muto package: block, report and moderation UI

**Recommended model:** sonnet   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** Muto (`/Users/anx/muto`) @ `main`   **Depends on:** P4-13, P4-12

## Goal
Put the controls of P4-12 in front of people (D-27): a student can report a listing and
block or unblock a seller from menus and see whom they blocked; an operator can hide,
restore, suspend, lift a suspension and dismiss from the Reports tab; an owner sees when a
listing was hidden by moderation, and a banned word gets a clear message. Split from P4-13
(D-42).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DESIGN.md` sections 5.3, 5.7, 5.8, 5.9, 6, 8
  and 11, `docs/numer2/DECISIONS.md` D-27, D-42 (`/Users/anx/numer_app/docs/numer2/...`)
- Muto `docs/API.md` (the P4-12 endpoints and errors)
- `muto_feature/lib/src/presentation/listing/listing_detail_screen.dart:520-620` (the
  floating report control), `seller/seller_profile_screen.dart`,
  `report/report_sheet.dart`, `operations/report_operations_screen.dart` (169 lines),
  `my_listings` screen, `lib/src/data/remote/remote_repositories.dart`,
  `lib/src/domain/repositories/`, `lib/src/data/mock/mock_listing_repository.dart`,
  `lib/src/l10n/arb/app_{en,ru,kk}.arb`

## Context
- Line numbers are from Muto `main` at `9467cc5` plus P4-13. Find code by name.
- Today a report is sent from a flag `IconButton` floating over the listing photo
  (`listing_detail_screen.dart:575-590`) through `showReportSheet`; there is no block, no
  report status in the app and the operator tab only lists reports.
- Menus (D-42): the listing detail's floating report control becomes an
  `IconButton(icon: AppIcons.moreVert, tooltip: strings.moreActions)` opening a
  `MenuAnchor` with "Report" (today's sheet; after it is sent, or when the API answers 409
  because this user already reported it, the row reads "Reported" and is disabled for this
  visit) and "Block seller" (or "Unblock seller" when the listing carries
  `seller_blocked: true`, P4-12); the menu is absent on your own
  listing. The seller profile's app bar has the same button with "Block seller" or
  "Unblock seller" (from `seller_blocked`). Block asks with `showNumerConfirm(title: blockSellerTitle, body:
  blockSellerBody, confirmLabel: blockSeller)`; unblock needs no confirmation. After a
  block the screen pops back to the tab root and the feeds refresh.
- "Blocked sellers": the host's app bar menu cannot reach the package's scope, so it is a
  `NumerRow` at the top of the My listings tab that pushes a list of blocked sellers, each a
  row with an "Unblock" text button; empty state `blockedSellersEmpty` (D-42).
- Operator tab (holders of `muto:admin`): the report response carries `seller_id`,
  `seller_account_status` and `listing_moderation_hidden` (P4-12). Each open report gets text buttons "Hide listing", "Suspend seller",
  "Dismiss"; each opens a form sheet with one required reason field (focus mode, one field,
  so no Done swap) and sends the P4-12 endpoint with `report_id`. A row at the top,
  "Handled reports", pushes the reports with status `actioned` or `dismissed`, each with
  "Restore listing" or "Lift suspension" where it applies. A successful action shows
  `showNumerMessage(opsActionDone)` and removes the report from the open list.
- Owner: a listing with `moderation_hidden: true` shows the status label "Hidden by
  moderation" (`DESIGN.md` 5.8, `error` colour) and its status controls are disabled.
- Editor: a 422 `listing_text_blocked` shows `listingTextBlocked` under the title field.
- Host hook for P4-15 (D-42): `MutoFeature` gains `Future<bool> Function()?
  beforeFirstListing`. When set, opening the editor from "New listing" awaits it first and
  opens nothing when it returns false. NUmer uses it to show its community rules once.
- Verified state (`DESIGN.md` 9.5, P4-14): the existing `contactUnavailableUnverified`
  ("Verify your student account to see contact details.") does not say how inside NUmer;
  its three values change to the ones in the table.
- Strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `moreActions` | More | Ещё | Тағы |
  | `menuReport` | Report | Пожаловаться | Шағымдану |
  | `menuReported` | Reported | Жалоба отправлена | Шағым жіберілді |
  | `blockSeller` | Block seller | Заблокировать продавца | Сатушыны бұғаттау |
  | `unblockSeller` | Unblock seller | Разблокировать продавца | Сатушыны бұғаттан шығару |
  | `blockSellerTitle` | Block this seller? | Заблокировать этого продавца? | Бұл сатушыны бұғаттау керек пе? |
  | `blockSellerBody` | You will not see their listings, and they are not told. | Вы не будете видеть его объявления, а он об этом не узнает. | Сіз оның хабарландыруларын көрмейсіз, ал оған бұл туралы хабарланбайды. |
  | `sellerBlocked` | Seller blocked. | Продавец заблокирован. | Сатушы бұғатталды. |
  | `sellerUnblocked` | Seller unblocked. | Продавец разблокирован. | Сатушы бұғаттан шығарылды. |
  | `blockedSellersTitle` | Blocked sellers | Заблокированные продавцы | Бұғатталған сатушылар |
  | `blockedSellersEmpty` | You have not blocked anyone. | Вы никого не заблокировали. | Сіз ешкімді бұғаттаған жоқсыз. |
  | `unblock` | Unblock | Разблокировать | Бұғаттан шығару |
  | `opsHideListing` | Hide listing | Скрыть объявление | Хабарландыруды жасыру |
  | `opsSuspendSeller` | Suspend seller | Приостановить продавца | Сатушыны тоқтата тұру |
  | `opsDismiss` | Dismiss | Отклонить | Қабылдамау |
  | `opsRestoreListing` | Restore listing | Вернуть объявление | Хабарландыруды қайтару |
  | `opsUnsuspendSeller` | Lift suspension | Снять приостановку | Тоқтатуды алып тастау |
  | `opsReasonLabel` | Reason | Причина | Себебі |
  | `opsReasonRequired` | Give a reason. | Укажите причину. | Себебін көрсетіңіз. |
  | `opsHandledReports` | Handled reports | Обработанные жалобы | Қаралған шағымдар |
  | `opsActionDone` | Done. | Готово. | Дайын. |
  | `listingModerated` | Hidden by moderation | Скрыто модерацией | Модерациямен жасырылды |
  | `contactUnavailableUnverified` (changed) | Contact details are shown only to accounts with a verified @nu.edu.kz email. | Контакты видны только аккаунтам с подтверждённой почтой @nu.edu.kz. | Байланыс деректері тек расталған @nu.edu.kz поштасы бар аккаунттарға көрінеді. |
  | `listingTextBlocked` | This text contains words that are not allowed. | В тексте есть недопустимые слова. | Мәтінде рұқсат етілмеген сөздер бар. |

## Steps
1. Domain and data: a `BlockRepository` interface (`block(sellerId)`, `unblock(sellerId)`,
   `list({cursor})`) in `domain/repositories/`, its remote implementation over
   `/api/v1/blocks`, and a mock one; operator methods `hideListing`, `restoreListing`,
   `suspendUser`, `unsuspendUser`, `dismissReport` (each with `reason` and optional
   `reportId`) and `reports({status})` on the operations repository; `Listing` gains
   `moderationHidden`; the editor maps 422 `listing_text_blocked` to a failure the form can
   show. Wire them in `MutoDependencies` and `createRemoteDependencies`.
2. Listing and seller menus per Context; delete the floating report control.
3. Blocked sellers row and screen per Context (new file
   `presentation/blocks/blocked_sellers_screen.dart`), paginated like favourites, with the
   four states (`DESIGN.md` 6).
4. Operator tab per Context: action buttons, the reason sheet
   (`presentation/operations/moderation_reason_sheet.dart`, `showNumerFormSheet` +
   `NumerSheetBody`), the handled list (`handled_reports_screen.dart`). Destructive actions
   (hide, suspend) use `destructive: true` buttons in the sheet.
5. Owner status label and disabled controls; the editor's blocked-word message; the
   `beforeFirstListing` hook of Context.
6. Strings: add the keys of the table to the three ARB files; `flutter gen-l10n`.
7. Tests (hand-written fakes over the repositories):
   - listing menu: Report opens the sheet and then reads "Reported"; Block asks, then calls
     `block` and pops; Unblock calls `unblock` without asking; no menu on your own listing.
   - seller menu: block and unblock.
   - blocked sellers screen: loading, empty, error with retry, two rows, unblock removes
     the row.
   - operator tab: each action sends its endpoint with the reason and the report id, the
     reason is required, a success removes the report and shows the message; the handled
     list offers restore and lift.
   - owner: a `moderationHidden` listing shows "Hidden by moderation" and disabled status
     controls; the editor shows the blocked-word message on that failure.
   - `beforeFirstListing` returning false opens no editor; returning true opens it; unset
     opens it directly.
   - every new icon-only control has a non-empty tooltip.
8. Run `./scripts/verify.sh` (coverage floor 70).

## Non-goals
- No backend change. No NUmer code (P4-14, P4-15).
- No report of a seller (the API reports listings only), no appeal, no blocked-user search.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart` and `Numer*`; confirmations are `showNumerConfirm`; messages are `showNumerMessage`. No new colour, radius, text style, font or icon package. Every icon-only control has a tooltip.
- Every sheet or dialog with a text field uses focus mode; a loading button shows only its spinner and passes `loadingHint`.
- Every user-facing string in the three ARB files, with the values of the table.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings (convert the `///` you touch), debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 with the coverage floor of 70.
- [ ] The tests of step 7 exist and pass.
- [ ] `listing_detail_screen.dart` is no longer than it was after P4-13 (state both counts); the menu lives in its own file.
- [ ] Screenshots from `muto_app` (sample backend) in host chrome: the listing menu, the block confirmation, blocked sellers (empty and with rows), the operator tab with actions, the reason sheet while typing, an owner's moderated listing; light and dark, EN and RU.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- After review: `git tag v0.2.0 && git push origin v0.2.0` in Muto (`USER_ACTIONS.md` F-1).

## Deliverable
Branch `numer2/p4-20-muto-block-report-ui`, one commit, message `feat: add block, report and moderation controls` (subject line only). Do not push.
Report: files changed, verify output, screenshots, user actions still pending.

## Stop and ask if
- The P4-12 endpoints differ from Muto's `docs/API.md`.
- The listing detail has no place for an app bar action in host chrome.
