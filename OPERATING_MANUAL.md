# Methodology Operating Manual

This manual explains what the methodology is, how it is meant to be used in practice, and what each major file and script is responsible for.

Use this document when you want one end-to-end explanation instead of jumping between the README, templates, and helper scripts.

Source repo boundary note:
- this cloned `methodology/` directory is the methodology source git repo
- the parent directory may contain unrelated files and should not be treated as the methodology source boundary
- commands below assume you are running them from the methodology repo root with `./script.sh`
- after `./install-toolkit.sh`, you can run the same helpers from elsewhere with `mtool script.sh`

## Installing The Toolkit On Linux Or WSL

After cloning the methodology repo on another machine, run:

```bash
cd /path/to/cloned/methodology
./install-toolkit.sh
```

That does three things:
- writes `METHODOLOGY_HOME` config under `~/.config/methodology/config.env`
- installs a small `mtool` wrapper in `~/.local/bin`
- makes project bootstraps record the cloned toolkit path in `methodology/toolkit-path.txt`

Portable project behavior then works like this:
- if `METHODOLOGY_HOME` is set, use it
- otherwise project flows can read `methodology/toolkit-path.txt`
- generated next-step commands should resolve through that toolkit home instead of a machine-specific path

## What This Methodology Is

This methodology is a project operating system for Codex-style software work.

Its job is to make project state recoverable from disk instead of relying on chat memory alone. It does that by combining:
- compact startup state
- explicit task lifecycle
- task-local execution workspaces
- visible verification
- visible handoff state
- optional multi-agent coordination
- runtime hygiene
- release, incident, and security discipline when the project needs it

The methodology is designed for:
- new software projects on Linux or WSL workstations
- existing repos that need a structured operating layer
- limited-context or non-persistent agent sessions

## Core Design Ideas

The methodology is built around a few rules:

1. Disk state beats chat memory.
   If work cannot be recovered from files in the repo, continuity is weak.

2. Machine state comes before long prose.
   `methodology-state.json` is the first startup surface for low-context sessions.

3. Hot docs stay small.
   `CORE_CONTEXT.md`, `WORK_INDEX.md`, `TASKS.md`, `SESSION_STATE.md`, and `HANDOFF.md` should stay compact.

4. Detailed execution state lives close to the task.
   Active task detail belongs in `methodology/work/<task-slug>/`.

5. Verification is part of the work, not a postscript.
   Work is not done just because code was written.

6. Methodology usage should be visible.
   Progress, readiness, handoff, risks, verification, and exceptions should be inspectable on disk.

7. Rigor should scale with risk and maturity.
   `prototype`, `product`, and `production` are intentionally different.

## Repo Layout

New methodology-managed projects are expected to look like this:

- root `AGENTS.md`
- root `methodology/`

The important layout rule is:
- `methodology/templates/FEATURE_SPEC_TEMPLATE.md` is the methodology feature-spec template source
- root `specs/` is reserved for repo-native specs or legacy feature-spec locations
- new methodology-generated feature specs live under `methodology/features/`

Inside `methodology/`, the most important surfaces are:
- startup and continuity docs
- task lifecycle docs
- runtime and verification docs
- risk, release, and governance docs
- task-local workspaces under `work/`
- claim records under `claims/`

## Operating States

The source repo classifies methodology artifacts into these states:

- `core`: default path; should be small and expected
- `conditional`: real and supported, but only when triggered
- `manual`: explicit opt-in helper or reference
- `experimental`: available, but not trusted as default
- `deprecated`: avoid for new work
- `template-only`: source template copied into project repos

The source-of-truth classification lives in [METHODOLOGY_REGISTRY.md](./METHODOLOGY_REGISTRY.md).

## Lifecycle Overview

The normal project lifecycle looks like this:

1. Create or adopt a repo.
2. Initialize methodology and git.
3. Enter through the methodology startup flow.
4. Identify the active task and active task workspace.
5. Run a preflight before substantial implementation.
6. Read the linked feature spec for non-trivial work and treat it as read-only unless the user explicitly asks for a spec change.
7. Create or refresh a sprint contract for the current implementation slice.
8. Implement, verify, checkpoint, and keep state visible.
9. Finish the task when it is truly done.
10. Move to the next task when appropriate.

## Startup Paths

### New Project

Use:

```bash
./init-project.sh /path/to/project
```

This will:
- create the project directory if needed
- initialize git if missing
- bootstrap the methodology

### Existing Repo Adoption

Use:

```bash
./adopt-methodology.sh /path/to/project
```

This will:
- initialize git if missing
- add missing methodology files
- infer the repo structure
- rehydrate the project state

