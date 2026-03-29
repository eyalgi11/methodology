# Agent Team

## Startup Role Model
- Lead:
  - Owns user communication, prioritization, decomposition, integration, and final decisions.
- Spec:
  - Turns goals into brief/spec/task updates, acceptance criteria, and open questions.
- Explorer:
  - Maps the codebase, impact surface, architecture fit, and risks before or during implementation.
- Builder:
  - Implements bounded code changes in owned files.
- Verifier:
  - Runs tests, browser automation, device automation, and acceptance checks.
- Reviewer:
  - Reviews for bugs, regressions, edge cases, and methodology drift.
- Ops:
  - Updates release notes, verification logs, incidents, metrics, and project health.

## Minimum Team Shapes
- Trivial task:
  - Single agent is acceptable.
  - Prefer Lead only or Lead + Reviewer when a second pass is useful.
- Small task:
  - Lead + one complementary agent
  - Preferred complementary role: Reviewer or Verifier
- Standard feature slice:
  - Lead + Builder + Verifier
- Discovery / greenfield planning:
  - Lead + Spec + Explorer
- Cross-stack feature:
  - Lead + frontend Builder + backend Builder + Verifier + Reviewer
- Stabilization / pre-release:
  - Lead + Verifier + Reviewer + Ops

## Team Selection Rules
- Trivial task:
  - One agent is acceptable without treating it as a methodology failure.
- Standard task:
  - Use Lead + Reviewer or Verifier when the work is bounded and low-risk.
- Cross-stack or risky task:
  - Use Lead + Builder + Verifier at minimum.
- Release, incident, or hotfix work:
  - Use Lead + Verifier + Reviewer + Ops whenever practical.
- Default to a second pair of eyes for meaningful work.
- Use full multi-agent decomposition when work is parallelizable, cross-stack, risky, or time-sensitive.

## Harness Escalation Policy
- `Light harness`:
  - Use for trivial or tightly bounded work with fast verification.
  - Typical shape: 1 agent or Lead + one complementary pass.
  - Typical iteration count: 1-3 loops.
- `Standard harness`:
  - Use for normal non-trivial feature, product, or cross-stack work.
  - Typical shape: Builder + Verifier or Reviewer, with a Lead on the critical path.
  - Typical iteration count: enough to meet the sprint contract and pass thresholds, not a fixed large loop count.
- `Heavy harness`:
  - Use only when work is long-running, risky, search-heavy, or highly subjective, such as major UI/design exploration, agent behavior tuning, or complex release stabilization.
  - Typical shape: 3+ agents with explicit generator/evaluator separation.
  - Multi-hour autonomous loops are allowed only when the eval path, rollback path, and stop conditions are explicit.
- Do not default every task to a heavy 3-agent harness, 5-15 iterations, or multi-hour autonomous loops.
- Escalate the harness only when the expected search space, ambiguity, or risk justifies the extra cost.

## Shared Risk Rubric
- `R0`: local/dev-only, reversible, no persistent user impact
- `R1`: internal or easily reversible product change
- `R2`: customer-facing, migration-heavy, or persistent data impact
- `R3`: security, payments, auth, prod stability, or legal/compliance risk

## Mode And Risk Team Policy
| Mode | Risk | Default team shape |
| --- | --- | --- |
| `prototype` | `R0-R1` | single agent allowed |
| `prototype` | `R2-R3` | Lead + Verifier or Reviewer |
| `product` | `R0-R1` | Lead + Verifier or Reviewer |
| `product` | `R2-R3` | Lead + Builder + Verifier |
| `production` | `R0-R1` | Lead + Verifier |
| `production` | `R2-R3` | Lead + Builder + Verifier + Reviewer + Ops |

## Execution Policy
- Delegation policy: `multi_agent_default`
- Use `single_agent_by_platform_policy` when the runtime or platform forbids delegation unless the user explicitly asks for it.
- Reason:

## Approval Matrix
| Decision | Responsible | Approver | Notes |
| --- | --- | --- | --- |
| Move `R0-R1` task to `done` | Lead | Lead | Low risk means low blast radius, no schema/API risk, and fast verification. |
| Move `R2-R3` task to `done` | Lead | Lead + Reviewer or Verifier | Required for migrations, customer-visible breaking change, or higher blast radius. |
| Verification skip | Lead | Lead + Verifier | Must be recorded in `PROCESS_EXCEPTIONS.md`. |
| Process exception | Lead | Lead + Reviewer | Record approver and expiry. |
| Exit hotfix mode | Lead | Lead + Verifier | Runtime stabilization must be verified first. |
| Cut release | Ops | Lead + Verifier | Use release notes plus verification evidence. |
| Approve schema / data migration | Lead | Lead + Reviewer | Rollback path, risk class, and blast radius must be explicit. |
| Accept security waiver | Lead | Lead + Ops | Also record in `SECURITY_NOTES.md` and `PROCESS_EXCEPTIONS.md`. |
| Approve user behavior / pricing / access change | Lead | Lead + Business Owner | Use customer communication and rollout notes. |
| Approve operator-impacting migration or support-heavy release | Lead | Lead + Ops | Runbook/support note must be ready. |
| Scope cut or kill on major feature | Lead | Lead + Business Owner | Use kill criteria and business impact from `PROJECT_BRIEF.md`. |

## Escalation Rules
- If claims conflict or overlap, the Lead resolves ownership before further edits continue.
- If blocked work stays unresolved beyond one work session, escalate it into `BLOCKERS.md` and the active handoff.
- If a worker cannot finish safely from its current base, it must hand off instead of improvising merge policy.

## Operating Rules
- Default to multi-agent execution for all meaningful Codex work.
- If `Delegation policy` is `single_agent_by_platform_policy`, single-agent execution is acceptable until the user explicitly asks for delegation or sub-agents.
- At minimum, every meaningful task should use:
  - one Lead
  - one complementary agent
- Use `MULTI_AGENT_PLAN.md` to map actual assignments for the current task.
- Use `ACTIVE_CLAIMS.md` for live file and task ownership.
- If a non-trivial task must collapse to single-agent execution, record the reason in `PROCESS_EXCEPTIONS.md`.
