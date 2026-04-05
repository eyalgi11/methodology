# Methodology Registry

Use this file to classify the methodology toolkit itself.

The goal is to make artifact state explicit instead of guessing from docs, chat, or file presence alone.

## State Definitions

| State | Meaning |
| --- | --- |
| `core` | Part of the routine operating path. Agents should expect it in normal methodology usage. |
| `conditional` | Real and supported, but only loaded or invoked when the relevant trigger applies. |
| `manual` | Useful tooling or documentation that is only expected when explicitly invoked by a user or agent. |
| `experimental` | Available, but not trusted as a default dependency yet. Validate before promoting. |
| `deprecated` | Avoid for new work. Keep only for migration or compatibility until removal. |
| `template-only` | Template/source artifact. In the methodology repo it is not live runtime state; it becomes live only after being copied into a project. |

## Registry Rules

- Every `.sh`, `.md`, and `.json` artifact in this methodology source repo must be listed here exactly once.
- State changes must be updated here in the same change that changes the tooling.
- `core` should stay small and reflect the real default path.
- `conditional` should name a concrete trigger or use case.
- `manual` is acceptable for low-frequency tools; it should not silently become a required dependency.
- `experimental` should either be promoted, redesigned, or removed after enough real usage.
- `template-only` does not mean unimportant. It means the source repo stores the template, while real usage happens in project copies.
- Validate coverage with `./methodology-registry-check.sh`.

## Core

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| `adopt-methodology.sh` | script | `core` | Existing codebase retrofit entrypoint; initializes git if missing. |
| `bootstrap-methodology.sh` | script | `core` | Copies the methodology into a project and initializes git if missing. |
| `claim-work.sh` | script | `core` | Default ownership/lease flow for parallel work. |
| `compact-hot-docs.sh` | script | `core` | Keeps hot continuity docs within budget. |
| `context-pack.sh` | script | `core` | Builds the compact resume bundle after entry/resume. |
| `drift-check.sh` | script | `core` | Core consistency and hygiene check. |
| `fix-project-perms.sh` | script | `core` | Normalizes ownership after sudo/root work. |
| `init-project.sh` | script | `core` | New-project bootstrap entrypoint; initializes git automatically. |
| `methodology-audit.sh` | script | `core` | Required file/template-presence audit. |
| `methodology-common.sh` | script | `core` | Shared plumbing used across the toolkit. |
| `methodology-entry.sh` | script | `core` | Default startup/resume entry flow; ensures the project is a git repo. |
| `methodology-status.sh` | script | `core` | Continuity freshness warning check. |
| `migrate-methodology-layout.sh` | script | `core` | Migrates legacy root layout to `methodology/`. |
| `project-dashboard.sh` | script | `core` | Compact operational summary used during routine work. |
| `refresh-core-context.sh` | script | `core` | Rebuilds the default hot startup summary. |
| `refresh-methodology-state.sh` | script | `core` | Rebuilds the machine-readable startup state. |
| `resume-work.sh` | script | `core` | Standard resume sequence. |
| `stale-claims-check.sh` | script | `core` | Detects expired leases and missing heartbeats. |
| `upgrade-template-placeholders.sh` | script | `core` | Refreshes known untouched older placeholders. |
| `verify-project.sh` | script | `core` | Canonical verification runner. |
| `work-preflight.sh` | script | `core` | One-command readiness, compliance, and mode preflight before substantial implementation. |

## Conditional

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| `archive-cold-docs.sh` | script | `conditional` | Use when inactive specs/logs are bloating context. |
| `agent-merge-check.sh` | script | `conditional` | Merge or handoff gate for claimed multi-agent work. |
| `begin-work.sh` | script | `conditional` | Visible checkpoint before substantial work. |
| `close-work.sh` | script | `conditional` | Close a task across multiple docs after a meaningful chunk. |
| `decision-review.sh` | script | `conditional` | Use when ADR review dates matter. |
| `dependency-delta.sh` | script | `conditional` | Use when dependencies changed or need review. |
| `enter-hotfix.sh` | script | `conditional` | Runtime stabilization interrupts planned work. |
| `knowledge-extract.sh` | script | `conditional` | Deeper repo understanding for adoption/backfill. |
| `lookup-archived-doc.sh` | script | `conditional` | Query archived docs without loading them directly. |
| `methodology-score.sh` | script | `conditional` | Recompute methodology hygiene score when needed. |
| `metrics-check.sh` | script | `conditional` | Validate metrics content when metrics are in scope. |
| `mode-check.sh` | script | `conditional` | Enforce rigor against declared methodology mode. |
| `move-task.sh` | script | `conditional` | Lifecycle transitions with readiness/WIP rules. |
| `new-experiment.sh` | script | `conditional` | Seed a bounded experiment entry when the work is hypothesis-driven. |
| `new-feature.sh` | script | `conditional` | Seed a new feature spec under `methodology/features/` plus task. |
| `observable-compliance-check.sh` | script | `conditional` | Check that methodology use is visible on disk. |
| `progress-checkpoint.sh` | script | `conditional` | Record meaningful in-flight progress. |
| `ready-check.sh` | script | `conditional` | Gate non-trivial work before it becomes ready. |
| `record-learning.sh` | script | `conditional` | Persist lessons after incidents or rework. |
| `refresh-docs-archive-index.sh` | script | `conditional` | Rebuild archive lookup metadata after archiving. |
| `repo-intake.sh` | script | `conditional` | Detect stack/commands when adopting or backfilling. |
| `security-review.sh` | script | `conditional` | Run local security hygiene checks. |
| `session-snapshot.sh` | script | `conditional` | Capture working state at a checkpoint or handoff. |
| `sync-docs.sh` | script | `conditional` | Refresh cross-document summaries after changes. |
| `claim-diff-check.sh` | script | `conditional` | Use when multi-agent edits need a claimed-files conflict check. |
| `worker-context-pack.sh` | script | `conditional` | Build a worker-specific resume pack from claim + task workspace state. |

## Manual

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| `OPERATING_MANUAL.md` | doc | `manual` | Full end-to-end explanation of the methodology lifecycle, files, and scripts. |
| `README.md` | doc | `manual` | Human-facing overview of the methodology source. |
| `shell-methodology.sh` | script | `manual` | Shared bash/zsh shell helpers for `mstart`, `mresume`, `mupdate`, and `madopt`, while preserving shell-local behavior like `cd`. |
| `METHODOLOGY_REGISTRY.md` | doc | `manual` | Human-facing source-of-truth for toolkit artifact states. |
| `METHODOLOGY_PRINCIPLES.md` | doc | `manual` | Shortest statement of what the methodology is for and what it must not do. |
| `DEFAULT_BEHAVIOR.md` | doc | `manual` | Short default-path explanation of what the methodology usually does. |
| `METHODOLOGY_LAYERS.md` | doc | `manual` | Compact map of what is core, optional, advanced, and compatibility-only. |
| `METHODOLOGY_CONTROL_LOOP.md` | doc | `manual` | Compact rule for how the methodology should keep itself aligned with user intent. |
| `PORTABILITY.md` | doc | `manual` | Portable install and Linux/WSL usage guide for cloned methodology repos. |
| `reference/USER_FACING_FILES.md` | doc | `manual` | Compact reference for which methodology files are primarily user-facing versus internal. |
| `archive-methodology.sh` | script | `manual` | Explicit methodology archive/cleanup operation. |
| `ci-methodology-check.sh` | script | `manual` | CI-oriented methodology validation entrypoint. |
| `ensure-playwriter-cli.sh` | script | `manual` | Ensures the Playwriter CLI is installed and periodically updates it to the latest npm version before browser-automation workflows. |
| `finish-work.sh` | script | `manual` | Optional end-of-work wrapper. |
| `finish-task.sh` | script | `manual` | Preferred explicit “task is really done” flow with local commit when changed. |
| `methodology-source-work.sh` | script | `manual` | Lightweight start/finish/commit wrapper for using the methodology on its own source repo with control-surface docs, preflight, audit refresh, registry proof, and methodology-only local commits. |
| `incident-close.sh` | script | `manual` | Explicit incident close flow. |
| `incident-open.sh` | script | `manual` | Explicit incident open flow. |
| `install-methodology-hooks.sh` | script | `manual` | Opt-in git hooks. |
| `install-toolkit.sh` | script | `manual` | Registers the cloned methodology repo as the local toolkit install for Linux/WSL and writes `METHODOLOGY_HOME` config plus a small wrapper. |
| `launch-playwriter-brave.sh` | script | `manual` | Launches Brave for Playwriter-based browser automation; useful for manual bring-up and browser debugging, and supports dedicated automation profiles plus local-file URL bridging. |
| `methodology-registry-check.sh` | script | `manual` | Verifies registry coverage and state validity in the methodology source repo. |
| `playwriter-ready-session.sh` | script | `manual` | Launches a dedicated Playwriter automation browser/profile, creates a real usable session immediately, and optionally bridges local file targets to localhost URLs. |
| `playwriter-self-check.sh` | script | `manual` | Validates the full Playwriter self-launch path, including Brave availability, extension detection, local-file bridge reachability, browser connection, and optional smoke navigation. |
| `serve-local-page.sh` | script | `manual` | Converts local files into localhost browser URLs for browser automation tools that cannot use raw `file://` navigation; defaults to HTTPS and supports HTTP fallback. |
| `milestone-update.sh` | script | `manual` | Explicit milestone refresh. |
| `next-task.sh` | script | `manual` | Preferred explicit “continue to the next ready task” flow with local commit when changed. |
| `plan-task.sh` | script | `manual` | Optional task/spec planning wrapper. |
| `project-bootstrap-profile.sh` | script | `manual` | Profile-specific bootstrap instead of the default path. |
| `portability-check.sh` | script | `manual` | Flags machine-specific runtime paths in shell scripts so the toolkit stays portable across Linux/WSL installs. |
| `record-exception.sh` | script | `manual` | Explicit process-exception logging helper. |
| `record-methodology-failure.sh` | script | `manual` | Explicit methodology-failure logging helper with suggested-improvement capture. |
| `render-methodology-audit.sh` | script | `manual` | Generates a static HTML methodology audit dashboard from real repo state. |
| `release-cut.sh` | script | `manual` | Explicit release-prep flow. |
| `scaffold-stack.sh` | script | `manual` | Opinionated project scaffolding for supported stacks. |
| `set-maturity-mode.sh` | script | `manual` | Explicit maturity-mode switch helper. |
| `weekly-review.sh` | script | `manual` | Explicit weekly review generation. |

## Experimental

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| `auto-update-from-git.sh` | script | `experimental` | Repo-state backfill from git history; useful but not trusted as a default path. |
| `recovery-check.sh` | script | `experimental` | Deterministic recovery flow for context loss; available, but not yet part of the routine default path. |
| `test-gap-report.sh` | script | `experimental` | Testing-gap inference is helpful but still heuristic. |

## Deprecated

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| _None currently_ | n/a | `deprecated` | Add entries here only when a real migration path exists. |

## Template-Only

| Artifact | Kind | State | Trigger / Meaning |
| --- | --- | --- | --- |
| `ACTIVE_CLAIMS.md` | template | `template-only` | Copied into projects; becomes the compact live claim index there. |
| `AGENTS.md` | template | `template-only` | Copied into projects as the repo-local instruction layer. |
| `AGENT_TEAM.md` | template | `template-only` | Copied into projects as the stable role model. |
| `ANTI_PATTERNS.md` | template | `template-only` | Copied into projects for durable project-specific anti-patterns. |
| `ARCHITECTURE.md` | template | `template-only` | Copied into projects for important boundaries and invariants. |
| `BLOCKERS.md` | template | `template-only` | Copied into projects for active blockers. |
| `claims/README.md` | template | `template-only` | Copied into projects to explain detailed claim records. |
| `COMMANDS.md` | template | `template-only` | Copied into projects as the canonical commands surface. |
| `CORE_CONTEXT.md` | template | `template-only` | Copied into projects as the compact startup summary. |
| `DECISIONS.md` | template | `template-only` | Copied into projects as the ADR log. |
| `DEFINITION_OF_DONE.md` | template | `template-only` | Copied into projects as the done gate. |
| `DEFINITION_OF_READY.md` | template | `template-only` | Copied into projects as the readiness gate. |
| `DEPENDENCIES.md` | template | `template-only` | Copied into projects for important dependency choices. |
| `docs-archive-index.json` | data template | `template-only` | Copied into projects as archive lookup metadata. |
| `DOCS_ARCHIVE.md` | template | `template-only` | Copied into projects as the cold-doc index. |
| `EXPERIMENT_LOG.md` | template | `template-only` | Copied into projects for completed experiment outcomes and keep/discard decisions. |
| `EXPERIMENTS.md` | template | `template-only` | Copied into projects for active bounded experiments. |
| `HANDOFF.md` | template | `template-only` | Copied into projects as the compact top-level handoff. |
| `HOTFIX.md` | template | `template-only` | Copied into projects as the visible hotfix state. |
| `INCIDENTS.md` | template | `template-only` | Copied into projects for incident history. |
| `LOCAL_ENV.md` | template | `template-only` | Copied into projects as the runtime contract. |
| `MANUAL_CHECKS.md` | template | `template-only` | Copied into projects for human QA handoff steps. |
| `METHODOLOGY_EVOLUTION.md` | template | `template-only` | Copied into projects as the meta-improvement loop. |
| `METHODOLOGY_FAILURES.md` | template | `template-only` | Copied into projects as the methodology failure log and suggested-improvement surface. |
| `METHODOLOGY_MODE.md` | template | `template-only` | Copied into projects for rigor mode selection. |
| `METHODOLOGY_SCORE.md` | template | `template-only` | Copied into projects for methodology score output. |
| `METRICS.md` | template | `template-only` | Copied into projects for product/technical measures. |
| `MILESTONES.md` | template | `template-only` | Copied into projects for delivery checkpoints. |
| `methodology-state.json` | data template | `template-only` | Copied into projects as machine-readable state. |
| `MULTI_AGENT_PLAN.md` | template | `template-only` | Copied into projects for multi-agent decomposition. |
| `OBSERVABLE_COMPLIANCE.md` | template | `template-only` | Copied into projects as visible methodology rules. |
| `OPEN_QUESTIONS.md` | template | `template-only` | Copied into projects for unresolved questions. |
| `PROCESS_EXCEPTIONS.md` | template | `template-only` | Copied into projects for explicit methodology exceptions. |
| `PROJECT_BRIEF.md` | template | `template-only` | Copied into projects as the project brief. |
| `PROJECT_HEALTH.md` | template | `template-only` | Copied into projects for operating health. |
| `RELEASE_NOTES.md` | template | `template-only` | Copied into projects for user-visible change tracking. |
| `REPO_MAP.md` | template | `template-only` | Copied into projects for orientation. |
| `RISK_REGISTER.md` | template | `template-only` | Copied into projects for active risks. |
| `ROADMAP.md` | template | `template-only` | Copied into projects for now/next/later priorities. |
| `SECURITY_NOTES.md` | template | `template-only` | Copied into projects for security assumptions and risk. |
| `SESSION_STATE.md` | template | `template-only` | Copied into projects as the compact top-level state index. |
| `templates/FEATURE_SPEC_TEMPLATE.md` | template | `template-only` | Copied into projects as the default non-trivial work spec source under `methodology/templates/`. |
| `TASKS_ARCHIVE.md` | template | `template-only` | Copied into projects for archived completed tasks. |
| `TASKS.md` | template | `template-only` | Copied into projects as lifecycle truth. |
| `VERIFICATION_LOG.md` | template | `template-only` | Copied into projects as verification evidence storage. |
| `WEEKLY_REVIEW.md` | template | `template-only` | Copied into projects for compact weekly reviews. |
| `work/README.md` | template | `template-only` | Copied into projects to explain task-local workspaces. |
| `work/SPRINT_CONTRACT_TEMPLATE.md` | template | `template-only` | Copied into projects as the template for per-task sprint contracts. |
| `WORKING_AGREEMENTS.md` | template | `template-only` | Copied into projects for coding and operating defaults. |
| `WORK_INDEX.md` | template | `template-only` | Copied into projects as the active-workspace pointer index. |
