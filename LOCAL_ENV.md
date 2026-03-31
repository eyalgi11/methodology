# Local Environment Contract

Use this file to define the canonical local runtime contract for the project.

## Core Environment
- Canonical dev database name:
- Is the dev database disposable?
- Canonical cache / queue services:
- Required background services:
- Expected local ports:
- Port ownership expectations:
- Required env files / env vars:

## Runtime Profiles
- Available runtime profiles:
- Fresh runtime profile:
- Warm runtime profile:
- Fresh runtime launch script:
- Warm runtime launch script:
- Runtime profile selection notes:

## Device / UI Expectations
- Browser expectations:
- Browser automation profile:
- Browser automation bootstrap notes:
- Browser automation localhost HTTPS certificate note:
- Local page localhost HTTPS command:
- Local page localhost HTTP fallback command:
- Emulator / simulator expectations:
- Native build expectations:

## Health / Preflight Checks
- Database running check:
- Cache / queue running check:
- API health check:
- Web / mobile shell health check:

## Cleanup / Reset
- Stale-process cleanup commands:
- Port cleanup commands:
- Build-output cleanup commands:
- Emulator / simulator reset commands:
- Dev-only rate-limit or auth-cooldown reset commands:
- Fresh runtime reset command:

## Ownership / Permissions
- Expected project user:
- Generated directories that must stay editable:
- Ownership normalization command:

## Schema Mismatch Triage
- Live DB schema check:
- Applied migration history check:
- Expected schema from source check:
- Reset-vs-migrate rule:

## Notes
- Project-specific local runtime assumptions and traps:
