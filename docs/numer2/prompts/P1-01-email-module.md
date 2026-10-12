# P1-01: Transactional email module

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
The auth rework sends 6-digit codes in NUmer's own emails instead of Firebase's link emails.
Build the part that renders a localized email and hands it to a provider, behind one
interface, with a queue for the cases where the sender must not wait for delivery.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-18 and D-19
- `docs/numer2/DESIGN.md` section 8 (copy rules apply to emails too)
- `functions/src/shared/admin.ts`, `functions/src/ai/analyze_course.ts` (the `runWith({secrets})` pattern)
- `functions/test/emulator/` (test style)

## Context
- The provider is Resend unless the task message names another. Its API: `POST
  https://api.resend.com/emails`, header `Authorization: Bearer <key>`, JSON body
  `{from, to: [address], subject, html, text}`; any 2xx is success.
- Node 20 has a global `fetch`. Add no HTTP or mail package.
- Secrets: `MAIL_API_KEY`. Parameters from the environment: `MAIL_FROM` (for example
  `NUmer <no-reply@mail.example.org>`), `MAIL_PROVIDER` (`resend` or `console`).
- The `console` provider logs that an email would be sent, without the code, and is refused
  when `process.env.GCLOUD_PROJECT === 'numer-60744'`.
- Three templates: `verify`, `reset`, `passwordChanged`. Three locales: `en`, `ru`, `kk`.
- An email has no link, no image and no tracking. The subject never contains the code.
- `mailQueue` is a server-only collection (already denied in the rules).
- Firestore triggers can run more than once for one document; a rare duplicate email is
  accepted.
- Tests call handlers in the test process; the functions emulator is not started.
- If `npm run build` does not know `fetch` or `AbortController`, add `@types/node@20` as a
  dev dependency and say so in the report. Add no other package.

## Steps
1. `functions/src/mail/types.ts`: `type MailTemplate = 'verify' | 'reset' | 'passwordChanged'`,
   `type MailLocale = 'en' | 'ru' | 'kk'`, `interface MailMessage {to: string; subject: string;
   html: string; text: string}`, `interface MailSender {send(message: MailMessage): Promise<void>}`,
   `class MailDeliveryError extends Error { constructor(public status: number) { super('mail
   delivery failed'); this.name = 'MailDeliveryError'; } }`.
2. `functions/src/mail/templates.ts`: `renderEmail(template, locale, vars: {code?: string}):
   {subject, html, text}`. An unknown locale falls back to `en`. Text, exactly:

   | key | EN | RU | KK |
   |---|---|---|---|
   | verify subject | Your NUmer verification code | Код подтверждения NUmer | NUmer растау коды |
   | verify line 1 | Enter this code in the app to verify your email. | Введите этот код в приложении, чтобы подтвердить почту. | Поштаңызды растау үшін осы кодты қолданбаға енгізіңіз. |
   | reset subject | Your NUmer password reset code | Код для сброса пароля NUmer | NUmer құпиясөзін қалпына келтіру коды |
   | reset line 1 | Enter this code in the app to set a new password. | Введите этот код в приложении, чтобы задать новый пароль. | Жаңа құпиясөз орнату үшін осы кодты қолданбаға енгізіңіз. |
   | validity (verify, reset) | The code is valid for 10 minutes. | Код действует 10 минут. | Код 10 минут жарамды. |
   | verify footer | If you did not create a NUmer account, ignore this email. | Если вы не создавали аккаунт NUmer, проигнорируйте это письмо. | NUmer аккаунтын ашпаған болсаңыз, бұл хатты елемеңіз. |
   | reset footer | If you did not ask to reset your password, ignore this email. Your password stays the same. | Если вы не запрашивали сброс пароля, проигнорируйте это письмо. Пароль останется прежним. | Құпиясөзді қалпына келтіруді сұрамаған болсаңыз, бұл хатты елемеңіз. Құпиясөзіңіз өзгермейді. |
   | passwordChanged subject | Your NUmer password was changed | Пароль NUmer изменён | NUmer құпиясөзі өзгертілді |
   | passwordChanged line 1 | The password of your NUmer account was just changed. All devices were signed out. | Пароль вашего аккаунта NUmer только что изменён. Выполнен выход на всех устройствах. | NUmer аккаунтыңыздың құпиясөзі жаңа ғана өзгертілді. Барлық құрылғылардан шығу орындалды. |
   | passwordChanged footer | If this was not you, reset your password in the app now. | Если это были не вы, сразу сбросьте пароль в приложении. | Бұл сіз болмасаңыз, қолданбада құпиясөзді дереу қалпына келтіріңіз. |

   Plain text: line 1, a blank line, the code on its own line (verify and reset only), a blank
   line, the validity line (verify and reset only), a blank line, the footer.
   HTML: one `<html lang="...">` document with `<meta name="color-scheme" content="light dark">`;
   a single centred table 480 px wide at most; inline styles only; font stack
   `-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif`; the word `NUmer`
   at 20 px, weight 700, colour `#448AFF`; line 1 at 16 px; the code at 32 px, weight 700,
   `letter-spacing: 6px`, `font-family: ui-monospace, Menlo, Consolas, monospace`; validity and
   footer at 13 px in `#5F6368`; line 1 and the code in `#202124`; no background colour.
   Escape every interpolated value.
3. `functions/src/mail/resend_sender.ts`: `class ResendMailSender implements MailSender`,
   constructed with `{apiKey, from, fetchImpl = fetch}`. It posts the body above with a 10
   second `AbortController` timeout and throws `MailDeliveryError(status)` on a non-2xx status
   and `MailDeliveryError(0)` on a network error or timeout. It never logs the message.
   `functions/src/mail/console_sender.ts`: logs `{to: '<redacted>', subject}` with
   `functions.logger.info` and resolves.
   `functions/src/mail/sender_factory.ts`: `getMailSender()` chooses by `MAIL_PROVIDER`
   (default `resend`), and throws at call time when `console` is selected on the production
   project or when `MAIL_FROM` or the key is empty.
4. `functions/src/mail/queue.ts`:
   - `enqueueMail(to: string | null, template, locale, vars)` adds a `mailQueue` document
     `{to, template, locale, vars, createdAt, expiresAt}` where both times are Firestore
     `Timestamp`s and `expiresAt` is now plus 1 hour. A null `to` is a deliberate dummy entry.
   - `processMailQueued(snapshot, sender: MailSender, wait = <a 1 second delay>)`, exported: for
     a null `to`, delete the document and return. Otherwise render, send, delete the document.
     On a `MailDeliveryError` whose status is 0, 429, or 500 and above, wait and try once more;
     on any other status do not retry. On final failure log
     `functions.logger.error('mail_delivery_failed', {template, status})` and update the
     document with `{to: FieldValue.delete(), vars: FieldValue.delete(), failedAt}` so neither
     the address nor a code stays at rest.
   - `onMailQueued = functions.runWith({secrets: ['MAIL_API_KEY']}).firestore
     .document('mailQueue/{id}').onCreate((snap) => processMailQueued(snap, getMailSender()))`.
   Export `onMailQueued` from `functions/src/index.ts` and add it to the exports test.
5. `functions/scripts/send_test_email.js --to <address> --template <verify|reset|passwordChanged>
   --locale <en|ru|kk>`: requires the built `lib/mail/*`, reads `MAIL_API_KEY`, `MAIL_FROM` and
   `MAIL_PROVIDER` from the environment, uses the code `123456`, and exits 1 when `--to` is
   missing. It needs `npm run build` first; say so in its usage text. Add the npm script
   `mail:test`.
6. Tests:
   - `functions/test/unit/mail_templates.test.ts`: for all 9 combinations the subject has no
     digit; for `verify` and `reset` both `html` and `text` contain the code and the validity
     line; no output contains `http`, `<img` or `<a `; the `html` has the right `lang`; a code
     of `<b>` is escaped; an unknown locale equals `en`.
   - `functions/test/unit/resend_sender.test.ts` with a fake `fetchImpl`: sends the expected
     URL, header and body; a 500 throws `MailDeliveryError` with status 500; a rejected fetch
     throws status 0.
   - `functions/test/emulator/mail_queue.test.ts`, calling `processMailQueued` directly with a
     fake sender and a zero delay: a queued document is sent and deleted; a null `to` is
     deleted without a send; two failures with status 500 leave the document without `to` and
     `vars`; a 422 is not retried.
7. Add `MAIL_FROM=`, `MAIL_PROVIDER=resend` to `functions/.env.example`. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`.

## Non-goals
- Do not write any auth callable (P1-02).
- Do not add `nodemailer` or any other package.
- Do not put links, images, a logo file or tracking into an email.
- Do not log a recipient address or a code.

## Constraints
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- Email text follows the copy rules: no exclamation marks, no long dashes, sentence case.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] The template test covers all 9 combinations.
- [ ] `grep -rn "console\." functions/src/mail` prints nothing.
- [ ] `grep -nP "[\x{2014}\x{2013}]" functions/src/mail/templates.ts` prints nothing, and the report states that no email text contains an exclamation mark.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Choose the provider and the sending domain, add the DNS records, store `MAIL_API_KEY`, then send test emails to a university inbox and a Gmail inbox (`docs/numer2/USER_ACTIONS.md` C-1, C-2).

## Deliverable
Branch `numer2/p1-01-email-module`, one commit, message `feat: add transactional email module` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The task message names a provider other than Resend and does not give its API shape.
