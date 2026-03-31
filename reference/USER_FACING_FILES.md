# User-Facing Files

This file explains which methodology files are primarily meant for the user to read, approve, or act on directly.

## Purpose

Not every methodology file is meant to be user-facing.

Some files are mainly for:
- agent continuity
- machine-readable state
- coordination
- internal checks

This file lists the files that should be treated as the main user-facing surfaces.

## Main User-Facing Files

- `PROJECT_BRIEF.md`
  - the highest-level project intent, business context, and success criteria
- `ROADMAP.md`
  - the current now / next / later direction
- `TASKS.md`
  - the active task list and lifecycle state
- `HANDOFF.md`
  - the short current summary of what was done, what remains, and what the next step is
- `MANUAL_CHECKS.md`
  - the manual QA steps the user can actually run
- `RELEASE_NOTES.md`
  - the user-visible or operator-visible changes over time
- `PROJECT_HEALTH.md`
  - the compact status view of momentum, risk, and current concerns
- `METRICS.md`
  - the important measures that define success or failure
- `DECISIONS.md`
  - the important decisions that a user may want to review or challenge

## Conditionally User-Facing Files

- `methodology/features/*.md`
  - feature specs are user-facing when the user explicitly wants to review or edit the spec
  - otherwise, they are implementation contracts and should be treated as read-only
- `HOTFIX.md`
  - user-facing during runtime stabilization or incident response
- `PROCESS_EXCEPTIONS.md`
  - user-facing when a deviation from the normal methodology needs explicit visibility
- `OPEN_QUESTIONS.md`
  - user-facing when unresolved decisions need user input
- `MILESTONES.md`
  - user-facing when delivery checkpoints matter to the user
- `INCIDENTS.md`
  - user-facing after regressions or outages

## Mostly Agent/Internal Files

These are usually not the first files a user should have to care about:

- `CORE_CONTEXT.md`
- `WORK_INDEX.md`
- `SESSION_STATE.md`
- `methodology-state.json`
- `ACTIVE_CLAIMS.md`
- `MULTI_AGENT_PLAN.md`
- `work/<task-slug>/...`
- `claims/<claim-id>.*`
- archive index files and registry files

They exist to keep the work recoverable and auditable, but they are not the main human control surfaces.

## Practical Rule

If the goal is to show the user what matters most, start with:
1. `PROJECT_BRIEF.md`
2. `ROADMAP.md`
3. `TASKS.md`
4. `HANDOFF.md`
5. `MANUAL_CHECKS.md` when manual verification is relevant

Everything else should be pulled in only when the situation needs it.
