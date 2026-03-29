# Feature Spec

## Why Now
- Why is this worth doing now?

## Customer Evidence
- Linked request, ticket, interview, bug trend, analytics signal, or incident:

## Design Basis
- Stitch required for this work? yes / no
- Stitch prompt or design direction:
- Stitch screen or project reference:
- Existing design system or product constraints to preserve:
- Intentional deviations from the Stitch-generated design:

## User Story
- As a ...
- I want ...
- So that ...

## Scope
- In scope:
- Out of scope:

## Success Metric
- Primary outcome:
- Leading indicator or proxy:

## Risk Classification
- Risk class: `R0` / `R1` / `R2` / `R3`
- Why this class fits:

## Experiment Plan
- Hypothesis:
- Baseline:
- Success threshold:
- Time-to-signal:
- Max budget / max runs:
- Stop rule:
- Promotion gate:
  - Do not promote this to standard behavior until it beats the baseline and is recorded in `EXPERIMENT_LOG.md`.

## Release / Rollout
- Launch owner:
- Release risk: low / medium / high
- Rollout type: full / staged / canary
- Rollout plan:
- Rollback plan:
- Blast radius if this fails:
- Customer-facing communication needed:

## Edge Cases
- What non-happy-path behavior matters?

## Architecture / Data Impact
- Architecture, API, schema, or migration impact:
- Data sensitivity / privacy / compliance impact:
- Support / migration notes:

## AI / Agent Evaluation
- Model / provider / version:
- Golden task or eval set:
- Pass threshold:
- Fallback behavior:
- Max cost / latency budget:
- Allowed tools:
- Confirmation-required tools:

## Acceptance Criteria
<!-- Add concrete checklist items for this feature. -->

## Evaluator Criteria
- UI / design quality:
- Originality / deliberate choices:
- Craft / technical polish:
- Usability / task clarity:
- Product depth:
- Functionality:
- Code quality:
- Runtime reliability:

## Verification Plan
- Tests:
- Integration hardening checks:
- Local environment assumptions:
- Manual checks:
  - Readiness label: `warm-env verified` / `cold-start verified` / `partially verified`
  - Cold-start verified from zero running processes:
  - Expected first-success output:
  - Prerequisites:
  - Dependency preflight checks:
  - App health-check:
  - Expected local ports:
  - Likely networking traps:
  - Human/manual check instructions to give the user:
- Browser / web automation checks:
  - Canonical capability: browser automation.
  - Use `playwriter`, Playwright, or an equivalent browser automation workflow when changed files touch web UI behavior or browser behavior matters.
  - If skipped for relevant web UI work, record the reason in `PROCESS_EXCEPTIONS.md`.
- Mobile / device checks:
  - Canonical capability: mobile automation.
  - Use full native Appium verification when changed files touch mobile app/device behavior or device behavior matters.
  - Partial device checks or smoke checks do not satisfy this requirement.
  - Prefer `appium-mobile` or an equivalent native Appium run command.
  - If skipped for relevant mobile work, record the reason in `PROCESS_EXCEPTIONS.md`.
- Desktop app automation checks:
  - Canonical capability: desktop automation.
  - Use Playwright/Electron when changed files touch browser-tech desktop app behavior.
  - Use native desktop automation such as Appium Mac2 or Windows driver / WinAppDriver when changed files touch native desktop app behavior.
  - If skipped for relevant desktop work, record the reason in `PROCESS_EXCEPTIONS.md`.
- Observability or logging checks:
- Release / post-release checks:
- Follow-up stabilization task needed after feature-complete? yes / no

## Sprint Contract Guidance
- For the next implementation chunk, create or refresh `methodology/work/<task-slug>/SPRINT_CONTRACT.md`.
- The sprint contract should define:
  - sprint goal
  - in-scope vs out-of-scope work
  - what done means for this chunk
  - evaluator test plan
  - pass thresholds
  - failure / return conditions

## Post-Launch Review
- Review date:
- Review owner:
- Expected metrics after launch:
- Actual metrics after launch:
- Incidents or regressions seen after launch:
- Support / customer feedback:
- Decision: keep / iterate / rollback / sunset
