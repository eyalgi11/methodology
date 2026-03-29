# Project Agent Instructions

This repository is methodology-managed.

## Entry Rule
- When a user starts new work, says `start with the methodology`, asks to begin from scratch, or resumes after a break, do not answer with generic methodology advice first.
- First enter the project operationally:
  - run `/home/eyal/system-docs/methodology/methodology-entry.sh .` or perform its equivalent steps
  - read `methodology/methodology-state.json` first when it exists
  - run `/home/eyal/system-docs/methodology/work-preflight.sh .` before substantial implementation when you need one short readiness/remediation summary
  - choose a startup profile: `minimal`, `normal`, or `deep`
  - read `methodology/CORE_CONTEXT.md`, `methodology/TASKS.md`, `methodology/SESSION_STATE.md`, and `methodology/HANDOFF.md` first
- use `methodology/WORK_INDEX.md` to find the active task workspace before loading detailed in-flight state
- treat `methodology/work/<task-slug>/TASK.json` as the canonical task metadata source for active-task spec/state/risk/release fields when it exists
- for non-trivial implementation chunks, create or refresh `methodology/work/<task-slug>/SPRINT_CONTRACT.md` before substantial coding so the next slice has explicit scope, evaluator checks, thresholds, and failure conditions
  - load `methodology/PROJECT_BRIEF.md`, `methodology/ROADMAP.md`, `methodology/DECISIONS.md`, `methodology/COMMANDS.md`, `methodology/LOCAL_ENV.md`, `methodology/REPO_MAP.md`, `methodology/HOTFIX.md`, `methodology/MANUAL_CHECKS.md`, `methodology/DOCS_ARCHIVE.md`, and other docs only when the task requires them
  - identify the active task, task state, and relevant spec from disk
- After that, continue inside the project files rather than inventing a fresh generic process.
- Treat `PROJECT_BRIEF.md` as a business + product brief, not only an engineering brief.
- Set `## Work Type` in `PROJECT_BRIEF.md` to `product`, `maintenance`, `infra`, `incident`, or `template_source` so business-required fields and checks match the actual work.
- Treat non-trivial feature specs as release-aware and impact-aware.
- Keep the feature-spec template source at `methodology/templates/FEATURE_SPEC_TEMPLATE.md`.
- New methodology-managed feature specs should live under `methodology/features/`. Legacy root `specs/...` feature-spec links remain supported for older repos, but they are no longer the default destination for generated feature specs.
- For non-trivial web UI, mobile UI, or other user-facing design work, use Stitch MCP to generate or refine the design basis before implementation unless the change is a trivial tweak or the existing design system already constrains the solution tightly.
- Record the Stitch design basis in the feature spec with the prompt or direction used, the resulting screen reference, and any intentional deviations.
- For hypothesis-driven work, use `EXPERIMENTS.md` and `EXPERIMENT_LOG.md` as the bounded experimentation layer.
- Do not treat experimental winners as durable product decisions until they beat baseline and are logged explicitly.
- For experiment-driven work, do not start until hypothesis, baseline, success threshold, time-to-signal, and stop rule are explicit.
- For experiment-driven work, do not treat the result as durable until the keep / discard / inconclusive decision is logged.

## Multi-Agent Default
- Default to multi-agent execution for all meaningful Codex work.
- If `AGENT_TEAM.md` sets `Delegation policy: single_agent_by_platform_policy`, do not treat single-agent execution as a methodology failure unless the user explicitly asked for delegation or sub-agents.
- Default to a second pair of eyes for meaningful work; use full multi-agent decomposition when work is parallelizable, cross-stack, risky, or time-sensitive.
- Separate generation from evaluation when practical: the agent building the work should not be the only agent judging whether the sprint met its contract.
- Choose the harness level deliberately:
  - `light harness` for trivial or tightly bounded work
  - `standard harness` for normal non-trivial work
  - `heavy harness` only for long-running, risky, search-heavy, or highly subjective work
