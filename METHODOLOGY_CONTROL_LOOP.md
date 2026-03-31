# Methodology Control Loop

This file explains how the methodology should keep itself aligned with the user's intent.

Use it when the question is not "what files exist?" but "how do we keep the methodology from quietly deciding too much on its own?"

## Goal

The methodology should be:
- visible enough to audit quickly
- automatic enough to be followed reliably
- small enough that the user can tell what it is doing

The methodology should not depend on the agent remembering dozens of rules perfectly.

## Control Surface

These files are the shortest authority for what the methodology is supposed to do:
1. `METHODOLOGY_PRINCIPLES.md`
2. `DEFAULT_BEHAVIOR.md`
3. root `AGENTS.md`

If behavior in practice is not predictable from those files, the methodology is drifting.

## Mandatory Self-Check

Before and after meaningful work, the agent should be able to answer:
- what task is active
- what file is the source of truth for that task
- what verification path is being claimed
- what changed on disk
- what user-visible state was updated

If the agent cannot answer those questions quickly from disk state, the methodology is no longer controlling the work well enough.

For template-source work, the minimum loaded control surface should be visible on disk:
- `METHODOLOGY_PRINCIPLES.md`
- `DEFAULT_BEHAVIOR.md`
- `METHODOLOGY_CONTROL_LOOP.md`
- root `AGENTS.md`

## Automation Rule

Prefer automatic guardrails over "remember to" rules.

Good methodology behavior is:
- refreshed automatically when normal workflow commands run
- rendered visibly on disk
- checked by scripts instead of memory
- corrected by tooling when safe

Bad methodology behavior is:
- depending on the agent to remember hidden rituals
- requiring the user to guess whether a rule was followed
- silently leaving state stale until someone notices

## Pause-And-Realign Triggers

The agent should stop and surface the change before proceeding when:
- changing a default workflow
- changing spec behavior
- adding a new required rule
- adding a new always-on automation
- changing how completion or verification is judged
- the agent is no longer sure it is serving the user's intent rather than its own interpretation

In that pause, the agent should state:
- what is changing
- why it is changing
- what practical behavior will change
- what risk or tradeoff comes with it

## Dogfooding Rule

Use the methodology source repo to validate packaging and toolkit correctness.

Use a separate methodology-managed repo to validate lived workflow behavior.

That split keeps:
- source-repo checks focused on templates, bootstrap, migration, and registry correctness
- dogfood-repo checks focused on actual day-to-day usability

The methodology should say which kind of proof a claim is based on:
- `source proof` for toolkit and packaging correctness
- `dogfood proof` for lived workflow behavior

## Reduction Rule

When the methodology grows, prefer:
1. shrinking the default path
2. making optional layers more explicit
3. generating summaries instead of duplicating state
4. adding one stronger audit surface instead of many new docs

If a new rule cannot be explained simply in the control surface, it is probably not ready to be default behavior.

## Practical Audit Loop

The normal audit loop should be:
1. read `METHODOLOGY_PRINCIPLES.md`
2. read `DEFAULT_BEHAVIOR.md`
3. read root `AGENTS.md`
4. inspect `methodology/methodology-audit.html` when the repo is methodology-managed
5. compare what the dashboard says to what the control surface says

If the dashboard shows behavior the control surface would not predict, fix the methodology before adding more of it.

## Confidence Language Rule

When summarizing progress:
- say `implemented` when the change exists but the target path is not fully proven yet
- say `verified` only after the actual target path passed
- say `stable` only after repeated or stronger cross-path verification

If the verification is partial, flaky, or environment-biased, the methodology should say that directly instead of rounding up.