### Standard Entry / Resume

Use:

```bash
./methodology-entry.sh /path/to/project
```

This is the standard entry flow for both new and existing methodology-managed repos.

It is responsible for:
- ensuring methodology exists
- ensuring git exists
- refreshing machine and human startup state
- rebuilding compact startup context
- recording a visible start checkpoint

## Git Behavior

Git is mandatory for methodology-managed projects.

That means:
- project creation initializes git automatically
- adoption initializes git if it is missing
- bootstrapping also initializes git if needed

The methodology does not push automatically.

The current explicit “done / continue” helpers create local commits only:
- `finish-task.sh`
- `next-task.sh`

They do not run `git push`.

## Startup Profiles

The methodology supports three startup profiles:

- `minimal`
  - machine state
  - core context
  - work index
  - active task workspace
  - active spec

- `normal`
  - the standard default flow

- `deep`
  - the normal flow plus heavier architecture/runtime docs

The reason for profiles is simple: agents should not load the whole repo methodology when the session only has room for the current slice.

## Core State Surfaces

### `methodology-state.json`

This is the first machine-readable startup surface.

It should carry enough information for a low-context agent to answer:
- what repo is this
- what work type is active
- what task is active
- what task state is active
- where the active workspace is
- what spec is active
- what risk/release state is active
- whether hotfix mode is active

This file is refreshed by:
- `refresh-methodology-state.sh`

### `CORE_CONTEXT.md`

This is the compact human startup summary.

It should stay short and answer:
- what the repo is
- what the active work is
- what the next important decision is
- what the current constraints/risks are

This file is refreshed by:
- `refresh-core-context.sh`

### `WORK_INDEX.md`

This is the compact index of active task workspaces.

It should tell an agent:
- which task workspace is active
- where to find detailed task state

### `TASKS.md`

This is lifecycle truth.

It is the high-level task list and should track:
- `planned`
- `ready`
- `in_progress`
- `blocked`
- `done`
- `cancelled`

### `SESSION_STATE.md`

This is the compact top-level “what is happening now” summary.

It should not become a narrative history.

### `HANDOFF.md`

This is the compact top-level resume guide.

It should capture:
- what was completed
- what remains
- verification already run
- current blockers or risks
- exact next step

## Task-Local Workspaces

Each meaningful active task should have a task workspace:

```text
methodology/work/<task-slug>/
```

Important files inside that workspace:
- `TASK.json`
- `STATE.md`
- `HANDOFF.md`
- `SPRINT_CONTRACT.md`

### `TASK.json`

This is the canonical task metadata source when it exists.

It should be preferred for:
- active spec path
- task state
- risk class
- release metadata

Top-level summaries should prefer generating from this metadata rather than reparsing markdown.

### `STATE.md`

This is detailed task execution truth.

It should capture:
- current implementation objective
- touched files
- verification state
- blocker state
- exact next step

### `HANDOFF.md`

This is the task-local resume artifact.

It should be more detailed than the top-level handoff, but still compact.

### `SPRINT_CONTRACT.md`

This bridges a high-level feature spec into one concrete implementation slice.

It should define:
- what this sprint delivers
- what is out of scope
- how evaluation will work
- pass thresholds
- failure conditions

The template source for this is:
- `work/SPRINT_CONTRACT_TEMPLATE.md`

## Source-of-Truth Hierarchy

When docs disagree, follow this order:

1. `TASKS.md` for lifecycle truth
2. `WORK_INDEX.md` for active-workspace pointer truth
3. task `STATE.md` for execution truth
4. task `HANDOFF.md` for resume truth
5. `ACTIVE_CLAIMS.md` plus claim files for ownership truth
6. `LOCAL_ENV.md` for runtime truth
7. `HOTFIX.md` for hotfix override truth

This hierarchy exists to stop agents from improvising reconciliation rules mid-session.

## Work Types

The methodology supports these work types:

- `product`
- `maintenance`
- `infra`
- `incident`
- `template_source`

This matters because not every task needs the same business context.

For example:
- `product` work expects business owner, target metric, customer signal, and review date
- `infra` work still needs risk, release, runtime, and verification context, but product-market fields may not fit

## Maturity Modes

The methodology supports:

- `prototype`
- `product`
- `production`

These change how much rigor is expected.

### `prototype`

Favor speed and a lighter working surface.

### `product`

Balanced delivery rigor.

### `production`

Stricter verification, security, release, incident, and service-ownership discipline.

The declared mode lives in:
- `METHODOLOGY_MODE.md`

Mode enforcement is checked by:
- `mode-check.sh`