- Do not assume every task needs a heavy 3-agent harness, 5-15 iterations, or multi-hour autonomous loops.
- Trivial tasks may stay single-agent without being treated as a methodology failure.
- Use `AGENT_TEAM.md` as the repo's stable startup-role model.
- At minimum, every meaningful task should use one Lead and one complementary agent.
- Keep one lead agent on the critical path and use additional agents for bounded exploration, implementation, verification, review, or ops work.
- Before substantial parallel work, update `MULTI_AGENT_PLAN.md` and `ACTIVE_CLAIMS.md`.
- If meaningful work does not show a visible worker split in `MULTI_AGENT_PLAN.md` plus live claims in `ACTIVE_CLAIMS.md`, treat it as single-agent work and record the exception in `PROCESS_EXCEPTIONS.md`.
- Keep shared top-level continuity files compact; put detailed in-flight state in `methodology/work/<task-slug>/STATE.md` and `methodology/work/<task-slug>/HANDOFF.md`.
- Use leased claims with heartbeats under `methodology/claims/` rather than treating `ACTIVE_CLAIMS.md` as the only claim record.
- Treat `ACTIVE_CLAIMS.md` as the human-facing live index only; machine-readable claim companions live under `methodology/claims/<claim-id>.json`.
- Use `/home/eyal/system-docs/methodology/claim-diff-check.sh .` when multi-agent edits need a quick conflict check against claimed files.
- Use `/home/eyal/system-docs/methodology/agent-merge-check.sh .` before merge or handoff of claimed work so stale claims, ownership conflicts, ready-for-merge flags, rebase requirements, and verification status are checked together.
- Use `/home/eyal/system-docs/methodology/worker-context-pack.sh --claim-id <claim-id> .` to build a worker-specific resume bundle after compaction or handoff.
- If non-trivial work collapses to single-agent execution, record the reason in `PROCESS_EXCEPTIONS.md`.
- For risky changes, follow the approval matrix in `AGENT_TEAM.md` instead of self-approving by default.

## Runtime Hygiene
- Keep the local runtime contract current in `LOCAL_ENV.md`.
- Use named runtime profiles in `LOCAL_ENV.md` and `COMMANDS.md` for fresh-runtime vs warm-runtime startup paths when local state meaningfully affects verification or developer flow.
- Prefer a fresh-agent reset with a strong handoff over repeated in-place compaction when long-running work starts drifting, context anxiety appears, or the same agent keeps losing coherence.
- If runtime usage breaks a finished or in-flight slice, switch into formal hotfix mode with `/home/eyal/system-docs/methodology/enter-hotfix.sh .` or its equivalent steps.
- When hotfix mode is active, `TASKS.md`, `SESSION_STATE.md`, `HANDOFF.md`, and `HOTFIX.md` must reflect runtime stabilization instead of the interrupted roadmap task.
- Do not claim cold-start-ready manual testing unless it was verified from zero running processes.
- Manual QA handoff must include what changed, which files changed, what was verified, the exact commands to run, and what the human should check.
- Treat generated runtime output as ownership-sensitive and keep it editable for the normal project user.
- If a live secret is exposed in chat/logs/output, treat it as compromised, stop repeating it, and tell the user to rotate it.

## Observable Compliance
- Before substantial work, explicitly state:
  - the work type
  - which methodology files were loaded
  - the active task
  - the task state
  - the relevant spec path for non-trivial work
  - the intended verification path
  - for `product` work: the business owner, leading metric, customer signal, and decision or review date
  - the shared risk class (`R0` / `R1` / `R2` / `R3`)
  - for production-impacting work, the release risk
- If changed files touch web UI behavior, the verification path must include the intended browser automation flow unless the skip is recorded in `PROCESS_EXCEPTIONS.md`.
- If changed files touch mobile app/device behavior, the verification path must include the intended full native Appium flow unless the skip is recorded in `PROCESS_EXCEPTIONS.md`.
- If changed files touch desktop app behavior, the verification path must include the intended Playwright/Electron or native desktop automation flow unless the skip is recorded in `PROCESS_EXCEPTIONS.md`.
- When something is ready for manual human checking, do not leave that implicit. Say it clearly and provide short instructions for what to open, where to click, and what result to expect.
- Manual-test readiness must be labeled as `warm-env verified`, `cold-start verified`, or `partially verified`.
- Never present warm-environment validation as if it were a cold-start-ready user handoff.
- Manual-test instructions must include prerequisites, quick dependency checks, an app health check, expected ports, and one note about likely local networking traps.
- If local services were already running in the agent environment, convert that into an explicit prerequisite instead of silently assuming the user has the same state.
- If running from a sudo/root shell, do not leave root-owned project files behind. Normalize ownership and edit permissions before finishing the work.
- Keep `SESSION_STATE.md` and `HANDOFF.md` visibly current during meaningful progress.
- Treat top-level `SESSION_STATE.md` and `HANDOFF.md` as compact indexes and summaries, not long narrative logs.
- Record detailed current execution state in the active task workspace files and keep them aligned with `WORK_INDEX.md`.
- If methodology steps are skipped, record the exception in `PROCESS_EXCEPTIONS.md`.
- State who approved the exception and when it expires.

## Startup Behavior
- If the methodology files are missing, bootstrap them with `/home/eyal/system-docs/methodology/bootstrap-methodology.sh .` before substantial planning or implementation.
- Methodology-managed projects must be git repos. `methodology-entry.sh`, `init-project.sh`, and `adopt-methodology.sh` initialize git automatically when `.git` is missing.
- Core surface is the default bootstrap for prototype-style repos; use `--surface full` only when you intentionally want the full template set up front.
- If the project already has the methodology files, preserve them and work from their current contents.
- Treat `methodology/PROJECT_BRIEF.md`, `methodology/TASKS.md`, `methodology/SESSION_STATE.md`, and `methodology/HANDOFF.md` as the first source of truth for startup and resume behavior.
- For repeated user or team workflows, prefer stable bash entrypoints under the project-root `scripts/` directory instead of leaving the command only inline in docs or chat.
- Keep `COMMANDS.md` pointing to `scripts/*.sh` for repeated workflows; inline commands are acceptable for occasional or one-off use.
- When a task is truly complete and accepted, prefer `/home/eyal/system-docs/methodology/finish-task.sh .` over ad hoc manual closing so verification, closure, and the local git commit stay aligned.
- When the user explicitly wants to continue to the next task, prefer `/home/eyal/system-docs/methodology/next-task.sh .` so the next ready task, start checkpoint, and local git commit stay aligned.
- These task-transition helpers create local commits when there are changes; they do not push automatically.
- Treat `METRICS.md` as an operating document. Important metrics should include owner, source, cadence, baseline, threshold, and action-if-red.
- When the repo uses AI / Codex workflows meaningfully, keep `METRICS.md` and `SECURITY_NOTES.md` current with model/provider/version, eval thresholds, cost or latency budgets, allowed tools, confirmation-required tools, and fallback behavior.
- In `production` mode, keep service ownership visible in `ARCHITECTURE.md` with engineering owner, business owner, operational owner/on-call, dashboards, alerts, runbook, rollback owner, and service tier / SLO.
- Keep active bounded experiments visible in `EXPERIMENTS.md` and completed outcomes in `EXPERIMENT_LOG.md`.
- Treat `methodology/WORK_INDEX.md` as the compact index for active task workspaces and `methodology/claims/` as the source of detailed live claim records.

## Agent Guardrails
- Stop and ask before destructive or hard-to-reverse actions that were not already explicitly requested.
- Treat data deletion, destructive migrations, force-push/history rewrite, production access, secret rotation, and auth-provider changes as confirmation-required.
- For risky changes, make blast radius, rollback path, rollback owner, and approver explicit before execution.
- Do not assume permission to touch live systems just because the local repo or tooling exists.
- Keep secrets and `.env` contents out of normal output whenever possible; if exposed, treat them as compromised.
- Follow this authority order when docs disagree:
  - `TASKS.md` for lifecycle truth
  - `WORK_INDEX.md` for active-workspace pointers
  - `methodology/work/<task>/STATE.md` for execution truth
  - `methodology/work/<task>/HANDOFF.md` for resume truth
  - `ACTIVE_CLAIMS.md` plus `methodology/claims/<claim-id>.md` and `.json` for ownership truth
  - `LOCAL_ENV.md` for runtime truth
  - `HOTFIX.md` for temporary override truth during incidents
- Keep the hot files within these budgets:
  - `CORE_CONTEXT.md`: 150 lines
  - top-level `SESSION_STATE.md`: 80 lines
  - top-level `HANDOFF.md`: 80 lines
  - `WORK_INDEX.md`: 50 active entries
  - `work/<task>/STATE.md`: 200 lines
  - `work/<task>/HANDOFF.md`: 100 lines
- Keep active specs live, but archive oversized inactive spec/log docs with `/home/eyal/system-docs/methodology/archive-cold-docs.sh` so large historical docs do not stay in the active working path.
- Before opening archived docs directly, prefer `/home/eyal/system-docs/methodology/lookup-archived-doc.sh --query "..." .` or `docs-archive-index.json` so retrieval is driven by compact metadata rather than loading large archive files blindly.
- For existing codebases that do not yet have the methodology, prefer `/home/eyal/system-docs/methodology/adopt-methodology.sh .` so the repo is retrofitted incrementally rather than treated like a blank new project.
