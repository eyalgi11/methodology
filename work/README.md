# Workspaces

Detailed live task state should live here, one folder per task:

- `work/<task-slug>/TASK.json`
- `work/<task-slug>/SPRINT_CONTRACT.md`
- `work/<task-slug>/STATE.md`
- `work/<task-slug>/HANDOFF.md`

Keep repo-level `SESSION_STATE.md` and `HANDOFF.md` as compact indexes and summaries.
Treat `TASK.json` as the canonical task metadata source for spec/state/risk/release fields when it exists.
Use `SPRINT_CONTRACT.md` to define the next implementation chunk, evaluator test plan, pass thresholds, and failure conditions before substantial coding starts.

Recommended budgets:
- `STATE.md`: keep under 200 lines
- `HANDOFF.md`: keep under 100 lines
