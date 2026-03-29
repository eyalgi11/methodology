# Observable Methodology Compliance

## Goal
- Methodology use should be visible during development, not only implied by background rules.
- If the workflow does not show the methodology, it is not being followed well enough.

## Required Visible Signals
- Before substantial work:
  - state the startup profile: `minimal`, `normal`, or `deep`
  - state the work type: `product`, `maintenance`, `infra`, `incident`, or `template_source`
  - state which methodology files were loaded
  - state the active task and lifecycle state
  - state the task workspace path for meaningful task work
  - for meaningful work, state whether execution is `multi-agent` or `single-agent by exception`
  - if execution is multi-agent, point to `MULTI_AGENT_PLAN.md` and the live claim path
  - state the relevant spec path for non-trivial work
  - state the intended verification path
  - for meaningful product work, state the business owner
  - for meaningful product work, state the target metric or expected movement
  - for meaningful product work, state the customer segment or problem signal
  - for meaningful product work, state the review date or decision date
  - for production-impacting work, state the release risk
  - prefer `methodology-state.json` as the first machine-readable startup surface when it exists
- During substantial work:
  - record progress checkpoints when direction changes or meaningful progress is made
  - keep top-level `SESSION_STATE.md` and `HANDOFF.md` compact as indexes
  - update the task workspace `STATE.md` and `HANDOFF.md` with current state and next step
  - keep `MULTI_AGENT_PLAN.md` and `ACTIVE_CLAIMS.md` visibly current if the task is running multi-agent
  - say which methodology files were updated
- Before calling work done:
  - state the task-state transition
  - state what verification was run
  - state which methodology files now reflect the new state
- If a methodology step is skipped:
  - record it in `PROCESS_EXCEPTIONS.md`
  - state who approved the exception and when it expires

## Standard Commands
- `begin-work.sh`
- `work-preflight.sh`
- `progress-checkpoint.sh`
- `observable-compliance-check.sh`

## Source Of Truth
- `TASKS.md`: lifecycle truth
- `WORK_INDEX.md`: active-workspace pointer truth
- `work/<task>/STATE.md`: execution truth
- `work/<task>/HANDOFF.md`: resume truth
- `ACTIVE_CLAIMS.md` plus `claims/<claim-id>.md` and `claims/<claim-id>.json`: ownership truth
- `LOCAL_ENV.md`: runtime truth
- `HOTFIX.md`: override truth during runtime stabilization

## Context Budgets
- `CORE_CONTEXT.md`: keep under 150 lines
- top-level `SESSION_STATE.md`: keep under 80 lines
- top-level `HANDOFF.md`: keep under 80 lines
- `WORK_INDEX.md`: keep under 50 active task entries
- `work/<task>/STATE.md`: keep under 200 lines
- `work/<task>/HANDOFF.md`: keep under 100 lines

## Rule
- Hidden methodology is weak methodology.
- Shared top-level continuity files are indexes; detailed in-flight state belongs in task workspaces and live claims.
- If meaningful work does not show a visible worker split plus live claims, treat it as single-agent work and record an explicit exception.
- If sources disagree, follow the source-of-truth hierarchy from `CORE_CONTEXT.md`.
