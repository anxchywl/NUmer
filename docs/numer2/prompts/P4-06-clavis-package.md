# P4-06: Clavis package: `numer_ui`, token provider, booking callbacks

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** Clavis (`/Users/anx/Clavis`) @ `main`   **Depends on:** P3-02

## Goal
Make `piano_room_feature` mountable inside NUmer: NUmer's design language through
`numer_ui`, a fresh Firebase ID token on every request, a way to recover from an expired
session, and callbacks that let the host keep an "Upcoming" item for each booking.

## Read first
- `AGENTS.md` of this repo (binding), and NUmer `docs/numer2/DECISIONS.md` section F and
  D-42 (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `/Users/anx/numer_app/packages/numer_ui/MIGRATION.md` (whole file)
- `/Users/anx/numer_app/docs/DESIGN.md` sections 5.3, 5.4, 6, 7.2, 9 and 9.5
- `piano_room_feature/lib/piano_room_feature.dart` (128 lines),
  `lib/piano_room_remote.dart`, `lib/src/data/http_piano_room_repository.dart` (298),
  `lib/src/application/piano_room_controller.dart:160-227`,
  `lib/src/presentation/booking_sheet.dart` (239), `piano_room_widgets.dart:85-109`,
  `piano_room_screen.dart:590-657`
- `piano_room_app/lib/main.dart` (`resolveRemote`, lines 17-45 and 90-140),
  `scripts/verify.sh`, `.github/workflows/ci.yml:40-150`

## Context
- Line numbers are from Clavis `main` at `b4e08d6`. Find code by name if it moved.
- Today `HttpPianoRoomRepository` and `PianoRoomRemote` take `String accessToken`, sent as
  the bearer at `http_piano_room_repository.dart:96`. A 401 falls into `_failureOf` and
  becomes `PianoRoomFailureCode.unavailable` (`:155-158`).
- `studentId` is already a parameter of `PianoRoomRemote` and the session; NUmer passes the
  Firebase uid, which is the subject the backend keys bookings on (P2-04).
- The token contract (NUmer D-42), identical in every module:
  `typedef PianoRoomIdToken = Future<String> Function({bool forceRefresh});` is awaited for
  every request and never stored. On a 401 the repository calls `Future<bool> Function()
  onSessionExpired` once; on true it repeats the same request once (same body, same
  `Idempotency-Key`) with a new `idToken()`; on false, or a second 401, it throws
  `PianoRoomFailure(PianoRoomFailureCode.unavailable)` as today. It never calls
  `onSessionExpired` twice for one request.
- Booking callbacks (D-42): `void Function(PianoRoomBooking booking)? onBooked` after a
  successful `book`, and `void Function(String bookingId)? onReleased` after a successful
  `release`. Both run from `PianoRoomController._mutate` on success only, before `load()`.
- `DESIGN.md` 9.5 for Clavis: the nested `Navigator` stays (`piano_room_feature.dart:117-124`);
  the week switcher already uses icon buttons with tooltips (`piano_room_screen.dart:109-140`);
  a bookable slot's trailing chevron (`piano_room_screen.dart:644-649`) becomes a text button
  "Book" that opens the same `BookingSheet`; a successful booking gives
  `HapticFeedback.lightImpact()` once; `ScheduleSkeleton` (`piano_room_widgets.dart:91-109`)
  draws `NumerSkeleton(rows: 6)` instead of an empty `SizedBox`.
- `numer_ui` comes from the NUmer repository by git tag `numer-ui-v0.1.0` (D-42).
- The dev host seed for `NumerTheme.build` is `Colors.indigo`.
- No sheet in this package has a text field, so focus mode does not apply.
- New strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `bookSlot` | Book | Забронировать | Брондау |
  | `loadingHint` | Loading | Загрузка | Жүктелуде |

## Steps
1. `piano_room_feature/pubspec.yaml` and `piano_room_app/pubspec.yaml`: replace the `app_ui`
   path entry with the `numer_ui` git entry (`url: https://github.com/anxchywl/NUmer.git`,
   `path: packages/numer_ui`, `ref: numer-ui-v0.1.0`). In `piano_room_feature/pubspec.yaml`
   change `timezone: ^0.10.1` to `timezone: ^0.11.0`, the constraint NUmer uses
   (`/Users/anx/numer_app/pubspec.yaml:36`); otherwise NUmer cannot resolve both. Run
   `flutter pub get` in both.
2. Apply `MIGRATION.md` steps 1 to 4 to every Dart file under both packages' `lib` and
   `test`. The `AppPrimaryButton` of `booking_sheet.dart` that passes `isLoading` (line 208)
   also passes `loadingHint: s.loadingHint`. Before editing `piano_room_screen.dart` (657
   lines), move its slot row widget (the class around lines 590-657) into
   `lib/src/presentation/slot_row.dart` unchanged, then edit it there. Replace `AppTheme.lightTheme` and `.darkTheme` in
   `piano_room_app/lib/main.dart:96-97` with `NumerTheme.build(seed: Colors.indigo,
   brightness: ...)`.
3. Delete `app_ui/`. Remove it from `scripts/verify.sh:20`, from `.github/workflows/ci.yml:45`,
   `:121`, `:131`, `:137` and the line `(cd app_ui && flutter test --no-pub)` at `:143`.
4. Token provider: add `typedef PianoRoomIdToken` to `lib/src/domain/piano_room_repository.dart`
   and export it; also export `src/domain/piano_room_failure.dart` from
   `piano_room_feature.dart` so the host can name `PianoRoomFailure`. `HttpPianoRoomRepository` takes `required PianoRoomIdToken idToken` and
   `required Future<bool> Function() onSessionExpired` instead of `accessToken`; `_send`
   builds the request in a local function so it can send it a second time, awaits
   `idToken()` for the header each time, and applies the contract. `PianoRoomRemote` takes
   the same two parameters instead of `accessToken`; it still requires a non-empty
   `studentId` and keeps its HTTPS check.
5. Callbacks: `PianoRoomFeature` gains `this.onBooked` and `this.onReleased` (types in
   Context) and passes them to `PianoRoomController`. They are called outside the
   `try`/`finally` of `_mutate`, only when it returns true: `book` passes the booking it
   received to `onBooked`; `release` calls `onReleased(booking.id)` after `_mutate`
   returns true (its closure returns null, so `_mutate` cannot know the id). `didUpdateWidget` does not recreate the controller when
   only a callback changes.
6. UI per Context: the slot row's chevron becomes `AppTextButton(text: s.bookSlot,
   onPressed: book)` (keep the row's `InkWell`, `Semantics` and the not-eligible branch as
   they are); in `BookingSheet` after `success == true` for a new booking call
   `HapticFeedback.lightImpact()`; `ScheduleSkeleton` renders `NumerSkeleton(rows: 6)` with
   its `Semantics(liveRegion: true, label: loadingLabel)` kept.
7. `piano_room_app/lib/main.dart:35-40`: `PianoRoomRemote(baseUri: uri, idToken:
   ({forceRefresh = false}) async => accessToken, onSessionExpired: () async => false,
   studentId: studentId, allowInsecure: debug)`.
8. Strings: add the two keys to `lib/src/l10n/arb/app_{en,ru,kk}.arb`; run `flutter gen-l10n`.
9. Docs: replace `app_ui` with `numer_ui` (from the NUmer repository by git tag) in
   `AGENTS.md:3,8`, `README.md:70,76` and `docs/ARCHITECTURE.md:5,9,38`; drop the sentence
   about the Gradus fork commit.
10. Tests:
    - `test/data/http_piano_room_repository_test.dart` (extend): `idToken` is awaited once
      per request and is the bearer; a 401 with `onSessionExpired() == true` sends the
      request twice with the same `Idempotency-Key` and the second token, and calls
      `onSessionExpired` once; with `false` it throws `unavailable` after one request; two
      401s throw `unavailable` after two requests and one call.
    - `test/application/piano_room_controller_test.dart` (extend): a successful book calls
      `onBooked` once with the booking; a failed book (repository throws
      `PianoRoomFailure(conflict)`) calls nothing; a successful release calls `onReleased`
      with the id.
    - `test/presentation/piano_room_screen_test.dart` (extend): a bookable slot shows a
      "Book" text button that opens the booking sheet; a slot that is not eligible shows no
      button; the loading state shows `NumerSkeleton` (find it by type; it paints after 300 ms).
11. Run the `MIGRATION.md` step 6 grep, then `./scripts/verify.sh` and a debug build of
    `piano_room_app` (`flutter build apk --debug` in `piano_room_app`).

## Non-goals
- No backend change (P4-07). No NUmer code (P4-08).
- No change to the booking rules, the policy, the snapshot validator or the refresh timer.
- No new screens, no offline mode.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- UI: only names from `package:numer_ui/compat.dart`. No new colour, radius, text style, font or icon package. Every icon-only control has a tooltip.
- A loading button shows only its spinner and passes `loadingHint`. Every sheet or dialog with a text field uses focus mode (none exists here; a new one would).
- Every user-facing string is in the three ARB files; run `flutter gen-l10n`.
- The token is never written to disk, a log or a field that outlives one request.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Do not deploy, do not push, do not tag, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 with the feature coverage floor of 85.
- [ ] The `MIGRATION.md` step 6 grep prints only `AppColors.of` and `AppTextStyles.of` lines.
- [ ] `grep -rn "accessToken" piano_room_feature/lib` prints nothing; `app_ui/` is gone and `grep -rn "app_ui" .github scripts` prints nothing.
- [ ] The tests of step 10 exist and pass.
- [ ] `flutter build apk --debug` succeeds in `piano_room_app`.
- [ ] Screenshots from `piano_room_app` (sample backend): the week with free, own and taken slots, the booking sheet, the loading skeleton; light and dark, EN and RU.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` F-0 (the `numer-ui-v0.1.0` tag).
- After review: `git tag v0.2.0 && git push origin v0.2.0` in Clavis.

## Deliverable
Branch `numer2/p4-06-clavis-package`, one commit, message `feat: move clavis to numer_ui and a token provider` (subject line only). Do not push.
Report: files changed, verify output, the grep outputs, screenshots, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot resolve `numer_ui` at `numer-ui-v0.1.0`.
- A compat name the code uses is missing from `numer_ui` and not listed in `MIGRATION.md`.
- The repository's request path cannot be sent twice without changing its public behaviour.
