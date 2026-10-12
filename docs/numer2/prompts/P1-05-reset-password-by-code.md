# P1-05: Password reset by code (client)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-04

## Goal
Forgot password should be: enter email, enter the code from the email, set a new password,
all inside the app. Replace the link-based reset sheet with these three steps.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 2, 5.4, 5.5, 5.7, 6, 8 and 12 (binding)
- `lib/features/auth/screens/auth_screen.dart` lines 15-50 (private validators and field helpers), 400-480 and 720-965 (`ResetPasswordSheet`)
- `lib/features/auth/data/auth_service.dart` lines 85-105 (`sendEmailVerification`) and 870-1010 (`sendPasswordResetSecure`, `PasswordResetResult`)
- `lib/features/auth/data/auth_code_api.dart`, `lib/features/auth/widgets/code_entry_body.dart`
- `lib/l10n/app_en.arb` (the keys `resetPasswordTitle`, `resetPasswordSubtitle`, `invalidEmailFormat`, `passwordLength`)

## Context
Today `ResetPasswordSheet` (opened only from the sign-in form, with an `initialEmail`) asks
for an email and calls `sendPasswordResetSecure`, which throttles on the client, reads
`email_index` and `users/{uid}.emailVerified`, and finally calls Firebase's
`sendPasswordResetEmail` (a link). The sheet also offers to resend a verification email and
runs its own `Timer.periodic` cooldown.

The register form's rules for a password and an email are private helpers at the top of
`auth_screen.dart` (`_hasInvalidPasswordChars`, `_allowedPasswordCharsRegex`,
`_passwordMaxLength`, `_passwordInputFormatters`, `_emailInputFormatters`, `_emailRegex`).
The new password uses the same rules as registration.

The five callables (already deployed by P1-02). Errors are `FirebaseFunctionsException` with
`details['reason']`:

| Callable | Input | Success | Reasons |
|---|---|---|---|
| `sendEmailVerificationCode` | `{locale}` | `{status: sent, cooldown or already-verified, resendAvailableAt, expiresAt}` (ms since epoch) | `rate-limited` (+ `retryAfterSeconds`), `delivery-failed`, `no-email` |
| `verifyEmailCode` | `{code}` | `{verified: true}` | `malformed-code`, `invalid-code` (+ `attemptsLeft`), `code-expired`, `too-many-attempts`, `rate-limited`, `no-active-code` |
| `requestPasswordResetCode` | `{email, locale}` | `{status: accepted, resendAvailableAt}` | `invalid-email`, `rate-limited` |
| `verifyPasswordResetCode` | `{email, code}` | `{resetTicket}` | `malformed-input`, `invalid-or-expired-code`, `too-many-attempts`, `rate-limited` |
| `confirmPasswordReset` | `{email, resetTicket, newPassword}` | `{success: true}` | `malformed-input`, `weak-password`, `invalid-or-expired-ticket`, `rate-limited` |

A `FirebaseFunctionsException` with code `unavailable` or `deadline-exceeded` and no reason,
or a network error, is the offline case. `locale` is `en`, `ru` or `kk`.

Rules of the new flow:
- The request step always ends the same way, whether or not the account exists, and no text
  claims that a code was sent to an existing account.
- The ticket lives 10 minutes and works once. It is held in memory only.
- The sheet is reached only while signed out. After success every other device is signed
  out by the server; this device just returns to the sign-in form.

Strings to add or change:

| key | EN | RU | KK |
|---|---|---|---|
| `resetPasswordSubtitle` (change) | Enter your email. We will send a 6-digit code. | Введите почту. Мы отправим 6-значный код. | Поштаңызды енгізіңіз. 6 таңбалы код жібереміз. |
| `sendResetCode` | Send code | Отправить код | Код жіберу |
| `resetCodeSentGeneric` (`{email}`) | If an account exists for {email}, a code is on its way. | Если аккаунт с адресом {email} существует, код уже отправлен. | {email} мекенжайымен аккаунт бар болса, код жіберіледі. |
| `newPasswordTitle` | Set a new password | Задайте новый пароль | Жаңа құпиясөз орнатыңыз |
| `newPasswordLabel` | New password | Новый пароль | Жаңа құпиясөз |
| `confirmPasswordLabel` | Repeat the password | Повторите пароль | Құпиясөзді қайталаңыз |
| `passwordsDontMatch` | The passwords do not match. | Пароли не совпадают. | Құпиясөздер сәйкес келмейді. |
| `savePasswordButton` | Save password | Сохранить пароль | Құпиясөзді сақтау |
| `passwordResetSuccess` | Password changed. Sign in with the new password. | Пароль изменён. Войдите с новым паролем. | Құпиясөз өзгертілді. Жаңа құпиясөзбен кіріңіз. |
| `resetSessionExpired` | This reset expired. Start again. | Время сброса истекло. Начните заново. | Қалпына келтіру уақыты өтті. Қайта бастаңыз. |
| `resetStartOver` | Start again | Начать заново | Қайта бастау |
| `resetRequestFailed` | Could not send the request. Try again. | Не удалось отправить запрос. Попробуйте ещё раз. | Сұранысты жіберу мүмкін болмады. Қайталап көріңіз. |
| `passwordSaveFailed` | Could not save the password. Try again. | Не удалось сохранить пароль. Попробуйте ещё раз. | Құпиясөзді сақтау мүмкін болмады. Қайталап көріңіз. |

Existing keys to reuse: `resetPasswordTitle`, `invalidEmailFormat`, `passwordLength`, the
existing email field label, and the keys of `CodeEntryBody`.

## Steps
1. Move the private validators and input formatters listed in Context from `auth_screen.dart` to `lib/features/auth/widgets/auth_validators.dart` as public top-level members, and use them from both files. No behaviour change in the register form.
2. `AuthController`: add `requestPasswordResetCode(String email, String locale)`, `verifyPasswordResetCode(String email, String code)`, `confirmPasswordReset(String email, String ticket, String newPassword)`, each returning `Future<CodeResult>` through `AuthCodeApi`.
3. Rewrite `ResetPasswordSheet` in `lib/features/auth/screens/reset_password_sheet.dart`,
   keeping its `initialEmail` parameter, as one bottom sheet with an internal step state
   `email`, `code`, `newPassword`. Sheet frame per `DESIGN.md` 5.7: background
   `colorScheme.surfaceContainerLow`, top radius `NumerRadius.xl`, a drag handle, padding
   `NumerSpace.lg`, bottom inset following the keyboard so the button stays visible. Text
   fields are filled (`surfaceContainerHighest`), radius `NumerRadius.md`, no outline, no
   prefix icon, with a floating label. Password fields are obscured and have no visibility
   toggle.

   Step `email`, top to bottom: title `resetPasswordTitle` (`context.text.sectionTitle`);
   `NumerSpace.sm`; `resetPasswordSubtitle` (`context.text.body`, `onSurfaceVariant`);
   `NumerSpace.lg`; the email field; `NumerSpace.sm`; a state line (`context.text.meta`,
   `colorScheme.error`, minimum height 16); `NumerSpace.xl`; a full-width `FilledButton` (48
   high, radius `NumerRadius.md`) with `NumerButtonChild(label: sendResetCode, loading: ...)`.
   Results: `CodeOk` goes to `code`; `invalidEmail` (and a locally invalid address, checked
   first) shows `invalidEmailFormat`; `rateLimited` shows `codeRateLimited` with its countdown
   and disables the button until zero; `offline` shows `codeOffline`; anything else shows
   `resetRequestFailed`.

   Step `code`: title `codeScreenTitle`; `NumerSpace.sm`; then `CodeEntryBody` with
   `subtitle: resetCodeSentGeneric(email)`, `onSubmit` calling `verifyPasswordResetCode`,
   `onResend` calling `requestPasswordResetCode`, and `initialResult` set to the result of the
   request; under it a centred `TextButton` `resetStartOver` that returns to `email` and
   forgets the ticket. On verified keep the ticket in a field and go to `newPassword`.

   Step `newPassword`: title `newPasswordTitle`; `NumerSpace.lg`; field `newPasswordLabel`;
   `NumerSpace.md`; field `confirmPasswordLabel`; `NumerSpace.sm`; the state line;
   `NumerSpace.xl`; a full-width `FilledButton` with
   `NumerButtonChild(label: savePasswordButton, loading: ...)`; `NumerSpace.sm`; the centred
   `TextButton` `resetStartOver`. Validate before calling: the registration password rules
   (their existing messages) and equality (`passwordsDontMatch`). Results: `CodeOk` closes the
   sheet, shows `passwordResetSuccess` with `showAppMessage`, and gives a light haptic;
   `invalidOrExpiredTicket` and `malformedInput` return to `email` with `resetSessionExpired`
   in its state line; `weakPassword` shows `passwordLength`; `rateLimited` shows
   `codeRateLimited`; `offline` shows `codeOffline`; anything else shows `passwordSaveFailed`.
