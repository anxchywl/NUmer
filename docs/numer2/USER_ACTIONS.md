# What only the owner can do

Everything in the plan that needs an account, a console, a device, a decision or the server.
Grouped by phase. Each item says what, why, the exact steps, and the task that waits on it.

No server address, key or secret belongs in this file or in any committed file. Server
details are in the private capacity file outside version control.

Executors never deploy, never push and never connect to the server. Wherever a step says
"deploy", it is yours.

## Before anything starts

### A-1 Answer the open questions
**Why:** eight decisions are yours (`DECISIONS.md` section G). **Waits:** the tasks named.

| # | Question | Default if you say nothing | Waits |
|---|---|---|---|
| O-1 | Tab layout: Home, Habits, Study, Groups, Campus, with Settings behind the avatar? | the layout in D-20 | P3-05 |
| O-2 | Email provider and sending domain | see B-1 | P1-01 |
| O-3 | Legal advice on data localization in Kazakhstan | nothing changes; the risk stays open | nothing |
| O-4 | Is the Events bot process meant to be running in production? | assumed yes | P2-06, P4-09 |
| O-5 | Did Gradus ship standalone with real user data? Does Clavis hold bookings under old student ids? | assumed no to both | P2-04, P4-05 |
| O-6 | Replace users' avatar glyphs with Material icons? | no | P5-05 |
| O-7 | Add crash reporting (a new SDK and one line in the privacy policy)? | yes | P0-14 |
| O-8 | Which Android device is the performance reference? | the oldest mid-range phone you own | P0-14 |

### A-2 See the real Firebase numbers
**Why:** the cost model rests on an assumed usage pattern. **Waits:** nothing blocks, but it
tells you whether P0-08 worked.
1. Firebase console, project `numer-60744`, Firestore, Usage tab.
2. Note reads, writes and deletes per day for the last 7 days.
3. Functions, each function: invocations per day.
4. Repeat one week after P0-08 and P0-09 are live.

### A-3 Set a billing alert
**Why:** an unmetered callable was open (`RESEARCH.md` 3.2, H3). **Waits:** P0-14 lists it.
1. Google Cloud console, Billing, Budgets and alerts.
2. Create a budget for project `numer-60744`: 10 USD per month, alerts at 50%, 90%, 100%.

---

## Phase 0: Foundation

### B-0 Remove the broken AI callable (P0-01). Do this first.
**Why:** the AI analysis feature has been calling a shut-down model since 2026-06-01. It is
paused behind a coming-soon screen until P5-07.
1. After P0-01 is merged: `firebase functions:delete analyzeCourseAi --project numer-60744`.
2. Optional: `firebase functions:secrets:destroy GEMINI_API_KEY --project numer-60744`, then
   revoke the key in Google AI Studio.
3. Ship the coming-soon screen with the next release (1.1.0).

### B-1 Review added translations (P0-02)
**Why:** RU was 15 keys short of EN and KK one short; the task adds them.
1. Read the list of added keys in the task's report.
2. Correct any that read unnaturally, in `lib/l10n/app_ru.arb` and `app_kk.arb`.

### B-2 Device smoke test (P0-03, P0-12, later P3-04)
**Why:** nothing in the repo exercises Hive, Firebase or the Android toolchain.
1. `flutter run --release` on one Android and one iOS device.
2. Go through the smoke list at the end of `PLAN.md`.
3. Report any step that fails before the next task starts.

### B-3 Deploy the membership index and profiles, then backfill (P0-05)
**Why:** the stage 1 rules read these collections; they must be full before the rules change.
1. `firebase deploy --only functions:onGroupMemberWrite,functions:onUserProfileWrite --project numer-60744`
2. `cd functions && node scripts/backfill_group_index.js --dry-run`, then without `--dry-run`.
3. `node scripts/backfill_public_profiles.js --dry-run`, then without.
4. In the console, check that `groupIndex` has one document per user who is in a group and
   `publicProfiles` one per user.
The scripts need a service account key on your machine
(`GOOGLE_APPLICATION_CREDENTIALS`). Do not commit it.

### B-4 Deploy rules stage 1 (P0-06)
**Why:** closes the critical findings. **Waits on:** B-3.
1. Save the current rules: Firestore, Rules, copy the text to a local file.
2. `firebase deploy --only firestore:rules --project numer-60744`
3. For the next 24 hours watch Firestore, Usage, "Denied" requests. A jump means an
   installed version is being refused something.
