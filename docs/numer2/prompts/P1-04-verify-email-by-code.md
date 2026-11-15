# P1-04: Email verification by code (client)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-02, P1-03, P0-12

## Goal
A new user should type a 6-digit code from the email instead of leaving the app to tap a
link and coming back to a polling dialog. Replace the existing verification UIs with one
code screen that calls the new callables.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 2, 5.4, 5.5, 6, 7, 8 and 12 (binding)
- `lib/features/auth/auth.dart` (barrel)
- `lib/features/auth/data/auth_service.dart` lines 26-150, 380-510
- `lib/features/auth/screens/auth_screen.dart` lines 400-480 (sign-in form) and 480-720 (register form)
- `lib/features/auth/screens/email_verification_dialog.dart`, `verification_status.dart` (to be deleted)
- `lib/app/auth_gate.dart`
- `packages/numer_ui/lib/numer_ui.dart`
- `lib/shared/widgets/app_toast.dart` (`showAppMessage`)

## Context
Today:
- `AuthController.register` creates the user, calls `user.sendEmailVerification()`, waits one
  second, then writes `email_index`. The register form then opens a non-dismissable
  `EmailVerificationDialog` that polls every 3 seconds.
- `AuthGate` shows `EmailVerificationStatus` whenever `requiresEmailVerification` is true.
- The sign-in form has a branch that reacts to an error containing "verify your email" by
  showing a message with a resend action (about `auth_screen.dart:445-460`). `signIn` never
  returns that text, so the branch is dead.
- `checkEmailVerified` (`auth_service.dart:451-470`) reloads the user and re-runs
  `_handleAuthState`.
- `AuthController` has no `BuildContext`; the caller passes the locale code
  (`Localizations.localeOf(context).languageCode`).
- The password reset sheet and `sendPasswordResetSecure` still call
  `sendEmailVerification` and use a `Timer.periodic`. They are replaced by the next task,
  not this one.
- Toasts use the existing `showAppMessage(context, text, isError: ...)`.

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

Strings to add (all three files):

| key | EN | RU | KK |
|---|---|---|---|
| `codeScreenTitle` | Enter the code | Введите код | Кодты енгізіңіз |
| `codeScreenSubtitle` (`{email}`) | We sent a 6-digit code to {email} | Мы отправили 6-значный код на {email} | {email} мекенжайына 6 таңбалы код жібердік |
| `codeFieldLabel` | 6-digit code | 6-значный код | 6 таңбалы код |
| `verifyCodeButton` | Verify | Подтвердить | Растау |
| `resendCode` | Resend code | Отправить снова | Қайта жіберу |
| `resendCodeIn` (`{seconds}`) | Resend code in {seconds} s | Отправить снова через {seconds} с | {seconds} с кейін қайта жіберу |
| `newCodeSent` | New code sent. | Новый код отправлен. | Жаңа код жіберілді. |
| `codeInvalid` (`{count}`, EN as an ICU plural) | Wrong code. 1 attempt left. / Wrong code. {count} attempts left. | Неверный код. Осталось попыток: {count}. | Код қате. {count} мүмкіндік қалды. |
| `codeInvalidOrExpired` | Wrong or expired code. Request a new one. | Неверный или устаревший код. Запросите новый. | Код қате немесе мерзімі өткен. Жаңасын сұраңыз. |
| `codeExpired` | Code expired. Request a new one. | Код устарел. Запросите новый. | Кодтың мерзімі өтті. Жаңасын сұраңыз. |
| `codeTooManyAttempts` | Too many wrong attempts. Request a new code. | Слишком много неверных попыток. Запросите новый код. | Қате әрекет тым көп. Жаңа код сұраңыз. |
| `codeRateLimited` (`{seconds}`) | Too many requests. Try again in {seconds} s. | Слишком много запросов. Повторите через {seconds} с. | Сұраныс тым көп. {seconds} с кейін қайталаңыз. |
| `codeDeliveryFailed` | Could not send the email. Try again. | Не удалось отправить письмо. Попробуйте ещё раз. | Хатты жіберу мүмкін болмады. Қайталап көріңіз. |
| `codeCheckFailed` | Could not check the code. Try again. | Не удалось проверить код. Попробуйте ещё раз. | Кодты тексеру мүмкін болмады. Қайталап көріңіз. |
| `codeOffline` | No connection. Check the network and try again. | Нет соединения. Проверьте сеть и повторите. | Байланыс жоқ. Желіні тексеріп, қайталаңыз. |
| `emailVerifiedMessage` | Email verified. | Почта подтверждена. | Пошта расталды. |