4. Delete what the old sheet needed and nothing else uses: `sendPasswordResetSecure`, `PasswordResetResult`, `_lastResetRequestMs`, `AuthController.sendEmailVerification`, the old sheet's `Timer.periodic`, and the ARB keys that lose their last use (expected: `resetLinkSent`, `sendResetLink`, `verifyEmailFirst`, `resendVerificationEmail`, `signInToResend`, `verificationEmailSent`, `resendEmail`). Confirm each with `grep` and list them in the report.
5. Tests with `FakeAuthCodeApi` in `test/features/auth/reset_password_sheet_test.dart`: the
   three steps in order end with the sheet closed and the success message, and no sign-out
   call; an unknown email behaves exactly like a known one up to the code step and shows the
   same texts; mismatched passwords do not call the API; one test for each of `invalidEmail`,
   `rateLimited` and `offline` on the email step, and `weakPassword`, `invalidOrExpiredTicket`
   and `offline` on the password step; "Start again" returns to the email step; at width 320
   and text scale 1.3 nothing overflows on any step.
6. Run `flutter gen-l10n` and `./scripts/verify.sh`.

## Non-goals
- Do not call `sendPasswordResetEmail` anywhere.
- Do not read `email_index` or `users/{uid}` in this flow.
- Do not tell the user whether an account exists.
- Do not call `signOut` at the end of the flow: there is no session, and the call would leave the controller in a signing-out state.
- Do not change the verification screen from P1-04 beyond what `CodeEntryBody`'s parameters already allow.
- Do not change the register form's behaviour or how it reports an address that is already registered (P1-06 does).

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- The reset ticket is held in memory only: not in `SharedPreferences`, Hive, a route argument or a log.
- No literal sizes: spacing from `NumerSpace`, radius from `NumerRadius`, text styles from `context.text`.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, including `check_design.sh` with no new baseline entries for the new files.
- [ ] `grep -rn "sendPasswordResetEmail\|sendPasswordResetSecure\|sendEmailVerification" lib` prints nothing.
- [ ] `grep -rn "Timer.periodic" lib/features/auth` prints only the countdown in `code_entry_body.dart`.
- [ ] The test file passes with every case of step 5.
- [ ] `grep -c "resetCodeSentGeneric\|resetStartOver\|passwordSaveFailed" lib/l10n/app_en.arb lib/l10n/app_ru.arb lib/l10n/app_kk.arb` prints 3 or more for each.
- [ ] Screenshots attached to the report: each new or changed screen in light and dark mode, in EN and RU (add KK where labels are long), plus one at text scale 1.3. For screens that load data: loading, empty and error states. If you cannot run the app on a device or simulator, produce the images from a widget test that pumps the screen and writes them with `matchesGoldenFile` (run with `--update-goldens`), attach them, and do not commit them. Never fabricate an image; if none can be produced, say so.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Reset a password on staging; confirm a second signed-in device is signed out within an hour (`docs/numer2/USER_ACTIONS.md` C-4).

## Deliverable
Branch `numer2/p1-05-reset-password-by-code`, one commit, message `feat: reset password with a six digit code` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, screenshots, anything you could not verify, and user actions still pending.

## Stop and ask if
- `ResetPasswordSheet` is opened from a place where a user is signed in.
- A validator cannot be moved without changing the register form's behaviour.
- One of the existing keys named in Context does not exist under that name.
