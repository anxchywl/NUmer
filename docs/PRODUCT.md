# Product

**NUmer** is a collaborative study-group and personal-productivity app for students. It
combines focus timers, habit tracking, course/goal management, and social study groups with
leaderboards into one offline-first dashboard, localized in English,
Russian, and Kazakh.

**Who it's for:** students building structured study routines, and study-group leaders who
want friendly, leaderboard-driven competition.

Each capability below maps to a feature folder under `lib/features/` (see
[AGENTS.md](../AGENTS.md) for the code layout). This file is the single source of truth for
*what the app does*; it deliberately avoids implementation detail (that lives in
[INFRASTRUCTURE.md](INFRASTRUCTURE.md)).

## Navigation
The bottom tabs are Home, Habits, Study, Groups and, only while a campus module is visible
to the user, Campus. Settings opens from the user's avatar in the header of every tab and
ends with About: privacy policy, support contact and app version.

## Capabilities

### Onboarding & profile — `auth`, `account`
Sign-up/sign-in with email verification and password reset by a 6-digit code, guided onboarding, and a
profile (avatar, name, major, study goals, accent color, preferred language).

### Courses & goals — `courses`
Create courses with weekly study-hour goals, credits, experience levels, and custom order.

### Focus timers & sessions — `sessions`
Three timer modes — count-up **stopwatch**, count-down **timer**, and **Pomodoro** (work +
short/long breaks with break pings). Sessions auto-save. A running session shows a live
iOS Live Activity / lock-screen recording notification with elapsed time.

### Habit tracker — `habits`
Custom habits with frequency rules (daily, weekly, specific days), swipe-to-complete
interactions, categories, archiving, an Eisenhower prioritization view, and
streak heatmaps/calendars.

### Connections — `connections` *(planned, currently hidden)*
Log touchpoints with classmates/friends: interaction dates, notes, custom tags, birthdays,
and follow-up reminders (e.g. nudge after 30 days without contact). The feature is fully
built under `lib/features/connections/` but intentionally not yet exposed in the app's
navigation — see the marker in `lib/app/shell/shell_tabs.dart`.

### Study groups & leaderboards — `groups`
Create/join public or private groups (private groups use secure join codes). Live
leaderboards compare study duration (today / 7-day / monthly) with real-time aggregates,
plus per-member subject breakdowns. Members can **nudge** each other with motivational push
notifications, phrased in the recipient's preferred language.

### AI insights — `ai_analysis`
Paused. The Home entry points open a screen saying course analysis is coming soon.

### Study — `study`
The study tab, which for now links to Statistics and History.

### Campus — `campus`
Lists the campus modules visible to the user; hidden while there are none. More than eight
modules add a search over their names and descriptions.

### Statistics — `stats`
Charts, calendars, and heatmaps visualizing study time and progress.

### History & export — `history`
Browse past sessions and export logs to `.ics` (calendar), `.csv`, or `.xlsx` (Excel).

### Home dashboard — `home`
The composed landing surface tying the above together.

## Cross-cutting product traits
- **Offline-first:** the app works fully without a connection; study groups are the only
  online-only area.
- **Localized:** every user-facing string is available in English, Russian, and Kazakh.
- **Notifications:** local reminders, recording notifications, and FCM push nudges.
- **Update required:** a build older than the supported minimum shows only a screen that
  links to its store page.

## Platforms
iOS, Android, and macOS. Live on the [App Store](https://apps.apple.com/kz/app/numer-app/id6759787785)
and [Google Play](https://play.google.com/store/apps/details?id=app.anx.numer) (version 1.0.3).
