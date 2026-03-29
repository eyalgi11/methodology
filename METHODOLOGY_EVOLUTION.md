# Methodology Evolution Loop

## Purpose
- This project should improve the way it works when real execution reveals recurring friction, ambiguity, or missing automation.
- The goal is not endless process growth. The goal is a tighter operating system built from real usage.

## Evolution Loop
1. Build real project work.
2. Notice friction, failure, repetition, or noisy checks.
3. Decide whether the issue is local to this project or general across projects.
4. If local, fix it in the project.
5. If cross-project, improve the global methodology with the smallest useful change.
6. Update both documentation and automation when the operating model changes.
7. Verify the new behavior on a real or disposable repo before treating the methodology change as complete.

## Promotion Rules
- Promote a lesson into the global methodology only when it is likely to recur across projects.
- Keep project-specific preferences, stack quirks, and one-off exceptions local unless they clearly generalize.
- Prefer adding signal over adding ceremony.
- Prefer changing an existing rule or script before creating a brand new artifact.

## Signals That Warrant Global Improvement
- A recurring cross-project blocker or ambiguity
- A repeated handoff or continuity failure
- A noisy check that creates more distraction than value
- A missing automation step that agents keep doing manually
- A repeated quality or verification failure that should become a guardrail

## Signals That Should Stay Local
- Repo-specific conventions
- Framework-specific preferences that are not common enough yet
- Temporary project constraints
- One-off toolchain workarounds

## Change Standard
- Keep the change small.
- Keep it verifiable.
- Keep it documented.
- Keep it general.
