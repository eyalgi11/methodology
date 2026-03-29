# Methodology Mode

- Mode: prototype
- Reason: Default starting mode for a new project until user impact, release cadence, or operational risk require more rigor.
- Upgrade triggers:
  - Move to `product` when there are external users, active release cadence, a shared team, or recurring cross-functional product work.
  - Move to `production` when uptime, customer data, security sensitivity, payments, or on-call responsibility exist.
  - Move to `template_source` only for the methodology/template source repo itself.

## Mode Guide

- `prototype`: fastest iteration, lighter verification and release expectations
- `product`: balanced rigor for active product work
- `production`: strict verification, security, release, and incident discipline
- `template_source`: methodology/template repo mode; placeholder template content is expected

## Expected Rigor

- `prototype`:
  - project brief, tasks, and continuity docs should be current
  - basic runnable commands should exist
  - minimum docs: `PROJECT_BRIEF.md`, `TASKS.md`, `SESSION_STATE.md`, `HANDOFF.md`, `COMMANDS.md`, `LOCAL_ENV.md`
  - bootstrap defaults to the lighter core surface; generate broader docs on first use or with `--surface full`
  - metrics can be proxy-level, but at least one feature outcome should be named
  - business owner, why-now context, and at least one customer or problem signal should still be recorded
  - team policy: single-agent is acceptable for `R0-R1`; use at least Lead + Verifier/Reviewer for `R2-R3`
  - automation emphasis: keep the path light; helper scripts remain mostly optional
- `product`:
  - verification should pass before closing meaningful work
  - required additions over prototype: `ARCHITECTURE.md`, `DECISIONS.md`, `VERIFICATION_LOG.md`, `MANUAL_CHECKS.md`
  - metrics should contain real targets and current status
  - release notes should track user-visible changes
  - project brief should include business owner, expected business impact, and review date
  - feature specs should include rollout/rollback thinking for meaningful user-facing work
  - team policy: default to Lead + Verifier/Reviewer for `R0-R1`; use Lead + Builder + Verifier for `R2-R3`
  - automation emphasis: begin-work, lifecycle helpers, verification logging, and weekly review should be treated as normal operating behavior
- `production`:
  - product-mode expectations still apply
  - required additions over product: `METRICS.md`, `INCIDENTS.md`, `RELEASE_NOTES.md`, `SECURITY_NOTES.md`, `MILESTONES.md`, `DEPENDENCIES.md`
  - security review, dependency review, and decision review should pass
  - incident discipline and release hygiene should be maintained
  - release risk, rollout type, rollback path, support readiness, and service-level expectations should be explicit
  - team policy: even `R0-R1` work should have a second pair of eyes; `R2-R3` work should use Lead + Builder + Verifier + Reviewer + Ops
  - automation emphasis: release-cut, incident discipline, security review, expired-exception enforcement, and stronger approval discipline should be active
- `template_source`:
  - placeholder template content is allowed
  - focus on template integrity, script validity, and bootstrap behavior
  - do not treat intentionally blank templates as missing project execution state