Add these keys as new keys; do not reuse older keys with similar text. Reuse only the
existing sign-out string.

## Steps
1. `lib/features/auth/data/auth_code_api.dart`:
   - `sealed class CodeResult` with cases `CodeOk(Map<String, dynamic> data)` and
     `CodeFailure(CodeFailureReason reason, {int? attemptsLeft, int? retryAfterSeconds})`;
   - `enum CodeFailureReason { malformedCode, invalidCode, codeExpired, tooManyAttempts,
     rateLimited, noActiveCode, deliveryFailed, noEmail, invalidEmail, malformedInput,
     invalidOrExpiredCode, weakPassword, invalidOrExpiredTicket, offline, unknown }`;
   - `abstract class AuthCodeApi` with one method per callable returning `Future<CodeResult>`;
     the two send methods take the locale code;
   - `FunctionsAuthCodeApi` implementing it with `FirebaseFunctions.instance.httpsCallable`,
     mapping `details['reason']` to the enum, the offline case to `offline`, anything else to
     `unknown`. It catches `FirebaseFunctionsException` only.
2. `AuthController`: take an optional `AuthCodeApi` in the constructor (default
   `FunctionsAuthCodeApi`). Add `Future<CodeResult> sendVerificationCode(String locale)` and
   `Future<CodeResult> verifyEmailCode(String code)`. On `CodeOk` from verify:
   `await user.getIdToken(true)`, then run the existing `checkEmailVerified` path so `AuthGate`
   advances. In `register`, remove `user.sendEmailVerification()` and the one-second delay.
   Leave the `_upsertEmailIndex` line and the `sendEmailVerification` method as they are (later
   tasks remove them).
3. `lib/features/auth/widgets/code_entry_body.dart`: a reusable body (the next task uses it
   too) with parameters `subtitle` (String), `onSubmit(String code) -> Future<CodeResult>`,
   `onResend() -> Future<CodeResult>`, `initialResult` (`CodeResult?`, the result of a send the
   parent started), `initialMessage` (String?, shown in the state line until the first
   result), and `onVerified(CodeOk)`. It reacts to a changed `initialResult` in
   `didUpdateWidget`.

   `CodeEntryBody` layout, top to bottom, side padding `NumerSpace.lg`, column aligned to the
   start:
   1. the `subtitle` text in `context.text.body`, colour `onSurfaceVariant`;
   2. `NumerSpace.xl`;
   3. `NumerOtpField` (autofocus, `semanticsLabel: codeFieldLabel`);
   4. `NumerSpace.sm`;
   5. the state line: one `Text` in `context.text.meta` inside a box with a minimum height of
      16, so the layout does not jump; colour `colorScheme.error` for failures and
      `onSurfaceVariant` otherwise;
   6. `NumerSpace.xl`;
   7. a full-width `FilledButton`, minimum height 48, shape radius `NumerRadius.md`, child
      `NumerButtonChild(label: verifyCodeButton, loading: ...)`; disabled until six digits are
      entered and while a call runs;
   8. `NumerSpace.sm`;
   9. a centred `TextButton`: `resendCodeIn` while the cooldown runs (disabled), `resendCode`
      after.
   No icon, no illustration, no dialog, no other spinner.

   Behaviour:
   - the code submits automatically at six digits and from the button;
   - while a call runs, the button shows its loading state and the field is disabled;
   - a send result (`initialResult` or a resend) with `resendAvailableAt` starts the countdown:
     remaining seconds = that time minus the device time, clamped to 0..60; one `Timer`
     updates it every second and is cancelled in `dispose`;
   - while `initialResult` is null (the first send is still running) the field is enabled, the
     resend button is disabled and the state line is empty;
   - state line and field per failure: `invalidCode` with `attemptsLeft` shows `codeInvalid`
     and sets the field's error state; `invalidCode` without it, `malformedCode`,
     `malformedInput` and `invalidOrExpiredCode` show `codeInvalidOrExpired` with the error
     state; `codeExpired` and `noActiveCode` show `codeExpired`; `tooManyAttempts` shows
     `codeTooManyAttempts` and disables the field and the verify button until a resend
     succeeds; `rateLimited` shows `codeRateLimited` counting down from `retryAfterSeconds` (60
     when absent) and disables both buttons until it reaches zero; `deliveryFailed` and
     `noEmail` show `codeDeliveryFailed`; `offline` shows `codeOffline` and keeps the typed
     code; `unknown` shows `codeCheckFailed`;
   - a successful resend shows `newCodeSent` with `showAppMessage` and clears the field;
   - a successful verify gives `HapticFeedback.lightImpact()` and calls `onVerified`.
