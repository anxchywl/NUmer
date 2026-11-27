# NUmer 2.0 status

Updated 2026-11-27. "Done" means written, independently reviewed, fixed and merged into local
`main`. Nothing is live for users until it is deployed (functions, rules, module backends) or
released (app). Task details are in `PLAN.md`; your own steps are in `USER_ACTIONS.md`.

**Total: 46 done, 2 in progress, 41 to do (89 tasks; P4-05 dropped). Staging deployed 2026-11-27.**

Status: ✅ done, 🔄 in progress, ⏳ to do, ➖ dropped

Rule since 2026-11-27: source files stay under 400 lines (`AGENTS.md` "Size"); 33 older files may only shrink.

## Phase 0: Foundation (16 of 16 done)

Fix what is broken or risky in today's app before building on it. Ends in release 1.1.0.

| | Task | In plain words |
|---|---|---|
| ✅ | P0-01 Pause AI analysis | The broken AI screen now says "coming soon"; the dead AI code is gone |
| ✅ | P0-02 Verify script and CI | One command (`verify.sh`) checks every change; GitHub runs it on each PR |
| ✅ | P0-03 SDK and Android toolchain | Project settings match the Flutter version; Android build tools updated |
| ✅ | P0-04 Split functions | The 1,200-line Cloud Functions file is split by area, with tests |
| ✅ | P0-05 Membership index and public profiles | The server keeps a safe list of who is in which group and a public profile per user |
| ✅ | P0-06 Firestore rules stage 1 | Closes the critical holes: no more public user list, emails or group takeover |
| ✅ | P0-07 Harden callables | Server functions check their inputs, limit join-code guessing and nudges |
| ✅ | P0-08 Incremental aggregates | A study session costs about 3 database reads instead of about 111 |
| ✅ | P0-09 Sync push and pull | The app pushes changes right away and pulls less often; no stale overwrites |
| ✅ | P0-10 Redundant writes | Startup stops rewriting data that did not change |
| ✅ | P0-11 Groups read public profiles | Groups show peers from the safe public profiles, not private user docs |
| ✅ | P0-12 Split `main.dart` | The 1,171-line app entry file is split into clear parts |
| ✅ | P0-13 Feature flags and min build | Modules can be switched on remotely; very old app versions can be asked to update |
| ✅ | P0-14 Observability | Crash reporting and baselines for startup time and app size |
| ✅ | P0-15 Staging project | A safe copy of the backend to test deploys before production |
| ✅ | P0-16 Docs after foundation | Update `AGENTS.md` and the infrastructure doc |

## Phase 1: Sign-in rework (7 of 10 done)

Email verification and password reset by 6-digit code in a branded email. Ends in release 1.2.0.

| | Task | In plain words |
|---|---|---|
| ✅ | P1-01 Email module | The server can send branded emails in EN, RU and KK through Resend |
| ✅ | P1-02 Email-code callables | The server side of the codes: create, send, check, limits, security |
| ✅ | P1-03 Design tokens and code field | Shared colors, spacing and the 6-box code input (paste and autofill work) |
| ✅ | P1-04 Verify email by code | New users type the code from the email instead of tapping a link |
| ✅ | P1-05 Reset password by code | Forgot password: email, code, new password, all inside the app |
| ✅ | P1-06 Retire `email_index` | Remove the old, unsafe email lookup from the app |
| ✅ | P1-07 Account deletion | Deleting an account removes everything it owns (App Store rule) |
| ⏳ | P1-08 Rules stage 2 | Close the last exposure once most users run the new version |
| ✅ | P1-09 App Check switch | App Check can be turned on per server function without a code change |
| ⏳ | P1-10 Docs after auth | Docs describe the new sign-in, email and deletion |

## Phase 2: Identity and infrastructure (12 of 13 done)

The campus modules accept a NUmer sign-in; the server gets backups that are proven to restore.

| | Task | In plain words |
|---|---|---|
| ✅ | P2-01 Identity library | One shared Python library that checks a NUmer sign-in token |
| ✅ | P2-02 Module roles | You can make someone an admin of a module (stored on their account) |
| ✅ | P2-03 Gradus adapter | Gradus backend accepts NUmer sign-in |
| ✅ | P2-04 Clavis adapter | Piano room backend accepts NUmer sign-in |
| ✅ | P2-05 Muto adapter | Marketplace backend accepts NUmer sign-in; profiles no longer get wiped |
| ✅ | P2-06 Events bridge | Events backend accepts NUmer sign-in |
| ✅ | P2-07 Account events | A deleted NUmer account is also deleted in every module |
| ✅ | P2-08 Restore tests | A script proves each module's latest backup can be restored |
| ✅ | P2-09 Muto restore fix | Muto's restore script pointed at a service that did not exist |
| ✅ | P2-10 Monitor | One small checker watches all module APIs and backups |
| ✅ | P2-11 Server hardening | Audit and hardening scripts plus a runbook (nothing run on the server yet) |
| ✅ | P2-12 Docs after identity | The infrastructure doc describes backends, identity and backups |
| ⏳ | P2-13 Proxy and limits (optional) | Plan for moving the reverse proxy out of another project |

## Phase 3: Superapp shell (11 of 18; all prompts written)

The new app layout: tabs Home, Habits, Study, Groups, Campus; Settings behind your avatar.

