# Claims

Detailed claim records should live here, one file per claim:

- `claims/<claim-id>.md`
- `claims/<claim-id>.json`

Keep `ACTIVE_CLAIMS.md` as the compact live index of current claims.

Each claim should carry:
- lease + heartbeat
- based-on commit
- exact files changed
- commands run
- result summary
- known risks
- integration notes
- ready-for-merge and rebase-required flags

Use `agent-merge-check.sh` before merge or handoff when claimed work needs one combined gate for stale leases, claimed-file ownership, merge readiness, and latest verification status.
