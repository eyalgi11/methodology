# Security Notes

## Risk Tier
- Does this work touch auth, payments, PII, secrets, or external integrations?
- If yes:
  - require security review
  - require data sensitivity note
  - require rollback note
  - require owner sign-off

## Data Sensitivity
- What sensitive data exists?

## Secrets Handling
- Where secrets live
- How secrets are injected locally and in production

## Secret Exposure Response
- If a live secret is pasted into chat, logs, screenshots, or commits:
  - treat it as compromised
  - stop echoing it
  - tell the user to rotate it
  - record follow-up remediation work

## Auth / Access Assumptions
- What trust boundaries and roles exist?

## Tool Access Policy
- Allowed tools:
- Confirmation-required tools:
- Disallowed or high-risk operations:
- Production-access policy:

## Compliance / Privacy Impact
- What compliance, privacy, or regulatory expectations matter?

## AI / Data Exposure Policy
- Model / provider / version:
- What data may be sent to models or tools:
- What data must never be sent:
- Retention / logging expectations:
- Fallback behavior if the preferred model or tool is unavailable:
- Abuse-sensitive or red-team cases:

## Security Approval / Waivers
- Security owner:
- Approved waivers:
- Waiver expiry:
- Rollback path for risky security changes:

## Abuse / Misuse Risks
- What could be abused and how is it limited?

## Open Security Work
- Pending hardening, reviews, or gaps
