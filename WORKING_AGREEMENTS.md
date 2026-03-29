# Working Agreements

## Engineering Defaults
- Prefer the simplest design that can satisfy the current scope.
- Keep behavior explicit. Avoid hidden control flow and silent fallbacks.
- Make small, reviewable changes rather than broad speculative refactors.

## Coding Standards
- Follow existing project conventions before introducing new patterns.
- Keep modules focused and names specific.
- Add tests when behavior changes or risk justifies them.

## Delivery Rules
- Clarify scope before non-trivial implementation.
- Verify meaningful work before calling it done.
- Document important decisions and unresolved questions on disk.
- If a command is expected to be run repeatedly by the user or team, move it into a bash script under project-root `scripts/` and reference that script from `COMMANDS.md`.
- If work runs from a sudo/root shell, normalize ownership and edit permissions so project files remain editable from the normal non-sudo user shell.
- If real runtime usage breaks a finished slice, enter hotfix mode immediately and correct `TASKS.md`, `SESSION_STATE.md`, `HANDOFF.md`, and `HOTFIX.md` before resuming roadmap work.
- Treat generated runtime output directories like `dist`, `.next`, native build folders, and emulator assets as ownership-sensitive; they must not silently become non-editable for the normal project user.
- Use the local environment contract as real operating context, not optional notes.

## Operating Cadence
- Daily:
  - enter work through the methodology
  - keep task state, workspace state, and handoff current
  - end meaningful work with a clear next step and updated verification state
- Weekly:
  - review milestones, blockers, metrics, risks, incidents, and open questions
- Pre-release:
  - verify release notes, verification status, rollout/rollback plan, security posture, and dependency changes
- Post-incident:
  - close the incident with root cause, corrective action, and at least one durable learning update

## Learning Loop
- After incidents, regressions, or expensive rework, update a durable repo rule or decision.
- Prefer capturing the lesson in `ANTI_PATTERNS.md`, `WORKING_AGREEMENTS.md`, or `DECISIONS.md`.
- Do not leave important lessons trapped only in chat, handoff notes, or incident logs.

## Parallel Agent Coordination
- Default to multi-agent execution for all meaningful Codex work.
- Use `AGENT_TEAM.md` as the stable role model and `MULTI_AGENT_PLAN.md` to define the active lead ownership, worker slices, and merge order before substantial parallel work.
- When more than one agent is active, claim work in `ACTIVE_CLAIMS.md` before substantial edits.
- Keep file ownership disjoint whenever possible.
- Update or release claims when the working set changes materially.
