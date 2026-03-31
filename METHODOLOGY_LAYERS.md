# Methodology Layers

This file explains which parts of the methodology are active by default and which parts are optional.

Use it when you want to know what is shaping agent behavior versus what merely exists in the toolkit.

## Core

These define the normal path and should stay small:
- `METHODOLOGY_PRINCIPLES.md`
- `DEFAULT_BEHAVIOR.md`
- `AGENTS.md`
- `CORE_CONTEXT.md`
- `WORK_INDEX.md`
- `TASKS.md`
- `SESSION_STATE.md`
- `HANDOFF.md`
- `methodology-state.json`
- `methodology-entry.sh`
- `work-preflight.sh`
- `verify-project.sh`

## Optional

These are real, but should only become active when the task needs them:
- `MULTI_AGENT_PLAN.md`
- `ACTIVE_CLAIMS.md`
- `claim-work.sh`
- `worker-context-pack.sh`
- `claim-diff-check.sh`
- `agent-merge-check.sh`
- `EXPERIMENTS.md`
- `EXPERIMENT_LOG.md`
- `release-cut.sh`
- `security-review.sh`
- `enter-hotfix.sh`
- `archive-cold-docs.sh`

## Advanced

These are for unusual or more mature operating needs:
- incident flows
- weekly reviews
- milestone refresh
- methodology scoring
- deeper adoption/backfill helpers
- archive retrieval and maintenance helpers

## Compatibility

These exist to support older repos or migrations and should not be mistaken for the preferred current layout:
- legacy `specs/...` feature-spec paths
- legacy root-layout migration helpers
- template upgrade helpers

## Reading Order

If you want the shortest control path:
1. `METHODOLOGY_PRINCIPLES.md`
2. `DEFAULT_BEHAVIOR.md`
3. `AGENTS.md`

Everything else should be read only when the task actually needs it.