4. Rollback: paste the saved rules back in the console and publish.

### B-5 Deploy callable hardening and delete two functions (P0-07)
1. `firebase deploy --only functions --project numer-60744`
2. When the CLI asks about deleting `getMemberSubjectStats` and `deleteGroup`, answer yes.
3. Firestore console, TTL: add policies on `nudgeLimits.expiresAt`,
   `joinAttempts.expiresAt`, so the counters clean themselves up.

### B-6 Roll out incremental aggregates (P0-08)
**Why:** the new path must be proven equal to the old one on real data.
1. Deploy with `AGG_INCREMENTAL=off` and `AGG_SHADOW_PERCENT=5` (set in
   `functions/.env.numer-60744`).
2. For 3 days, search the function logs for `aggregate_shadow_mismatch`. There should be
   none.
3. Set `AGG_INCREMENTAL=on`, deploy again.
4. Rollback: set it back to `off` and deploy.

### B-7 Two-device sync check (P0-09)
1. Sign in to the same account on two devices.
2. Add a session on device A. On device B tap "Sync now" in Settings. The session appears.
3. Edit a course name on B. Leave A in the background for more than 10 minutes, then bring
   it to the foreground. The name changes without a manual sync.

### B-8 Create the flags document (P0-13)
1. Firestore console, create collection `config`, document `app`:
   `minSupportedBuild: 0` (number), `modules: {}` (map).
2. To test a module later, add under `modules`:
   `gradus: {enabled: true, rollout: 0, allow: ["<your uid>"], minBuild: 0}`.

### B-9 Crash reporting and baselines (P0-14)
1. If O-7 is yes: Firebase console, Crashlytics, enable for the Android and iOS apps.
2. On the reference device: `./scripts/measure_startup.sh` three times, take the median.
3. `./scripts/measure_size.sh`.
4. Write both numbers into `docs/PERFORMANCE.md`.

### B-10 Create the staging Firebase project (P0-15)
**Why:** auth, rules and email work must be tested somewhere that is not production.
1. Firebase console, add project `numer-staging`. Upgrade it to the Blaze plan (functions
   need it); set a 5 USD budget alert.
2. Enable Authentication with Email and Password; create Firestore in the same location as
   production.
3. Register an Android app and an iOS app with the same package name and bundle id as
   production.
4. Give the executor of P0-15 the project id, the two app ids, the two API keys, the sender
   id and the storage bucket. These are not secrets, but pass them as build defines, not
   committed text.
5. Enable App Check for both apps and register a debug token for your own device.

### B-11 Console checks that need no task
**Why:** the security review could not see the console (`RESEARCH.md` 3.3 and 14).
1. Authentication, Settings, User actions: turn on "Email enumeration protection".
2. Authentication, Settings, Password policy: minimum length 8, mode "Require enforcement".
3. Google Cloud console, APIs and Services, Credentials: for the Android key restrict to the
   Android app (package name and SHA-1); for the iOS key restrict to the iOS bundle id. For
   both, restrict APIs to Identity Toolkit, Token Service, Cloud Firestore, Firebase
   Installations, Firebase Cloud Messaging, Firebase App Check, Cloud Functions.
4. App Check: confirm both apps are registered (Play Integrity, and App Attest or
   DeviceCheck). Open the metrics for Cloud Functions and note the share of verified
   requests. You will need it for D-1.
5. Check the iOS bundle id in the Firebase project against the real one; the repo has a
   placeholder in `lib/core/firebase_options.dart:54`.

---

## Phase 1: Auth rework

### C-1 Email provider, domain and DNS (P1-01)
**Why:** codes must arrive, and arrive in the university's inboxes.
1. Choose the sending domain. If NUmer has no domain of its own, use a subdomain of one you
   own, for example `mail.<your domain>`.
2. Create an account with a transactional email provider that has an HTTPS API. The prompt
   implements the Resend API; any other provider needs a 40-line adapter. Confirm the free
   tier covers at least 100 emails a day before relying on it.
3. Add the domain at the provider and create the DNS records it shows: SPF (TXT), DKIM
   (CNAME or TXT), and a DMARC record `v=DMARC1; p=quarantine; rua=mailto:<your address>`.
4. Wait until the provider shows the domain as verified.
5. Store the API key as a function secret:
   `firebase functions:secrets:set MAIL_API_KEY --project numer-staging`, then the same for
   `numer-60744`.
6. Decide the From name and address, for example `NUmer <no-reply@mail.<your domain>>`.

