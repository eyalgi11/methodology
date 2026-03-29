# Definition of Done

Work is done only when all applicable items below are true:

- Behavior is implemented and matches the agreed scope.
- Acceptance criteria are satisfied.
- Verification was run and recorded.
- For meaningful non-trivial work, an evaluator / verifier pass reviewed the sprint against its contract or criteria, or the reason for not doing so was recorded.
- Release risk, rollout path, and rollback path are documented for meaningful user-facing or risky work.
- For experiment-driven work, the keep / discard / inconclusive decision is recorded in `EXPERIMENT_LOG.md` before the result is treated as durable.
- Dashboard, metric, or alert links were updated when the shipped change depends on ongoing monitoring.
- Manual user handoff is not treated as cold-start ready unless it was actually verified that way from a clean local start.
- Files created or modified from a sudo/root shell remain editable from the normal non-sudo user shell.
- Generated runtime output stays editable from the normal project user shell.
- If changed files touch web UI behavior, browser automation was run and recorded, or the skip was recorded in `PROCESS_EXCEPTIONS.md`.
- If changed files touch mobile app or device behavior, full native Appium verification was run and recorded, or the skip was recorded in `PROCESS_EXCEPTIONS.md`.
- If changed files touch desktop app behavior, desktop automation was run and recorded, or the skip was recorded in `PROCESS_EXCEPTIONS.md`.
- Tests were added or updated when appropriate.
- Runbook or support note was updated when operators or customer support need new context.
- Post-launch review date is scheduled for meaningful user-facing or risky changes.
- Customer-facing communication is prepared when the release changes user behavior, access, pricing, or migrations.
- Support / migration notes were recorded when behavior change could affect operators, users, or data.
- If the slice is feature-complete but not integration-hardened, an explicit stabilization follow-up task exists before the slice is treated as fully hardened.
- Documentation or specs were updated if behavior changed.
- Important tradeoffs or architectural decisions were written down.