## Feature Specs

For non-trivial work, the methodology expects a feature spec.

New methodology-managed specs live under:

```text
methodology/features/
```

The source template lives at:
- `templates/FEATURE_SPEC_TEMPLATE.md`

The spec should cover, as appropriate:
- user story
- scope
- design basis
- why now
- customer evidence
- success metric
- risk class
- experiment plan
- rollout plan
- rollback plan
- architecture/schema/API impact
- data sensitivity/compliance impact
- AI / agent evaluation and tool policy
- edge cases
- acceptance criteria
- verification plan

For non-trivial user-facing UI work, the intended flow is:
- use Stitch MCP first to establish or refine the design basis
- when using the Stitch web UI directly, prefer Stitch `Thinking with 3.1 Pro` / Gemini 3.1 Pro when that mode is available
- when using Stitch MCP, prefer the default supported model unless the exact accepted `modelId` has been verified in the current environment
- use Stitch `3 Flash` only for explicitly speed-first iterations and `Redesign` only for screenshot-based redesign flows
- then use `frontend-design` for the frontend implementation and polish pass when that skill is available
- record both the design-basis origin and any meaningful implementation/aesthetic deviations in the spec

Feature specs are created by:
- `new-feature.sh`

## Ready and Done Gates

### Definition of Ready

Non-trivial implementation should not start until the task is truly ready.

This is documented in:
- `DEFINITION_OF_READY.md`

Typical ready checks include:
- clear lifecycle state
- spec exists
- success metric exists
- risk or blast radius is known
- security/privacy trigger is known when needed
- instrumentation plan exists when runtime signals matter
- verification path is known
- rollback ownership exists for risky work

Checked by:
- `ready-check.sh`

### Definition of Done

Work is not done just because code compiles.

This is documented in:
- `DEFINITION_OF_DONE.md`

Done usually includes:
- behavior implemented
- acceptance criteria satisfied
- verification run and recorded
- manual QA handoff when meaningful
- docs/specs updated if behavior changed
- monitoring/support notes updated when relevant
- release/customer comms prepared when relevant

## Verification

Verification is one of the strongest parts of the methodology.

Important files:
- `VERIFICATION_LOG.md`
- `MANUAL_CHECKS.md`
- `COMMANDS.md`

Important script:
- `verify-project.sh`

### Web UI

Browser automation is first-class for web behavior changes.
When browser automation uses `playwriter` autonomously, prefer `./playwriter-ready-session.sh` or a stable project-root wrapper in `scripts/` that uses the same pattern.
That path launches a dedicated automation profile, auto-loads the bundled Playwriter extension when available, and establishes a usable session immediately instead of depending on an idle visible-profile extension connection.
Use `./launch-playwriter-brave.sh` as the manual bring-up/debug helper when you intentionally want to inspect the browser process or reuse a visible profile.
Treat Playwriter extension installation or enablement in a visible manual profile as a one-time bootstrap step, not as a repeated manual step during normal verification.
The methodology should keep the Playwriter CLI updated automatically through `./ensure-playwriter-cli.sh`, and the ready-session/bootstrap path should run that updater before Playwriter-based browser automation by default.
That Playwriter automation path is also allowed to ignore localhost certificate errors so HTTPS localhost pages remain automatable without mutating the user's normal browsing habits outside that launched profile.
When the browser target is a local HTML file, report, or generated page, use `./serve-local-page.sh` so browser automation works through localhost instead of raw `file://` navigation. The helper defaults to HTTPS, and the Playwriter launcher may use localhost HTTP fallback when the current browser-automation environment still rejects the local HTTPS certificate.
When the Playwriter self-launch path is uncertain, run `./playwriter-self-check.sh` first. That gives one compact check for Brave, the Playwriter CLI, extension detection, the local-file bridge, ready-session bootstrap, and smoke navigation.

## User Context

Run the methodology as the normal project user by default.

Use `sudo` or a root shell only when the work is genuinely system-level, such as:
- package installation or machine administration
- fixing ownership or permission damage from earlier root work
- other host-level operations outside the normal project workflow

Do not normalize “always work as root” into the methodology. The steady-state path should keep project files, generated outputs, browser profiles, and runtime state owned by the regular project user.

### Methodology Source Work

When changing the methodology source repo itself, use `./methodology-source-work.sh start` before substantial work and `./methodology-source-work.sh finish` afterward.
When the methodology-source change is actually done and ready to close out, use `./methodology-source-work.sh commit` so the standalone methodology source repo is refreshed, staged, and committed directly.

That wrapper keeps the control-surface docs visible in the checkpoint and makes the proof model explicit:
- source repo proves toolkit correctness
- dogfood repo proves lived workflow behavior

### Mobile App

Full native Appium verification is first-class for mobile behavior changes.
Partial device checks do not count as the methodology default.

### Manual QA

Manual handoff should include:
- what changed
- what files changed
- what was already verified
- exact commands to run
- what the human should check

Manual readiness labels are:
- `warm-env verified`
- `cold-start verified`
- `partially verified`

## Runtime Truth

`LOCAL_ENV.md` is the local runtime contract.

It should define:
- canonical dev database
- whether the DB is disposable
- required background services
- emulator/simulator expectations
- expected ports
- cleanup/reset commands
- ownership-sensitive outputs
- schema-mismatch triage steps

When local state matters, it should also define:
- named runtime profiles
- fresh-runtime launch/reset scripts
- warm-runtime launch/reset scripts

`COMMANDS.md` should point to stable script entrypoints for repeated commands.

If a command is expected to be run repeatedly by the user or team, it belongs in:

```text
scripts/*.sh
```

not only in docs or chat.

## Multi-Agent Work

The methodology supports multi-agent work, but it should be deliberate.

### Delegation Policy

The default stance is a second pair of eyes for meaningful work. Use full multi-agent decomposition only when the work is parallelizable, cross-stack, risky, or time-sensitive.

However:
- if `AGENT_TEAM.md` sets `Delegation policy: single_agent_by_platform_policy`
- single-agent execution is allowed without repetitive exception noise

### Team Shape

Common roles are:
- Lead
- Spec
- Explorer
- Builder
- Verifier
- Reviewer
- Ops

The active split belongs in:
- `MULTI_AGENT_PLAN.md`

### Claims

Ownership is tracked in:
- `ACTIVE_CLAIMS.md`
- `claims/<claim-id>.md`
- `claims/<claim-id>.json`

Claims should carry:
- lease
- heartbeat
- based-on commit
- ownership
- merge readiness

Helpful scripts:
- `claim-work.sh`
- `stale-claims-check.sh`
- `claim-diff-check.sh`
- `worker-context-pack.sh`
- `agent-merge-check.sh`

### Harness Escalation

The methodology explicitly supports three harness levels:

- `light harness`
  - trivial or tightly bounded work

- `standard harness`
  - normal non-trivial work

- `heavy harness`
  - long-running, risky, search-heavy, or highly subjective work

Do not assume every task needs:
- a 3-agent harness
- 5-15 iterations
- multi-hour autonomous loops

## Observable Compliance

The methodology wants process to be visible on disk.

Before substantial work, the agent should visibly establish:
- which methodology files were loaded
- the work type
- the active task
- the task state
- the active workspace path
- the relevant spec path for non-trivial work
- the intended verification path

For meaningful product work, visible compliance should also include:
- business owner
- target or leading metric
- customer signal
- decision date
- risk class
- release risk

This policy is documented in:
- `OBSERVABLE_COMPLIANCE.md`

Helpful scripts:
- `begin-work.sh`
- `progress-checkpoint.sh`
- `observable-compliance-check.sh`

## Business, Risk, and Governance

The methodology is not only about coding hygiene.

Important files:
- `PROJECT_BRIEF.md`
- `ROADMAP.md`
- `DECISIONS.md`
- `RISK_REGISTER.md`
- `BLOCKERS.md`
- `PROCESS_EXCEPTIONS.md`
- `MILESTONES.md`
- `PROJECT_HEALTH.md`
- `METRICS.md`

### Project Brief

The brief should carry:
- work type
- hypothesis
- problem
- target user
- success metric
- leading metric
- guardrail metrics
- business owner
- why now
- customer evidence
- expected business impact
- confidence
- effort / complexity
- decision deadline
- stakeholders / approvers
- constraints
- non-goals
- if this succeeds / fails
- kill criteria
- review date

### Risk Rubric

The methodology uses `R0` to `R3` style risk classes.

This should stay consistent across:
- specs
- approvals
- readiness
- release decisions
- process exceptions

### Process Exceptions

`PROCESS_EXCEPTIONS.md` is where methodology deviations are made explicit.

It should include:
- reason
- risk level
- compensating control
- approver
- expiry
- CI effect after expiry
- evidence of backfill

## Experiments

For hypothesis-driven work, use:
- `EXPERIMENTS.md`
- `EXPERIMENT_LOG.md`

Each meaningful experiment should define:
- hypothesis
- owner
- primary metric
- baseline
- success threshold
- time-to-signal
- max budget / max runs
- stop rule
- rollback rule

