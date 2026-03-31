# Methodology Principles

This file is the shortest statement of what the methodology is trying to do.

If a more detailed document, helper, or habit conflicts with these principles, these principles win.

## Purpose

The methodology exists to make agent work:
- visible
- auditable
- verifiable
- recoverable after context loss
- aligned with the user's intent instead of the agent's private assumptions

It should feel like a small operating system for software work, not a pile of templates.

## Non-Negotiables

- Keep active task state visible on disk, not only in chat.
- Verify meaningful work before calling it done.
- Keep startup and resume deterministic.
- Keep the current task, next step, and verification path easy to find.
- Keep the methodology compact enough that the user can understand what it is doing.
- Keep specs read-only unless the user explicitly asks for a spec change.
- Do not silently change product scope, design intent, or acceptance criteria.
- Do not hide uncertainty about what was actually tested, verified, or assumed.
- Do not call work fixed, done, or stable more strongly than the current verification really supports.
- Do not leave the project in a root-owned or hard-to-edit state.

## What The Methodology Must Always Do

- establish the current task and task state from files on disk
- preserve continuity through compact summaries and task-local state
- make meaningful progress checkpoints visible
- keep a clear done gate with real verification
- make risky deviations explicit through exceptions instead of silently normalizing them

## What The Methodology Must Never Do Without Explicit User Approval

- edit a feature spec
- change product intent
- treat warm-environment checks as cold-start verification
- perform destructive or hard-to-reverse actions that were not requested
- pretend multi-agent work is happening when it is not actually visible

## Decision Rule

When in doubt, prefer:
1. smaller default behavior
2. clearer visibility
3. stronger verification
4. less silent interpretation

The methodology should help the user control the work, not make the user guess what the methodology decided on their behalf.

## Confidence Language

Use confidence language precisely:
- `implemented` means the code or docs changed
- `verified` means the target path was actually tested successfully
- `stable` means the target path passed repeated or cross-path verification, not just one hopeful run

If the methodology has not reached the stronger bar yet, it should say so plainly.
