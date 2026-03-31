# Methodology Templates

Startup-style operating templates for new software projects, designed to work from a cloned toolkit repo on Linux and WSL.

Repo boundary note:
- this cloned `methodology/` directory is its own git repo
- a parent directory may still contain unrelated files, so methodology-source work should use git from the `methodology/` directory itself

## Install On Another Machine

After cloning this repo on another Linux or WSL machine:

```bash
cd /path/to/cloned/methodology
./install-toolkit.sh
```

That writes `METHODOLOGY_HOME` config under `~/.config/methodology/config.env`, installs a small `mtool` wrapper in `~/.local/bin`, and lets project bootstraps record the correct toolkit path in `methodology/toolkit-path.txt`.

Portable runtime rules:
- project bootstraps write `methodology/toolkit-path.txt` automatically
- generated guidance should resolve through `METHODOLOGY_HOME` or that project-local toolkit path file
- `./portability-check.sh` is the source-repo guard against machine-specific runtime paths
- from the methodology repo root, examples in this README use `./script.sh`
- from elsewhere on the same machine after install, use `mtool script.sh`
- normal methodology use should run as the regular project user, not from a long-lived sudo/root shell

If you want the shortest possible explanation of what this methodology is trying to do and what it will usually do, read these first:
- [METHODOLOGY_PRINCIPLES.md](./METHODOLOGY_PRINCIPLES.md)
- [DEFAULT_BEHAVIOR.md](./DEFAULT_BEHAVIOR.md)
- [METHODOLOGY_LAYERS.md](./METHODOLOGY_LAYERS.md)
- [METHODOLOGY_CONTROL_LOOP.md](./METHODOLOGY_CONTROL_LOOP.md)
- [PORTABILITY.md](./PORTABILITY.md)

For one end-to-end explanation of what the methodology does, how the main files fit together, and which scripts to use in the normal lifecycle, read [OPERATING_MANUAL.md](./OPERATING_MANUAL.md).

## Governance
- Agents may improve the global methodology when real project work reveals a recurring cross-project gap, noisy check, missing automation, or unclear workflow.
- Keep project-specific preferences inside the project unless the same need appears repeatedly across projects.
- Prefer the smallest global change that resolves the recurring issue.
- When global methodology changes are made, update both docs and automation together.
- The methodology source repo classifies its own artifacts in `METHODOLOGY_REGISTRY.md`.
- Artifact states mean:
  - `core`: default operating path
  - `conditional`: real but only when a trigger applies
  - `manual`: explicit opt-in helper or doc
  - `experimental`: available but not trusted as default
  - `deprecated`: avoid for new work
- `template-only`: source template that becomes live only after it is copied into a project
- Validate registry coverage with `./methodology-registry-check.sh`.
- Treat sudo/root execution as an exception path for system-level setup or ownership repair, not as the normal methodology operating mode.

## Read This First

If you want to audit intent quickly:
- `METHODOLOGY_PRINCIPLES.md` is the shortest statement of what the methodology is for
- `DEFAULT_BEHAVIOR.md` is the normal operating path
- `METHODOLOGY_LAYERS.md` tells you what is core versus optional
- `METHODOLOGY_CONTROL_LOOP.md` explains how the methodology should keep itself aligned with the user's intent

Do not treat this toolkit as one flat list of files and scripts.

Use it in layers:
- `core`: the normal operating path; this is the only layer that should be assumed by default
- `conditional`: use only when the trigger applies
- `manual`: useful helpers, but not part of the default loop
- `experimental`: available, but not trusted as default behavior yet
- `template-only`: source templates that become live only after they are copied into a project

If you are entering or resuming real project work, start with the `core` layer and pull in the rest only when needed.

## Core Path

This is the real default methodology path.

Startup and continuity:
- `init-project.sh`: create a new project with the methodology and initialize git
- `adopt-methodology.sh`: retrofit an existing repo and initialize git if missing
- `bootstrap-methodology.sh`: add missing methodology files and initialize git if missing; defaults to the lighter core surface for prototype-style repos
- `methodology-entry.sh`: default startup/resume entry flow
- `work-preflight.sh`: one-command startup, readiness, compliance, and mode summary before substantial implementation
- `resume-work.sh`: standard resume sequence
- `refresh-methodology-state.sh`: rebuild machine-readable state
- `refresh-core-context.sh`: rebuild the compact human startup summary

Default hot state:
- `CORE_CONTEXT.md`
- `WORK_INDEX.md`
- `TASKS.md`
- `SESSION_STATE.md`
- `HANDOFF.md`
- `methodology-state.json`

Default operating hygiene:
- `project-dashboard.sh`: compact situational read
- `verify-project.sh`: canonical verification runner
- `claim-work.sh`: ownership/lease flow for parallel work
- `worker-context-pack.sh`: worker-specific resume bundle from claim + task workspace + spec + commands
- `claim-diff-check.sh`: changed-file check against active claims
- `agent-merge-check.sh`: one merge/handoff gate for stale claims, ownership conflicts, merge readiness, and verification status
- `stale-claims-check.sh`: expired-claim detection
- `compact-hot-docs.sh`: keep hot docs within budget
- `drift-check.sh`: consistency/hygiene check
- `methodology-audit.sh`: required-file/template audit
- `methodology-status.sh`: continuity freshness warning check
- `fix-project-perms.sh`: normalize ownership after sudo/root work

## Other Layers

Conditional:
- pull these in only when the work actually needs them
- examples: `enter-hotfix.sh`, `archive-cold-docs.sh`, `repo-intake.sh`, `security-review.sh`, `move-task.sh`, `ready-check.sh`, `mode-check.sh`, `decision-review.sh`, `new-experiment.sh`

Manual:
- useful helpers, but not part of the normal path
- examples: `finish-task.sh`, `next-task.sh`, `finish-work.sh`, `plan-task.sh`, `release-cut.sh`, `incident-open.sh`, `incident-close.sh`, `weekly-review.sh`, `install-methodology-hooks.sh`

Experimental:
- available, but not default
- current examples: `auto-update-from-git.sh`, `recovery-check.sh`, `test-gap-report.sh`

Template-only:
- these are the source templates in this repo
- they become live only after they are copied into a project
- examples: `TASKS.md`, `COMMANDS.md`, `LOCAL_ENV.md`, `MANUAL_CHECKS.md`, `WORK_INDEX.md`, `templates/FEATURE_SPEC_TEMPLATE.md`

## Files
- This section is the full reference inventory.
- For daily use, prefer the `Core Path` and `Other Layers` sections above.
- Layout:
  - root `AGENTS.md` stays at the repo root so project instructions are always discoverable
  - root `specs/` is reserved for repo-native specs or legacy feature-spec locations; new methodology bootstrap no longer creates it by default
  - new methodology-managed feature specs live under `methodology/features/`
  - the methodology feature-spec template source lives under `methodology/templates/`
  - all other methodology docs and state files live under `methodology/`
- `README.md`: human-facing overview of the methodology source repo
- `METHODOLOGY_REGISTRY.md`: source-of-truth classification of methodology source artifacts by operating state
- `AGENTS.md`: project-local startup and resume rules that force operational methodology entry inside the repo
- `AGENT_TEAM.md`: stable startup-style agent roles, risk-based team-shape thresholds, escalation rules, and approval matrix
- `CORE_CONTEXT.md`: compact session-start summary; the first methodology file to load after compaction or at session start
- `methodology-state.json`: first machine-readable startup surface for low-context agents; use it before prose docs when possible, and treat it as the schema-versioned machine state
- `WORK_INDEX.md`: compact index of active task workspaces so agents can find detailed in-flight state without loading every work file
- `work/<task-slug>/TASK.json`: canonical task metadata for an active task workspace; use it as the stable source for task state, spec, risk, and release metadata when it exists
- `work/SPRINT_CONTRACT_TEMPLATE.md`: template for a task-local sprint contract that bridges a high-level spec into one concrete implementation chunk and evaluator agreement
- `DOCS_ARCHIVE.md`: index of cold specs/logs that were archived out of the active working path
- `docs-archive-index.json`: compact machine-readable metadata for archived docs so agents can retrieve the right doc without loading the full archive
- `LOCAL_ENV.md`: canonical local runtime contract for databases, services, ports, cleanup/reset, ownership-sensitive outputs, and schema triage
- `HOTFIX.md`: formal runtime stabilization state for hotfix mode
- `PROJECT_BRIEF.md`: business + product brief with work type, owner, why-now context, customer evidence, prioritization economics, business impact, constraints, and kill criteria
- `ROADMAP.md`: `now / next / later` priorities
- `TASKS.md`: executable task list and status
- `TASKS_ARCHIVE.md`: archived older completed tasks so `TASKS.md` stays on the current hot path
- `MULTI_AGENT_PLAN.md`: lead/worker decomposition, ownership, and merge order for multi-agent execution
- `DECISIONS.md`: short ADR-style decision log
- `DEFINITION_OF_READY.md`: minimum conditions before non-trivial work can start, including blast radius, ownership, instrumentation, and rollback readiness
- `DEFINITION_OF_DONE.md`: quality gate for completion, including monitoring, support readiness, communication, and post-launch review scheduling
- `WORKING_AGREEMENTS.md`: coding standards, operating defaults, and explicit operating cadence
- `REPO_MAP.md`: orientation to key folders, entrypoints, and feature locations
- `COMMANDS.md`: canonical setup, run, test, and release commands
- `ARCHITECTURE.md`: important system boundaries, flows, invariants, and in `production` mode the service ownership surface for dashboards, runbooks, alerts, and rollback responsibility
- `ANTI_PATTERNS.md`: project-specific approaches to avoid
- `METHODOLOGY_MODE.md`: current maturity mode, reason, upgrade triggers, and expected rigor
- `METHODOLOGY_EVOLUTION.md`: explicit loop for improving the methodology from real project work
- `OBSERVABLE_COMPLIANCE.md`: rules for making methodology use visible during development, including business owner, leading metric, customer signal, decision date, risk class, and release risk
- `ACTIVE_CLAIMS.md`: explicit task and file ownership for parallel agents
- `work/README.md`: explains the per-task workspace layout under `methodology/work/`
- `claims/README.md`: explains the detailed leased-claim layout under `methodology/claims/`
- `BLOCKERS.md`: active blockers that prevent progress
- `PROCESS_EXCEPTIONS.md`: documented methodology deviations with risk, compensating controls, approver, expiry, CI behavior, and backfill evidence
- `SESSION_STATE.md`: current working state for the active agent session
- `HANDOFF.md`: compact resume guide for the next session or agent
- `VERIFICATION_LOG.md`: durable record of checks, tests, and gaps
- `MANUAL_CHECKS.md`: exact user-facing steps for manual verification, including artifact links and failure-report guidance
- `EXPERIMENTS.md`: active bounded experiments with hypotheses, metrics, budgets, and stop rules
- `EXPERIMENT_LOG.md`: completed experiment outcomes and keep/discard decisions
- `OPEN_QUESTIONS.md`: unresolved decisions or product questions
- `RISK_REGISTER.md`: active risks and mitigations
- `RELEASE_NOTES.md`: user-visible changes and migration notes
- `MILESTONES.md`: concrete delivery checkpoints toward release
- `METRICS.md`: product, technical, service-level, AI / agent, cost, and methodology measures with owner/source/cadence/baseline/threshold/action fields
- `SECURITY_NOTES.md`: risk tier, data sensitivity, secret handling, tool-access policy, AI / data exposure policy, waiver/owner info, and abuse concerns
- `PROJECT_HEALTH.md`: quick health snapshot of the project, including post-launch reviews due
- `INCIDENTS.md`: regressions, outages, detection/mitigation timing, gaps, and corrective action
- `DEPENDENCIES.md`: important libraries/services and why they exist
- `WEEKLY_REVIEW.md`: compact weekly operating reviews
- `METHODOLOGY_SCORE.md`: methodology completeness and hygiene score
- `methodology-state.json`: machine-readable current methodology state
- `templates/FEATURE_SPEC_TEMPLATE.md`: source template for non-trivial feature work
- `bootstrap-methodology.sh`: idempotent helper that initializes git if missing, then copies root `AGENTS.md` and the chosen methodology surface into `methodology/`
- `migrate-methodology-layout.sh`: moves legacy root-level methodology docs into `methodology/` while preserving root `AGENTS.md` and root `specs/`
- `init-project.sh`: creates a new project directory, initializes git, and bootstraps the methodology
- `adopt-methodology.sh`: adds the methodology to an existing codebase, initializes git if missing, and rehydrates current repo state
- `methodology-entry.sh`: the default project-entry flow that bootstraps if needed, rehydrates the project, and records a visible start checkpoint
- `recovery-check.sh`: deterministic recovery flow for lost context or stale continuity
- `methodology-audit.sh`: finds missing methodology files and untouched templates
- `methodology-status.sh`: warns when continuity docs are missing or stale
- `methodology-common.sh`: shared shell helpers used by the automation scripts
- `refresh-core-context.sh`: rebuilds `CORE_CONTEXT.md` from the current project state
- `compact-hot-docs.sh`: trims hot-path rolling docs and archives older completed tasks
- `archive-cold-docs.sh`: archives oversized inactive spec/log docs into `archive/docs/` and leaves short stubs at the original paths
- `refresh-docs-archive-index.sh`: rebuilds `docs-archive-index.json` from archived-doc stubs and archives
- `lookup-archived-doc.sh`: searches archived-doc metadata and returns the most relevant archived docs without opening the full files
- `enter-hotfix.sh`: switches the repo into visible runtime hotfix mode and corrects working-state docs
- `repo-intake.sh`: auto-detects repo structure and writes baseline doc sections
- `begin-work.sh`: records a visible start-of-work methodology checkpoint
- `progress-checkpoint.sh`: records a visible in-flight methodology checkpoint
- `ready-check.sh`: verifies that a task is truly ready before it moves to Ready
- `move-task.sh`: moves tasks between lifecycle states with readiness and WIP enforcement
- `next-task.sh`: moves the next ready task into progress, records the start checkpoint, and creates a local git commit if there are changes
- `session-snapshot.sh`: writes current branch, touched files, and next-step context
- `verify-project.sh`: runs verification commands from `COMMANDS.md` and logs the result
- `context-pack.sh`: builds a compact markdown resume bundle from the repo and key docs
- `worker-context-pack.sh`: builds a compact worker-specific resume bundle from a claim record and task-local state
- `agent-merge-check.sh`: validates whether claimed work is actually ready to merge or hand off
- `render-methodology-audit.sh`: generates a static HTML audit dashboard with user and agent views from real repo state; by default it writes to `methodology/methodology-audit.html` in a project repo and `methodology-audit.html` in the methodology source repo itself
- `launch-playwriter-brave.sh`: launches Brave for Playwriter-based browser automation; useful for manual bring-up and browser debugging
- `playwriter-ready-session.sh`: launches a dedicated Playwriter automation browser/profile and immediately establishes a usable Playwriter session for autonomous browser work
- `ensure-playwriter-cli.sh`: keeps the Playwriter CLI installed and periodically updated to the latest npm version for methodology-managed browser automation
- `playwriter-self-check.sh`: validates the autonomous Playwriter path using the same ready-session flow the methodology should rely on
- `serve-local-page.sh`: converts a local file path into a localhost URL and starts or reuses the local file server needed for browser automation tools that cannot navigate raw `file://` URLs; it defaults to HTTPS and also supports HTTP fallback
- Normal methodology refresh flows now update the audit page automatically through `refresh-methodology-state.sh`, so `methodology/methodology-audit.html` stays current without a separate manual command in most projects
- `work-preflight.sh`: runs entry plus readiness/compliance/mode checks and prints one short remediation list
- `drift-check.sh`: checks for contradictions, stale docs, and optional command failures
- `new-feature.sh`: explicit opt-in helper that creates a feature spec under `methodology/features/` and a corresponding planned task when the user asks for a spec/task seed
- `new-experiment.sh`: creates a bounded experiment entry in `EXPERIMENTS.md`
- `close-work.sh`: closes a task across tasks, handoff, session, health, and release notes
- `finish-task.sh`: finishes a truly-done task through verification, closure, and a local git commit when there are changes
- `methodology-source-work.sh`: lightweight start/finish/commit wrapper for using the methodology on its own source repo with control-surface docs, preflight, audit refresh, registry proof, and local commits in the standalone methodology source repo
- `sync-docs.sh`: refreshes cross-document auto summaries
- `scaffold-stack.sh`: creates a starter app for a supported stack, then initializes methodology
- `milestone-update.sh`: refreshes milestone confidence and delivery health
- `release-cut.sh`: writes a release-candidate summary from repo state
- `security-review.sh`: runs lightweight repo security hygiene checks
- `dependency-delta.sh`: finds dependencies that are not documented in `DEPENDENCIES.md`
- `project-dashboard.sh`: prints a compact operational summary of the project
- `install-methodology-hooks.sh`: installs warning-only git hooks for methodology drift
- `resume-work.sh`: runs the standard resume sequence and writes a context pack
- `finish-work.sh`: runs the standard end-of-work sequence
- `ci-methodology-check.sh`: read-only methodology checks for CI
- `plan-task.sh`: explicit opt-in helper that creates a feature spec plus seed questions and risks when the user asks for planning/spec scaffolding
- `auto-update-from-git.sh`: refreshes docs from branch/status/commit state
- `project-bootstrap-profile.sh`: scaffolds a profile-specific project shape
- `knowledge-extract.sh`: deeper repo scan that enriches methodology docs
- `test-gap-report.sh`: flags likely testing gaps from repo state
- `incident-open.sh`: opens an incident record and updates project health
- `incident-close.sh`: closes an incident record with fix/follow-up details
- `metrics-check.sh`: validates that METRICS.md contains usable values
- `mode-check.sh`: checks whether repo rigor matches the declared maturity mode
- `decision-review.sh`: flags ADRs with missing or overdue review dates
- `observable-compliance-check.sh`: detects when methodology use is not visible on disk
- `record-learning.sh`: stores durable lessons in anti-patterns, agreements, or decisions
- `claim-work.sh`: claims or releases task/file ownership in `ACTIVE_CLAIMS.md`
- `claim-diff-check.sh`: compares active diffs to claimed file ownership
- `stale-claims-check.sh`: reports claims with expired leases or missing heartbeats
- `fix-project-perms.sh`: normalizes project ownership and edit permissions after work done in a sudo/root shell
- `upgrade-template-placeholders.sh`: refreshes known untouched older methodology placeholders to the latest template version
- `methodology-registry-check.sh`: verifies that every `.sh`, `.md`, and `.json` artifact in the methodology source repo is classified in `METHODOLOGY_REGISTRY.md`

## Usage
Run the bootstrap helper from the project root or pass a target path:

```bash
./bootstrap-methodology.sh
./bootstrap-methodology.sh /path/to/project
```

Existing files are preserved. Missing files are created.

## Automation
```bash
./init-project.sh /path/to/project
./work-preflight.sh /path/to/project
./adopt-methodology.sh /path/to/project
./methodology-entry.sh /path/to/project
./methodology-audit.sh /path/to/project
./methodology-status.sh /path/to/project
./repo-intake.sh /path/to/project
./begin-work.sh --task "Add billing settings" --state in_progress /path/to/project
./new-feature.sh --title "Add billing settings" /path/to/project
./new-experiment.sh --title "Headline variant" --hypothesis "Shorter headline increases signup CTR" --metric "signup CTR" /path/to/project
./progress-checkpoint.sh --summary "Finished the API wiring" /path/to/project
./ready-check.sh --task "Add billing settings" /path/to/project
./move-task.sh --task "Add billing settings" --to ready /path/to/project
./next-task.sh /path/to/project
./session-snapshot.sh --next-step "Run the next task" /path/to/project
./verify-project.sh /path/to/project
./context-pack.sh --output /tmp/context.md /path/to/project
./worker-context-pack.sh --claim-id claim-2026-03-21-builder-task /path/to/project
./agent-merge-check.sh --claim-id claim-2026-03-21-builder-task /path/to/project
./drift-check.sh --verify-commands /path/to/project
./archive-cold-docs.sh /path/to/project
./refresh-docs-archive-index.sh /path/to/project
./lookup-archived-doc.sh --query "billing history" /path/to/project
./enter-hotfix.sh --summary "Auth login fails in real usage" --interrupted-task "T-014" /path/to/project
./close-work.sh --task "Add billing settings" /path/to/project
./sync-docs.sh /path/to/project
./scaffold-stack.sh --git vite /path/to/project
./milestone-update.sh /path/to/project
./release-cut.sh --version v0.1.0 /path/to/project
./security-review.sh /path/to/project
./dependency-delta.sh /path/to/project
./project-dashboard.sh /path/to/project
./install-methodology-hooks.sh /path/to/project
./resume-work.sh /path/to/project
./finish-task.sh --task "Add billing settings" /path/to/project
./ci-methodology-check.sh /path/to/project
./plan-task.sh --title "Add billing settings" /path/to/project
./auto-update-from-git.sh /path/to/project
./project-bootstrap-profile.sh --git saas-web /path/to/project
./knowledge-extract.sh /path/to/project
./test-gap-report.sh /path/to/project
./incident-open.sh --summary "Checkout outage" /path/to/project
./incident-close.sh --id 2026-03-06-checkout-outage /path/to/project
./metrics-check.sh /path/to/project
./mode-check.sh /path/to/project
./decision-review.sh /path/to/project
./observable-compliance-check.sh /path/to/project
./record-learning.sh --target anti-pattern --summary "Avoid direct lifecycle edits" /path/to/project
./claim-work.sh --agent agent-a --task "Add billing settings" --file src/app.ts /path/to/project
./claim-diff-check.sh /path/to/project
./fix-project-perms.sh /path/to/project
./upgrade-template-placeholders.sh /path/to/project
./methodology-registry-check.sh
```

- `init-project.sh` is the recommended way to create a brand new project directory; it initializes git automatically.
- `adopt-methodology.sh` is the recommended way to bring an existing repo under the methodology without overwriting its existing code and docs, and it initializes git automatically if missing.
- `migrate-methodology-layout.sh` is the safe upgrade path for older repos that still keep methodology docs in the repo root.
- `methodology-entry.sh` is the recommended way to enter a project for substantial work, whether the project is new, existing, or being resumed after context loss.
- `methodology-entry.sh`, `resume-work.sh`, and `context-pack.sh` support startup profiles:
  - `minimal`: `methodology-state.json`, `CORE_CONTEXT.md`, `WORK_INDEX.md`, active task workspace, active spec
  - `normal`: the standard operating read path
  - `deep`: normal plus architecture/runtime/supporting docs
- `methodology-state.json` now also carries business-owner/review metadata and active-spec release risk so low-context agents can start from machine state plus compact human state.
- `methodology/CORE_CONTEXT.md` is the default first file to load at session start; broader methodology docs should be loaded on demand.
- Hard hot-doc budgets now apply:
  - `CORE_CONTEXT.md`: about 100-150 lines
  - top-level `SESSION_STATE.md`: about 60-80 lines
  - top-level `HANDOFF.md`: about 60-80 lines
  - `WORK_INDEX.md`: about 50 active entries
  - task `STATE.md`: about 150-200 lines
  - task `HANDOFF.md`: about 100 lines
- `methodology/WORK_INDEX.md` is the compact bridge from top-level state into the detailed task workspace under `methodology/work/<task-slug>/`.
- Shared top-level `SESSION_STATE.md` and `HANDOFF.md` are summary indexes; the active task workspace holds the detailed current execution state and handoff.
- `ACTIVE_CLAIMS.md` is a live index; detailed claim records with lease/heartbeat data live under `methodology/claims/`.
- `claim-work.sh` plus `stale-claims-check.sh` provide the default leased-claim flow for non-persistent multi-agent work.
- Source-of-truth hierarchy is explicit:
  - `TASKS.md` lifecycle truth
  - `WORK_INDEX.md` active-workspace truth
  - task `STATE.md` execution truth
  - task `HANDOFF.md` resume truth
  - claims ownership truth
  - `LOCAL_ENV.md` runtime truth
  - `HOTFIX.md` hotfix override truth
- `compact-hot-docs.sh` is part of the normal maintenance path and should keep `TASKS.md`, `SESSION_STATE.md`, and `HANDOFF.md` lean over time.
- `archive-cold-docs.sh` keeps the on-demand layer lean too by moving large inactive spec/log docs under `archive/docs/` while leaving short stubs at the original paths.
- `lookup-archived-doc.sh` should be the default retrieval path for archived docs; use it before opening full archived markdown files.
- `docs-archive-index.json` is the compact archive-retrieval surface for agents and should stay small enough to inspect without loading the full archive.
- `LOCAL_ENV.md` should define the canonical local runtime contract, including cleanup/reset commands and schema mismatch triage.
- `LOCAL_ENV.md` and `COMMANDS.md` should define named runtime profiles plus fresh-runtime and warm-runtime launch/reset scripts when local state meaningfully affects verification or developer flow.
- `HOTFIX.md` plus `enter-hotfix.sh` are the default runtime-stabilization path when real usage interrupts roadmap work.
- Manual QA handoffs should use `MANUAL_CHECKS.md` plus `HANDOFF.md` and must say what changed, which files changed, what was verified, exact commands to run, and what the human should check.
- `PROJECT_BRIEF.md` and feature specs now intentionally carry business/customer/release context so the methodology behaves more like a company operating system, not only an engineering workflow.
- Feature specs are read-only by default. Agents should implement against them and record discovered drift separately unless the user explicitly asks for a spec change.
- For non-trivial user-facing UI work, Stitch MCP is the default design-basis tool: generate or refine screens first, then implement against that design basis instead of inventing the visual direction ad hoc.
- When using the Stitch web UI directly, prefer `Thinking with 3.1 Pro` / Gemini 3.1 Pro when that mode is available. For Stitch MCP, use the default supported model unless the exact accepted `modelId` has been verified in the current environment. Use `3 Flash` only for intentionally speed-first iterations, and use `Redesign` only for screenshot-driven redesign work.
- For non-trivial web UI implementation after the design basis exists, `frontend-design` is the preferred frontend craft skill for turning that basis into polished, production-quality interface code.
- Approval, release, and exception handling are now more independent for risky work; do not treat Lead self-approval as the default for migrations, releases, waivers, or higher-risk completion decisions.
- `PROCESS_EXCEPTIONS.md` is operational now: use risk level, compensating control, owner, status, expiry, CI behavior, and evidence of backfill.
- Post-launch review is now part of the normal flow through feature specs, release notes, and project health instead of being left implicit after shipping.
- `EXPERIMENTS.md` and `EXPERIMENT_LOG.md` are the controlled experimentation layer: use them for bounded hypothesis-driven work instead of letting agents run unbounded loops.
- Cold-start-ready handoff means verified from zero running processes; otherwise label it as warm-env verified or partially verified.
- Feature-complete and integration-hardened are not the same; if integration hardening is still needed, create an explicit stabilization follow-up task.
- `methodology-audit.sh` returns non-zero when files are missing or still untouched templates.
- `methodology-status.sh` returns non-zero when key continuity files are missing or older than recent work files.
- `repo-intake.sh` updates `COMMANDS.md`, `REPO_MAP.md`, `ARCHITECTURE.md`, and `DEPENDENCIES.md` with auto-detected sections.
- `begin-work.sh`, `progress-checkpoint.sh`, and `observable-compliance-check.sh` make methodology usage visible instead of implicit.
- `new-feature.sh`, `ready-check.sh`, and `move-task.sh` form the default non-trivial task lifecycle.
- For non-trivial implementation chunks, create `work/<task-slug>/SPRINT_CONTRACT.md` from `work/SPRINT_CONTRACT_TEMPLATE.md` before substantial coding.
- Multi-agent work should follow `AGENT_TEAM.md`, be planned in `MULTI_AGENT_PLAN.md`, and be claimed in `ACTIVE_CLAIMS.md` before substantial parallel edits begin.
- If `AGENT_TEAM.md` sets `Delegation policy: single_agent_by_platform_policy`, single-agent execution is allowed without recurring exception noise until the user explicitly asks for delegation.
- Use harness escalation instead of one-size-fits-all rigor:
  - light harness for trivial or tightly bounded tasks
  - standard harness for normal non-trivial work
  - heavy harness only for long-running, risky, search-heavy, or highly subjective work
- Do not treat heavy 3-agent harnesses, 5-15 iteration loops, or multi-hour autonomous runs as universal defaults.
- `session-snapshot.sh` refreshes `SESSION_STATE.md`, `HANDOFF.md`, and an auto section in `PROJECT_HEALTH.md`.
- `verify-project.sh` defaults to the `Test`, `Quality`, and `Build / Release` sections from `COMMANDS.md`.
- Repeated developer or operator workflows should live as bash scripts under project-root `scripts/`, with `COMMANDS.md` pointing to those scripts instead of burying long inline commands in docs.
- When something is ready for a human to verify directly, update `MANUAL_CHECKS.md` and tell the user exactly how to check it.
- Manual-test readiness must be labeled as `warm-env verified`, `cold-start verified`, or `partially verified`.
- Manual-test handoffs must include prerequisites, dependency preflight checks, an app health check, expected ports, and likely local networking traps.
- Do not let already-running local services become silent assumptions; convert them into explicit prerequisites.
- When work runs from a sudo/root shell, use `fix-project-perms.sh` or the built-in bootstrap/scaffold hooks so project files stay editable from the normal user shell.
- `upgrade-template-placeholders.sh` is intended for existing methodology-managed repos that still have older untouched placeholder files and is part of the `mupdate` flow.
- For web UI projects, treat browser automation as a default verification path in `COMMANDS.md` and feature specs, and use `playwriter` when browser behavior matters unless the skip is documented in `PROCESS_EXCEPTIONS.md`.
- When `playwriter` is the browser automation path, prefer a real visible Brave profile launched through `./launch-playwriter-brave.sh` from the toolkit repo or a project-root wrapper script under `scripts/`. First-time extension installation or enablement is a one-time bootstrap step; it should not be repeated as part of normal verification.
- The methodology should keep the Playwriter CLI updated automatically through `./ensure-playwriter-cli.sh`, and the Brave launcher should run that updater before Playwriter-based browser automation by default.
- The launcher should prefer the visible Brave profile that already has the Playwriter extension installed instead of defaulting to an isolated browser data directory.
- When the Playwriter self-launch path is uncertain, run `./playwriter-self-check.sh` so the browser, extension, localhost bridge, and smoke navigation are validated in one place before deeper debugging.
- That Playwriter Brave launch path is allowed to ignore localhost certificate errors so HTTPS localhost pages can still be automated without weakening the user's normal browsing habits outside that launched profile.
- When the browser automation target is a local HTML file, local report, or generated page, convert it to a localhost URL with `./serve-local-page.sh` instead of relying on raw `file://` navigation. The helper defaults to HTTPS, and `launch-playwriter-brave.sh` now does that automatically for local file targets with a localhost HTTP fallback when the current Playwriter environment rejects the local HTTPS certificate.
- For mobile app projects, treat full native Appium verification as the default verification path in `COMMANDS.md` and feature specs, and use `appium-mobile` when device behavior matters unless the skip is documented in `PROCESS_EXCEPTIONS.md`.
- For desktop app projects, treat desktop automation as a default verification path in `COMMANDS.md` and feature specs; use Playwright/Electron for browser-tech desktop apps and native desktop automation such as Appium Mac2 or Windows driver / WinAppDriver for native desktop apps unless the skip is documented in `PROCESS_EXCEPTIONS.md`.
- `context-pack.sh` is useful before handoff or after conversation compaction.
- Compaction and reset are not the same tool: use compaction for shorter continuity preservation, but prefer a fresh-agent reset plus strong handoff when long-running work starts drifting or the agent loses coherence.
- Separate generation from evaluation when practical. The builder should not be the only agent deciding the sprint met its contract, especially for UI/design or long-running work.
- Use confidence language precisely: `implemented` for changed work, `verified` for a passed target path, and `stable` only for stronger repeated or cross-path proof.
- For methodology changes, keep source proof and dogfood proof distinct: source repo proves toolkit correctness, dogfood repo proves lived workflow behavior.
- `drift-check.sh` combines structural checks with higher-level doc consistency checks.
- `recovery-check.sh` is the deterministic recovery checklist for lost context, stale continuity, and abandoned claims.
- `template_source` is a valid methodology mode for the methodology repo itself; it relaxes placeholder/freshness expectations while keeping tooling checks meaningful.
- `close-work.sh` and `sync-docs.sh` help keep the methodology current at the end of a work chunk.
- `close-work.sh`, `sync-docs.sh`, and `archive-methodology.sh` now run the cold-doc archive step automatically; `resume-work.sh` intentionally does not.
- `scaffold-stack.sh` creates a starter app and immediately brings it under the methodology.
- `milestone-update.sh`, `release-cut.sh`, `security-review.sh`, and `dependency-delta.sh` are periodic maintenance checks.
- `project-dashboard.sh` is the best single command for a quick situational read.
- `install-methodology-hooks.sh` installs warning-only hooks and never blocks git.
- `resume-work.sh`, `finish-task.sh`, and `next-task.sh` are the highest-level daily workflow commands.
- `finish-task.sh` and `next-task.sh` create local commits when there are changes; they do not push automatically.
- `ci-methodology-check.sh` is the enforcement entrypoint for automated pipelines.
- `plan-task.sh`, `auto-update-from-git.sh`, and `knowledge-extract.sh` reduce manual doc maintenance.
- `test-gap-report.sh`, `incident-open.sh`, `incident-close.sh`, `metrics-check.sh`, `mode-check.sh`, `decision-review.sh`, `observable-compliance-check.sh`, `record-learning.sh`, and `claim-work.sh` cover testing, rigor, visibility, learning, and coordination hygiene.
- `METHODOLOGY_REGISTRY.md` applies to the methodology source repo itself. It is not bootstrapped into projects, because it classifies toolkit artifacts rather than project state.
