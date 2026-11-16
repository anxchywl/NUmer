# Execution prompt template

Every task in `../PLAN.md` gets one prompt in this shape. Phases 0 to 2 already have theirs.
The outlines for phases 3 to 6 are expanded into this shape when their phase starts, by
reading the code as it is then.

Rules for whoever writes a prompt:

- It is self-contained. An executor with no other context must be able to finish it.
- Imperative English. Exact paths, commands and checks. No adjective where a check would do.
- Cite files and lines that exist at the time of writing. Open them first.
- Every step can be verified. Never "improve", "clean up", "make it nice", "as appropriate".
- UI prompts quote the token names and values from `../DESIGN.md` and give every new string
  in EN, RU and KK.
- One task is one pull request that a mid-tier model finishes in one session.

```markdown
# <TASK-ID>: <title>

**Recommended model:** sonnet | opus | haiku   **Effort:** low | medium | high
**Risk:** low | med | high   **Est.:** <hours>
**Repo / working dir:** <repo> @ <base branch>   **Depends on:** <task ids or none>

## Goal
One or two sentences: the outcome, and why it matters for NUmer 2.0.

## Read first
- `AGENTS.md` (binding rules and code conventions), `docs/numer2/DESIGN.md` sections <n>
  (for UI work), and: <exact paths, line ranges if large>

## Context
Only the facts the executor needs: current behaviour, relevant decisions, constraints.
Exact names of classes, functions, collections, env vars. No history, no alternatives.

## Steps
1. <concrete step with file path>
2. ...

## Non-goals
- Related-looking things that must NOT be changed in this task.

## Constraints
- Offline-first contract; never write Firestore from UI.
- Never renumber Hive typeIds or reorder fields; new types get new ids.
- All user-facing strings in EN/RU/KK ARB files, following the copy rules in DESIGN.md.
- No secrets in code or `--dart-define`; dev mechanisms refused when `APP_ENV=production`.
- UI: only DESIGN.md tokens and components; no new colors, radii, icon packages or fonts.
- Code conventions from `AGENTS.md`. Comments only for non-obvious *why*: lowercase, no
  trailing punctuation, one line.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, update them in the same
  commit.
- <task-specific constraints>

## Acceptance criteria
- [ ] `<exact command>` passes (`./scripts/verify.sh`)
- [ ] <observable, testable behaviour>
- [ ] <test added at exact path covering exact case>
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code
- [ ] Docs touched by this change are updated (or "none affected" stated in the report)
- [ ] UI tasks: screenshots in light and dark mode, in EN and RU, attached to the report

## User actions
- What only the user can do for this task, with exact steps.

## Deliverable
Branch `numer2/<task-id>-<slug>`, one commit, short subject-line-only message. Do not push.
Report: files changed, test output, screenshots for UI, user actions still pending.

## Stop and ask if
- <conditions where the executor must stop instead of guessing>
```