### C-2 Delivery test to the university (P1-01)
1. `node functions/scripts/send_test_email.js --to <you>@nu.edu.kz --locale ru --template verify`
2. Repeat for a Gmail address and for `--locale kk` and `en`.
3. Check: inbox, not junk; Cyrillic and Kazakh letters render; the code is readable in dark
   mode on a phone.
4. If the university mail puts it in junk, ask its IT desk to allow the sending domain, and
   do not release until it lands in the inbox.

### C-3 Secrets and TTL policies (P1-02)
1. `openssl rand -base64 32 | firebase functions:secrets:set AUTH_CODE_SECRET --project numer-staging`
   and again for `numer-60744` with a different value.
2. Firestore console, TTL: add policies on `authCodes.ttlAt` (not `expiresAt`: a code's
   reset ticket outlives its code), `authRateLimits.expiresAt`, `mailQueue.expiresAt`,
   `authAudit.expiresAt`.
3. Deploy to staging first:
   `./scripts/deploy_staging.sh`.

### C-4 Try the flows on staging (P1-04, P1-05)
1. Build with `APP_ENV=staging`. Sign up with a real inbox, enter the code.
2. Enter a wrong code five times; request a new one.
3. Reset the password; confirm other signed-in devices are signed out within an hour.

### C-5 Release 1.2.0 and keep Firebase's link emails on
**Why:** installed versions still use the link emails.
1. Do not edit or disable the email templates in Authentication, Templates.
2. Release 1.2.0 to both stores.

### C-6 Delete a test account (P1-07)
1. On staging: create an account, join a group, add sessions and habits, send a nudge.
2. Delete the account in the app.
3. In the console search for the uid: there must be no document under `users`,
   `publicProfiles`, `groupIndex`, `email_index`, `nudges`, or any group.
4. Firestore console, TTL: add a policy on `deletedUsers.expiresAt`.

### C-7 Adoption check, reminder, then rules stage 2 (P1-08)
**Why:** stage 2 degrades versions older than 1.2.0.
1. App Store Connect and Play Console: share of active devices on 1.2.0 or later.
2. Below 90%: send an update reminder. The task ships
   `functions/scripts/send_update_reminder.js`, which sends one push to users whose last
   seen build is older. Run it once with `--dry-run`, then for real. Wait a week.
3. At 90% or more: `firebase deploy --only firestore:rules`.
4. `node functions/scripts/delete_email_index.js --dry-run`, then for real.
5. Set `DELETE_REQUIRES_RECENT_AUTH=on`, deploy functions.
6. Set `minSupportedBuild` in `config/app` to the 1.2.0 build number.

### C-8 App Check enforcement, one callable at a time (P1-09)
1. App Check metrics for Cloud Functions: verified share at least 95% for 7 days.
2. Add the callable's name to `APPCHECK_ENFORCED`, deploy, watch errors for a day.
3. Repeat for the next callable.

### C-9 Privacy policy (P1-10)
Read the draft. It must name the email provider, push tokens and, if O-7 is
yes, crash reports. Publish it where the store listings point.

---

## Phase 2: Identity and infrastructure

Every step here touches the shared server. Nothing is applied without your decision, and you
run the commands.

### D-1 Tag the identity library (P2-01)
1. Review the pull request.
2. `git tag identity-v0.1.0 && git push origin identity-v0.1.0`

### D-2 First admin (P2-02)
1. `cd functions && node scripts/set_roles.js --uid <your uid> --roles numer:admin,numer:editor`
2. Sign out and in again in the app so the token carries the claim.

### D-3 Redeploy the four module backends (P2-03 to P2-06). Approval needed.
For each module, in the order Gradus, Clavis, Muto, Events:
1. Take a fresh backup with the module's own backup command and copy it off the server.
2. In the module's production env file set `AUTH_ADAPTER=firebase` and
   `FIREBASE_PROJECT_ID=numer-60744` (Events: `FIREBASE_AUTH_ENABLED=true`).
3. Deploy with the module's own deploy workflow.
4. Check `/health/ready` from outside.
5. Rollback: set the adapter back and redeploy the previous tag. The old adapters stay in
   the code for one release.

Before Events: answer O-4. Before Clavis: answer O-5 (run the read-only count the task
provides).

### D-4 One secret per module for account events (P2-07)
1. For each of clavis, events, muto: `openssl rand -hex 32`.
2. Put it in the module's env file as `ACCOUNT_EVENTS_SECRET` and in Firebase as
   `firebase functions:secrets:set ACCOUNT_EVENTS_SECRET_<MODULE>`.
