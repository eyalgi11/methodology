#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: enter-hotfix.sh --summary "text" [options] [target-directory]

Enters or updates runtime hotfix mode and makes the interruption visible in
HOTFIX.md, TASKS.md, SESSION_STATE.md, and HANDOFF.md.

Options:
  --summary TEXT
  --interrupted-task TEXT
  --status TEXT              active or resolved. Default: active
  --reproduction TEXT
  --root-cause TEXT
  --fix TEXT
  --exit-criteria TEXT
  --next-step TEXT
  -h, --help
EOF
}

target_arg=""
summary=""
interrupted_task=""
status="active"
reproduction=""
root_cause=""
fix_note=""
exit_criteria=""
next_step=""

while (($# > 0)); do
  case "$1" in
    --summary) summary="$2"; shift 2 ;;
    --interrupted-task) interrupted_task="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --reproduction) reproduction="$2"; shift 2 ;;
    --root-cause) root_cause="$2"; shift 2 ;;
    --fix) fix_note="$2"; shift 2 ;;
    --exit-criteria) exit_criteria="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

if [[ -z "$summary" ]]; then
  echo "--summary is required." >&2
  usage >&2
  exit 1
fi

if [[ "$status" != "active" && "$status" != "resolved" ]]; then
  echo "--status must be 'active' or 'resolved'." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
hotfix_path="$(project_file_path "$target_dir" "HOTFIX.md")"
[[ -f "$hotfix_path" ]] || cp "$SCRIPT_DIR/HOTFIX.md" "$hotfix_path"

current_next_step="${next_step:-$summary}"
if [[ "$status" == "active" ]]; then
  current_next_step="${next_step:-Reproduce the runtime issue, confirm the root cause, and exit hotfix mode only after stabilization is verified.}"
fi

hotfix_body=$(cat <<EOF
- Status: ${status}
- Hotfix summary: ${summary}
- Interrupted planned task: ${interrupted_task:-n/a}
- Started at: $(timestamp_now)
- Resolved at: $(if [[ "$status" == "resolved" ]]; then timestamp_now; else printf 'n/a'; fi)

## Reproduction
- Exact symptom: ${summary}
- Reproduction steps: ${reproduction:-not recorded yet}
- Expected behavior: not recorded yet
- Actual behavior: ${reproduction:-not recorded yet}

## Root Cause
- Confirmed root cause: ${root_cause:-unknown}
- Unknowns: $(if [[ -n "$root_cause" ]]; then printf 'none recorded'; else printf 'root cause still being confirmed'; fi)

## Fix Plan
- Target files / services: not recorded yet
- Current fix approach: ${fix_note:-not recorded yet}
- Exit criteria: ${exit_criteria:-runtime issue reproduced, fixed, and re-verified}

## Verification
- Commands already run: not recorded yet
- Cold-start verification status: not recorded yet
- Manual QA handoff status: not recorded yet

## Cleanup / Follow-Up
- State corrections required in TASKS.md / SESSION_STATE.md / HANDOFF.md: runtime hotfix mode must remain visible until resolved
- Remaining hardening after the hotfix: not recorded yet
EOF
)
cat > "$hotfix_path" <<EOF
# Runtime Hotfix

Use this file when real runtime usage interrupts planned work and the project
must switch into stabilization/hotfix mode.

${hotfix_body}
EOF

tasks_override=$(cat <<EOF
- Status: ${status}
- Hotfix: ${summary}
- Interrupted planned task: ${interrupted_task:-n/a}
- Exit criteria: ${exit_criteria:-runtime issue reproduced, fixed, and re-verified}
EOF
)

python3 - "$(project_file_path "$target_dir" "TASKS.md")" "$tasks_override" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
body = sys.argv[2].rstrip().splitlines()
text = path.read_text() if path.exists() else "# Tasks\n"
lines = text.splitlines()
out = []
replaced = False
i = 0

while i < len(lines):
    line = lines[i]
    if line == "## Runtime Override":
        out.append(line)
        out.append("")
        out.extend(body)
        out.append("")
        replaced = True
        i += 1
        while i < len(lines) and not lines[i].startswith("## "):
            i += 1
        continue
    out.append(line)
    i += 1

if not replaced:
    if out and out[-1] != "":
        out.append("")
    out.extend(["## Runtime Override", "", *body, ""])

path.write_text("\n".join(out).rstrip() + "\n")
PY

session_body=$(cat <<EOF
- Hotfix status: ${status}
- Hotfix summary: ${summary}
- Interrupted planned task: ${interrupted_task:-n/a}
- Reproduction: ${reproduction:-not recorded yet}
- Root cause: ${root_cause:-unknown}
- Fix approach: ${fix_note:-not recorded yet}
- Exit criteria: ${exit_criteria:-runtime issue reproduced, fixed, and re-verified}
- Next step: ${current_next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "runtime-hotfix" "## Runtime Hotfix" "$session_body"
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "runtime-hotfix" "## Runtime Hotfix" "$session_body"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/refresh-core-context.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/compact-hot-docs.sh" "$target_dir" >/dev/null 2>&1 || true

if [[ -f "$SCRIPT_DIR/fix-project-perms.sh" ]]; then
  bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null 2>&1 || true
fi

echo "Updated runtime hotfix mode for $target_dir"
echo "Status: $status"
echo "Hotfix: $summary"