Do not promote experiment output into standard behavior until:
- it beat baseline
- the result was recorded in `EXPERIMENT_LOG.md`

Created by:
- `new-experiment.sh`

## Security, Releases, and Incidents

### Security

Use:
- `SECURITY_NOTES.md`
- `security-review.sh`

Security review becomes important for work touching:
- auth
- payments
- PII
- secrets
- external integrations

### Releases

Use:
- `RELEASE_NOTES.md`
- `release-cut.sh`

### Incidents and Hotfixes

Use:
- `INCIDENTS.md`
- `HOTFIX.md`
- `enter-hotfix.sh`
- `incident-open.sh`
- `incident-close.sh`

If runtime stabilization interrupts planned work, the methodology expects the repo to visibly switch into hotfix mode instead of pretending roadmap work is still primary.

## Finish / Continue Flow

There is now an explicit local git-backed finish/continue path.

### Finish a Truly Done Task

Use:

```bash
./finish-task.sh /path/to/project
```

This flow is meant for:
- the task is actually done
- verification is in place
- you are not saying “done, but one more fix remains”

It will:
- run the end-of-task flow
- refresh methodology state
- create a local git commit if there are changes

### Continue to the Next Ready Task

Use:

```bash
./next-task.sh /path/to/project
```

This will:
- move the next ready task into progress
- record the visible start checkpoint
- create a local git commit if there are changes

These helpers do not push automatically.

## Reset vs Compaction

The methodology distinguishes:
- compacting the same working agent
- resetting to a fresh agent with a strong handoff

Use compaction when:
- continuity is still good
- you just need a smaller context

Prefer a fresh-agent reset when:
- the task is long-running
- coherence is drifting
- the same agent is repeatedly losing the thread
- a clean evaluator pass is more valuable than carrying forward the same context

## Archiving and Cold Docs

When inactive docs become too large for the hot path:
- use `archive-cold-docs.sh`
- keep short stubs at the old paths
- use `DOCS_ARCHIVE.md` and `docs-archive-index.json` for lookup

Before opening archived docs directly, prefer:

```bash
./lookup-archived-doc.sh --query "..."
```

## Source Repo vs Project Repo

This methodology repo is a source repo.

That means:
- many files here are templates
- the templates become live only after they are copied into a project

This is why the source repo uses:
- `METHODOLOGY_REGISTRY.md`
- registry validation
- `template_source` mode

The source repo should stay strict about:
- registry coverage
- bootstrap correctness
- idempotent adoption
- startup flow reliability

## Most Useful Commands

### Start or adopt

```bash
./init-project.sh /path/to/project
./adopt-methodology.sh /path/to/project
./methodology-entry.sh /path/to/project
```

### Readiness and execution

```bash
./work-preflight.sh /path/to/project
./begin-work.sh --task "Task title" --state in_progress /path/to/project
./progress-checkpoint.sh --summary "What changed" /path/to/project
./verify-project.sh /path/to/project
```

### Task lifecycle

```bash
./new-feature.sh --title "Feature title" /path/to/project
./move-task.sh --task "Feature title" --to ready /path/to/project
./finish-task.sh /path/to/project
./next-task.sh /path/to/project
```

### Multi-agent

```bash
./claim-work.sh --task "Task title" --agent "builder" --files "app/api.ts,app/ui.tsx" /path/to/project
./worker-context-pack.sh --claim-id claim-... /path/to/project
./claim-diff-check.sh /path/to/project
./agent-merge-check.sh /path/to/project
```

### Hotfix / release / audit

```bash
./enter-hotfix.sh --summary "..." --interrupted-task "T-014" /path/to/project
./release-cut.sh /path/to/project
./methodology-audit.sh /path/to/project
./methodology-status.sh /path/to/project
```

## When To Improve The Methodology

Improve the methodology when real work repeatedly shows:
- recurring drift
- repeated missing state
- unclear startup behavior
- weak verification behavior
- avoidable handoff failures
- noisy, low-value checks
- friction that appears across projects, not just one repo

Prefer:
- the smallest useful change
- updating docs and automation together
- strengthening existing paths before adding new surfaces

## Reading Order

If you are onboarding to the methodology itself, use this reading order:

1. `README.md`
2. `OPERATING_MANUAL.md`
3. `METHODOLOGY_REGISTRY.md`
4. `AGENTS.md`
5. the relevant template or helper for the workflow you care about

If you are entering a real project that uses the methodology, use this order instead:

1. `methodology-state.json`
2. `CORE_CONTEXT.md`
3. `WORK_INDEX.md`
4. the active task workspace
5. the active feature spec
6. additional docs only when needed
