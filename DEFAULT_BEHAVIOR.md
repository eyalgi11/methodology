# Default Behavior

This file describes the normal methodology path.

If you want to know what the methodology will usually do without reading the whole toolkit, read this file first.

## Startup

For substantial work in a methodology-managed repo:
1. enter through `methodology-entry.sh`
2. read `methodology-state.json`
3. read `CORE_CONTEXT.md`
4. read `WORK_INDEX.md`
5. read `TASKS.md`, `SESSION_STATE.md`, and `HANDOFF.md`
6. identify the active task, workspace, spec path, and verification path
7. run `work-preflight.sh` when a short readiness/remediation summary is useful
8. stay in the normal project-user shell unless the work is genuinely system-level or needs ownership repair

If `work-preflight.sh` is flaky, unhelpful, or environment-blocked, the agent should not hand-wave past it.
The fallback is:
- run the equivalent underlying checks directly
- summarize the blockers or warnings explicitly
- record a process exception only when a real methodology step is being skipped

## During Work

For meaningful work, the methodology should:
- keep the active task visible
- keep the active workspace visible
- keep `SESSION_STATE.md` and `HANDOFF.md` current but compact
- keep detailed in-flight state in `methodology/work/<task-slug>/`
- treat the linked feature spec as the implementation contract
- keep specs read-only unless the user explicitly asks for a spec change
- record mismatches or drift outside the spec until the user approves a spec edit

## Verification

Before calling meaningful work done, the methodology should:
- run the intended verification path
- prefer full verification whenever the intended path is feasible in the current environment
- record what was actually verified
- use precise confidence language:
  - `implemented` when the change exists
  - `verified` when the target path passed
  - `stable` only when stronger repeated or cross-path verification exists
- distinguish warm-env, cold-start, and partial verification honestly
- use partial verification only when the full intended verification path is not feasible, and state the concrete reason
- include browser automation for web UI work unless explicitly skipped
- include full native Appium verification for mobile/device work unless explicitly skipped
- keep manual QA instructions short, explicit, and reproducible when human checking is possible

## Multi-Agent Default

The default is:
- a second pair of eyes for meaningful work

Full multi-agent decomposition is used only when:
- the work is parallelizable
- the work is cross-stack
- the work is risky
- the work is time-sensitive

If `Delegation policy: single_agent_by_platform_policy` is active, a single agent may proceed without being treated as non-compliant.

## Source vs Dogfood Proof

When the repo itself is the methodology source:
- prove template, script, bootstrap, migration, and registry correctness there
- do not treat source-repo checks alone as proof that the lived workflow feels right

When using the dogfood repo:
- prove task flow, handoff, verification, audit usability, and day-to-day ergonomics there
- prefer dogfood evidence when the question is about how the methodology feels in practice

## Finish A Task

When a task is truly complete and accepted:
1. update task state and handoff state
2. ensure verification is recorded
3. ensure manual QA instructions exist when relevant
4. use `finish-task.sh` if the repo uses that flow
5. create a local commit if there are changes

## Move To The Next Task

When the user explicitly wants to continue:
1. choose the next ready task
2. move it into progress
3. record the visible start checkpoint
4. use `next-task.sh` if the repo uses that flow
5. create a local commit if there are changes

## When The Methodology Should Ask For Help

The methodology should stop and ask before:
- destructive actions
- spec edits
- major scope changes
- risky approvals that are not clear from repo state
- actions that would create hidden product or operational consequences

When the methodology itself fails during normal work:
- record it in `METHODOLOGY_FAILURES.md`
- include the impact on work and the suggested improvement
- use `record-methodology-failure.sh` when you want a fast, structured log entry

## What Should Stay Optional

The methodology should not force advanced layers by default.

Use optional layers only when needed:
- multi-agent claims
- experiments
- release flow
- incidents
- security review
- archive tooling
- deeper dashboards and audits
