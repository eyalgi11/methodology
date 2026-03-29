# Core Context

This file is the compact session-start summary for the project.
Keep it under roughly 100-150 lines.

The agent should read `methodology-state.json` first when it exists, then this file, then `WORK_INDEX.md`, `TASKS.md`, `SESSION_STATE.md`, `HANDOFF.md`, and the active spec if one exists.

Other methodology docs should be loaded on demand, not by default.

## Source Of Truth Hierarchy
- `TASKS.md`: lifecycle truth
- `WORK_INDEX.md`: active-workspace pointer truth
- `work/<task>/STATE.md`: execution truth
- `work/<task>/HANDOFF.md`: resume truth
- `ACTIVE_CLAIMS.md` plus `claims/<claim-id>.md`: ownership truth
- `LOCAL_ENV.md`: runtime truth
- `HOTFIX.md`: temporary override truth while hotfix mode is active