| | Task | In plain words |
|---|---|---|
| ✅ | P3-01 Theme and components | Shared buttons, rows, sheets built on the design tokens |
| ✅ | P3-02 Compatibility layer | Lets module code use the shared design without rewrites |
| ✅ | P3-03 Module registry | One list of modules; each loads only when opened |
| ✅ | P3-04 Split `home.dart` | Break up the 3,098-line home screen (no visible change) |
| ✅ | P3-05 New shell | The new tabs, avatar menu, Settings and About screens |
| ✅ | P3-06 Study tab | Courses with timer, statistics, history, GPA in one place |
| 🔄 | P3-07 Home today | Home shows streak, running session, today, upcoming, news |
| ✅ | P3-08 Feed backend | Announcements plus events combined into one cheap feed document |
| ⏳ | P3-09 News on Home | The news list on Home and its own screen |
| ⏳ | P3-10 Upcoming store | Bookings and reminders shown on Home without loading modules |
| ✅ | P3-11 Campus tab | The list of campus modules |
| 🔄 | P3-12 Design pass | Remove glass, gradients, chips and raw toasts per the design rules |
| ⏳ | P3-13 Docs after shell | Docs describe the new layout |
| ✅ | P3-14 Split `stats.dart` | Break the 3,228-line statistics screen into small files (no visible change) |
| ✅ | P3-15 Split `add_habit_sheet.dart` | Break the 2,462-line add-habit sheet into small files |
| ✅ | P3-16 Split `habits_screen.dart` | Break the 1,610-line habits screen into small files |
| ⏳ | P3-17 States pass | Confirmations become bottom sheets; loading spinners become quiet placeholders |
| ⏳ | P3-18 Focus mode everywhere | While typing in any sheet, only the field and a Done button stay on screen |

## Phase 4: Module integration (0 of 19; all prompts written)

Gradus, Clavis, Events and Muto appear inside NUmer, each behind a feature flag.

| | Task | In plain words |
|---|---|---|
| ⏳ | P4-01 Gradus package | Gradus uses NUmer's design and sign-in |
| ⏳ | P4-02 Grades storage | Grades saved in NUmer's local database and Firestore |
| ⏳ | P4-03 Grades sync | Grades sync between devices |
| ⏳ | P4-04 Mount Gradus | GPA appears in the Study tab |
| ➖ | P4-05 Gradus import | Dropped: no old Gradus data (O-5) |
| ⏳ | P4-06 Clavis package | Piano room uses NUmer's design and sign-in |
| ⏳ | P4-07 Clavis account events | Piano room deletes data when a NUmer account is deleted |
| ⏳ | P4-08 Mount Clavis | Piano room in Campus, bookings in Upcoming |
| ⏳ | P4-09 Events Telegram link | Link your Telegram account to NUmer for Events |
| ⏳ | P4-10 Events package | Events uses NUmer's design and sign-in |
| ⏳ | P4-16 Events strings | Events speaks English, Russian and Kazakh |
| ⏳ | P4-17 Events tabs and filters | Events fits inside NUmer: tabs, filter rows, reminders |
| ⏳ | P4-18 Events account events | Events deletes data when a NUmer account is deleted |
| ⏳ | P4-11 Mount Events | Events in Campus, with Telegram link and reminders |
| ⏳ | P4-12 Muto moderation | Block user, moderation, text filter (needed for App Review) |
| ⏳ | P4-19 Muto account events | Marketplace deletes data when a NUmer account is deleted |
| ⏳ | P4-13 Muto package | Marketplace uses NUmer's design and sign-in |
| ⏳ | P4-20 Muto block and report | Block, report and moderation buttons in the marketplace |
| ⏳ | P4-14 Mount Muto | Marketplace in Campus |
| ⏳ | P4-15 App Review readiness | Review notes and contact details for user content |

## Phase 5: Polish (0 of 7)

| | Task | In plain words |
|---|---|---|
| ⏳ | P5-01 Notifications | Tapping a notification opens the right screen; per-category settings |
| ⏳ | P5-02 Deletion drill | End-to-end test that deleting an account clears every module |
| ⏳ | P5-03 Campus search | Search across campus modules |
| ⏳ | P5-04 Peer stats privacy | Group stats come from summaries; sessions become owner-only |
| ⏳ | P5-05 Avatar icons (optional) | Skipped (you chose to keep glyphs, O-6) |
| ⏳ | P5-06 Budgets in CI | CI fails if startup time or app size grows too much |
| ⏳ | P5-07 Bring back AI analysis | Course analysis returns, built safely |

## Phase 6: Developer docs (0 of 6)

| | Task | In plain words |
|---|---|---|
| ⏳ | P6-01 `AGENTS.md` | Agent rules for the superapp |
| ⏳ | P6-02 `README.md` | Project readme |
| ⏳ | P6-03 `docs/PRODUCT.md` | What the app does |
| ⏳ | P6-04 `docs/INFRASTRUCTURE.md` | How it runs and deploys |
| ⏳ | P6-05 Module `AGENTS.md` | Align each module repo's agent rules |
| ⏳ | P6-06 Privacy policy | Update the privacy policy (you approve) |

## Releases and deploys (not started)

Nothing above reaches users until these happen, in order, with you:
1. Deploy phase 0 server changes to staging (done 2026-11-27; owner signed up with a code on an S23, it works), then production (`USER_ACTIONS.md` B-3 to B-6)
2. Release app 1.1.0 (phase 0)
3. Deploy phase 1 server changes; release app 1.2.0 (sign-in by code)
4. Redeploy the four module backends with NUmer sign-in (needs your approval)