3. After review, push the library tag `identity-v0.2.0` (it adds the signature check the
   module handlers use).
4. When the first module handler is deployed, set `ACCOUNT_EVENT_TARGETS` in
   `functions/.env.numer-60744` to a JSON list with that module's name and its
   `/internal/v1/account-events` URL, and deploy functions. The file is not committed.

### D-5 Install the restore test (P2-08). Approval needed.
1. Copy `infra/backup/` to the server.
2. Run `restore-test.sh` once by hand for each of muto, events_bot, clavis. Read the log
   line: it must say `result=PASS`.
3. Add the weekly timer from `infra/backup/README.md`. Pick an hour when nothing else runs.
4. If a module fails: its backups are not restorable today. That is the most important
   finding of this whole phase; fix it before anything else.

### D-6 Monitor and heartbeat (P2-10). Approval needed.
1. Choose where alerts go (a Telegram bot chat or any webhook that accepts JSON).
2. Create a check at an outside heartbeat service; copy its ping URL.
3. Fill `infra/monitor/monitor.env` on the server (mode 600), start the monitor project,
   stop the old Muto monitor.
4. Test: stop one module API for 4 minutes; an alert and then a recovery message arrive.

### D-7 Host hardening (P2-11). Approval needed.
1. Run `infra/host/audit.sh` and read its report.
2. Run `infra/host/harden.sh` with no arguments: it prints what it would change.
3. Apply one step at a time with `--apply <step>`, keeping a second SSH session open in case
   the first is cut off.
4. The Docker log-rotation step restarts the Docker daemon and with it every project on the
   server. Do it in a quiet hour.

### D-8 Findings on the server that are not part of NUmer
The audit found a few things in projects that are not NUmer modules. They are yours to
handle or ignore, and they are listed only in the private capacity file.

### D-9 If you ever shut down the project that owns the reverse proxy (P2-13)
Do P2-13 first. Every NUmer module is served through that proxy.

---

## Phase 3: Shell

### E-1 Confirm the navigation (O-1). **Waits:** P3-05.
### E-2 Support address and privacy URL for the About section. **Waits:** P3-05.
### E-3 Scheduler and first editor (P3-08)
1. Deploying the scheduled function creates a Cloud Scheduler job. The plan uses three in
   total (feed, account-event retries, the deleted-user sweep), which is the number that is
   free per billing account; check the current allowance before adding a fourth.
2. Give your account `numer:editor` (D-2).
3. Publish a test announcement with the script the task provides; see it on Home.
### E-4 Review the design pass (P3-12)
Look at the before and after screenshots of every changed screen in both modes.
### E-5 Store listing for 2.0.0
New screenshots and a description that mentions the new layout.

---

## Phase 4: Modules

### F-1 Tag each module package when its task is reviewed (P4-01, P4-06, P4-10, P4-13).
### F-2 Open each flag in three steps
1. `allow: [your uid]`. Use the module for a few days.
2. `rollout: 10`, then 50, then 100, a few days apart, watching crash reports and the
   server's memory (`free -h`, `docker stats --no-stream`) at each step.
3. If memory triggers fire (private capacity file), stop and decide before going on.
### F-3 Redeploy Clavis, Events and Muto with their account events handlers. Approval needed.
### F-4 Events: link your own Telegram account in the app and confirm your events appear.
### F-5 Muto storage
Confirm the S3-compatible bucket, its credentials and its CORS are in Muto's env file;
production refuses to start without them.
### F-6 Muto before App Review (P4-15)
1. Decide who answers reports and within what time; 24 hours is the usual promise.
2. Publish a contact address for content complaints.
3. Write the App Review notes: how to report, how to block, a test account.
4. Update the age rating answers for user-generated content in both stores.

---

## Phase 5 and 6

### G-1 Deletion drill (P5-02)
Delete a real test account in production and confirm each module removed its data.
### G-2 Decide O-6 (avatar glyphs).
### G-3 Approve the final privacy policy (P6-06).

---

## Standing duties after launch

- Read the monitor's alerts. A restore test older than 8 days is an alert.
- Once a month: restore one backup from the offsite copy with the offline key.
- Watch for the retirement of the AI models: `gemini-3.1-flash-lite` (used by Gradus) is
  listed for shutdown on 2027-05-07.
- Rotate `AUTH_CODE_SECRET` once a year (the code documents store a key version).