4. `lib/features/auth/screens/email_code_screen.dart`: a `Scaffold` with an `AppBar` whose
   title is `codeScreenTitle` in `context.text.screenTitle` and one text action, the existing
   sign-out string. Body: `CodeEntryBody` with `subtitle: codeScreenSubtitle(email)`. In
   `initState` call `sendVerificationCode(locale)` once and pass its result as `initialResult`;
   a result with status `already-verified` runs the verified path instead. On verified show
   `emailVerifiedMessage` with `showAppMessage`.
5. `lib/app/auth_gate.dart`: the `requiresEmailVerification` branch returns `EmailCodeScreen`. In the register form remove the dialog call and the dead `else` branch after it; after a successful `register` the form does nothing more (the gate takes over). In the sign-in form delete the dead "verify your email" branch with its resend action.
6. Delete `email_verification_dialog.dart` and `verification_status.dart` and remove them from the barrel. Remove an ARB key only when `grep` shows no remaining use after this task; keys still used by the password reset sheet stay for the next task. List the removed and the kept keys in the report.
7. Tests with a hand-written `FakeAuthCodeApi`:
   - `test/features/auth/code_entry_body_test.dart`: one test per failure reason handled above
     asserting the text shown and the enabled state of field and buttons; the verify button is
     disabled with five digits; six digits call `onSubmit` once; the countdown reaches zero and
     enables resend (use `tester.pump` with durations); a `resendAvailableAt` far in the future
     is clamped to 60 seconds; resend success clears the field; a late `initialResult` with a
     failure shows its message; at width 320 and text scale 1.3 nothing overflows.
   - `test/features/auth/email_code_screen_test.dart`: mounting calls send once with the
     locale; `cooldown` does not show an error; sign-out is reachable.
   - `test/features/auth/auth_code_api_test.dart`: the reason mapping for every reason in the
     table, an unknown reason, and the offline case.
8. Run `flutter gen-l10n` and `./scripts/verify.sh`.

## Non-goals
- Do not touch the password reset sheet, `sendPasswordResetSecure` or `AuthController.sendEmailVerification` (the next task replaces them).
- Do not remove `email_index` code (P1-06).
- Do not restyle the sign-in or register forms.
- Do not disable Firebase's link emails; older app versions still use them.
- No polling of `user.reload()` anywhere in the new code.

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
- The screen follows `DESIGN.md`: one filled button, the only spinner is inside `NumerButtonChild`, no dialog.
- No literal sizes: spacing from `NumerSpace`, radius from `NumerRadius`, text styles from `context.text`.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, including `check_design.sh` with no new baseline entries for the new files.
- [ ] The three test files pass, with one test per failure reason.
- [ ] `ls lib/features/auth/screens | grep -E "verification_(dialog|status)"` prints nothing.
- [ ] `grep -rn "sendEmailVerification()" lib` prints only lines inside the password reset sheet, `sendPasswordResetSecure` and the method's own definition.
- [ ] `grep -rn "Timer.periodic" lib/features/auth` prints only the countdown in `code_entry_body.dart` and the one in the password reset sheet.
- [ ] Screenshots attached to the report: each new or changed screen in light and dark mode, in EN and RU (add KK where labels are long), plus one at text scale 1.3. For screens that load data: loading, empty and error states. If you cannot run the app on a device or simulator, produce the images from a widget test that pumps the screen and writes them with `matchesGoldenFile` (run with `--update-goldens`), attach them, and do not commit them. Never fabricate an image; if none can be produced, say so.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Sign up on staging with a real inbox and enter the code (`docs/numer2/USER_ACTIONS.md` C-4).

## Deliverable
Branch `numer2/p1-04-verify-email-by-code`, one commit, message `feat: verify email with a six digit code` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, screenshots, anything you could not verify, and user actions still pending.

## Stop and ask if
- `AuthController` is constructed in more than two places, so injecting the API would touch unrelated code.
- Removing the dialog changes what an existing unverified user sees in a way the gate does not cover.
- A new key name already exists in `lib/l10n/app_en.arb` with another meaning.
