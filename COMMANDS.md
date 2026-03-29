# Commands

<!-- Repeated workflows that the user or team will run regularly should live as bash scripts under project-root `scripts/` and be referenced here. Inline commands are for occasional or one-off use. -->

## Setup
- Install dependencies:
- Initialize local environment:
- Canonical dev database:
- Disposable DB reset command:
- Required background services:

## Run
- Fresh runtime launch script:
- Warm runtime launch script:
- Start app:
- Start backend:
- Start workers:
- Health / preflight command:

## Test
- Unit tests:
- Integration tests:
- End-to-end tests:
- Browser automation:
<!-- Required when changed files touch web UI behavior unless an exception is recorded in PROCESS_EXCEPTIONS.md. Canonical capability: browser automation. Accept playwriter, Playwright, or an equivalent browser automation command. -->
- Mobile automation:
<!-- Required when changed files touch mobile app/device behavior unless an exception is recorded in PROCESS_EXCEPTIONS.md. Canonical capability: mobile automation. This must be a full native Appium command or workflow, not a partial device smoke check. Prefer `appium-mobile` or an equivalent native Appium run command. -->
- Desktop automation:
<!-- Required when changed files touch desktop app behavior unless an exception is recorded in PROCESS_EXCEPTIONS.md. Canonical capability: desktop automation. Use Playwright/Electron for browser-tech desktop apps, or native desktop automation such as Appium Mac2 or Windows driver / WinAppDriver for native desktop apps. -->

## Quality
- Lint:
- Type-check:
- Format check:

## Build / Release
- Production build:
- Release command:

## Cleanup / Reset
- Stop stale local processes:
- Free expected ports:
- Clean generated build output:
- Reset emulator / simulator:
- Reset dev-only rate limits / auth cooldowns:
