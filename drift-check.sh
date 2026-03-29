#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: drift-check.sh [--json] [--verify-commands] [target-directory]

Checks for methodology drift and contradictions between docs and repo state.
EOF
}

json_mode=0
verify_commands=0
target_arg=""

while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --verify-commands) verify_commands=1; shift ;;
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

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"
risk_register_file="$(project_file_path "$target_dir" "RISK_REGISTER.md")"
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
handoff_file="$(project_file_path "$target_dir" "HANDOFF.md")"
session_state_file="$(project_file_path "$target_dir" "SESSION_STATE.md")"
active_claims_file="$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")"
commands_file="$(project_file_path "$target_dir" "COMMANDS.md")"
exceptions_file="$(project_file_path "$target_dir" "PROCESS_EXCEPTIONS.md")"
issues=()

check_line_budget() {
  local relpath="$1"
  local max_lines="$2"
  local file_path
  file_path="$(project_file_path "$target_dir" "$relpath")"
  [[ -f "$file_path" ]] || return 0
  local line_count
  line_count="$(wc -l < "$file_path" 2>/dev/null || printf '0')"
  if (( line_count > max_lines )); then
    issues+=("${relpath} exceeds its hot-doc budget (${line_count}/${max_lines} lines).")
  fi
}

section_body() {
  local file_path="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section = 1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "$file_path" 2>/dev/null || true
}

if ! "$SCRIPT_DIR/methodology-audit.sh" --json "$target_dir" >/tmp/methodology-audit.$$ 2>/dev/null; then
  audit_json="$(cat /tmp/methodology-audit.$$)"
  missing_fragment="$(printf '%s' "$audit_json" | grep -o '"missing":\[[^]]*\]' || true)"
  placeholder_fragment="$(printf '%s' "$audit_json" | grep -o '"placeholder":\[[^]]*\]' || true)"
  [[ -n "$missing_fragment" && "$missing_fragment" != '"missing":[]' ]] && issues+=("Methodology files are missing.")
  [[ -n "$placeholder_fragment" && "$placeholder_fragment" != '"placeholder":[]' ]] && issues+=("Methodology templates are still untouched.")
fi
rm -f /tmp/methodology-audit.$$

if ! "$SCRIPT_DIR/methodology-status.sh" --json "$target_dir" >/tmp/methodology-status.$$ 2>/dev/null; then
  status_json="$(cat /tmp/methodology-status.$$)"
  stale_fragment="$(printf '%s' "$status_json" | grep -o '"stale":\[[^]]*\]' || true)"
  missing_fragment="$(printf '%s' "$status_json" | grep -o '"missing":\[[^]]*\]' || true)"
  [[ -n "$missing_fragment" && "$missing_fragment" != '"missing":[]' ]] && issues+=("Continuity files are missing.")
  [[ -n "$stale_fragment" && "$stale_fragment" != '"stale":[]' ]] && issues+=("Continuity files are stale relative to recent work.")
fi
rm -f /tmp/methodology-status.$$

if [[ -f "$project_health_file" && -f "$risk_register_file" ]]; then
  health_status_line="$(grep -i 'Current status:' "$project_health_file" | head -n 1 || true)"
  if printf '%s' "$health_status_line" | grep -qi 'green'; then
    if grep -Eqi 'Severity:[[:space:]]*(critical|high)' "$risk_register_file"; then
      issues+=("PROJECT_HEALTH.md says green while RISK_REGISTER.md contains high or critical severity risk.")
    fi
  fi
fi

in_progress_limit="$(task_limit_for_section "$tasks_file" "## In Progress")"
in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
if [[ "$in_progress_limit" =~ ^[0-9]+$ ]] && (( in_progress_limit > 0 )) && (( in_progress_count > in_progress_limit )); then
  issues+=("In Progress WIP limit is exceeded ($in_progress_count/$in_progress_limit).")
fi

ready_limit="$(task_limit_for_section "$tasks_file" "## Ready")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
if [[ "$ready_limit" =~ ^[0-9]+$ ]] && (( ready_limit > 0 )) && (( ready_count > ready_limit )); then
  issues+=("Ready WIP limit is exceeded ($ready_count/$ready_limit).")
fi

if [[ -f "$tasks_file" && -f "$handoff_file" ]]; then
  open_tasks="$(grep -c '^- \[ \]' "$tasks_file" || true)"
  remaining_value="$(awk '
    /^- Remaining:/ {
      value = $0
      sub(/^- Remaining:[[:space:]]*/, "", value)
      found = value
    }
    END {
      if (found != "") print found
    }
  ' "$handoff_file" 2>/dev/null || true)"
  remaining_value="$(trim_whitespace "$remaining_value")"
  if is_placeholder_value "$remaining_value"; then
    remaining_value=""
  fi
  if (( open_tasks > 0 )) && [[ -z "$remaining_value" ]]; then
    issues+=("TASKS.md has open tasks but HANDOFF.md Remaining is blank or still a placeholder.")
  fi
fi

if [[ -f "$session_state_file" ]]; then
  recent_any="$(recent_work_files "$target_dir" 1 || true)"
  next_step_value="$(best_next_step "$target_dir")"
  if [[ -n "$recent_any" ]] && [[ -z "$(trim_whitespace "$next_step_value")" ]]; then
    issues+=("SESSION_STATE.md does not contain a concrete next step.")
  fi
fi

if ! "$SCRIPT_DIR/mode-check.sh" --json --light "$target_dir" >/tmp/methodology-mode.$$ 2>/dev/null; then
  issues+=("Declared maturity mode expectations are not satisfied.")
fi
rm -f /tmp/methodology-mode.$$

if ! "$SCRIPT_DIR/decision-review.sh" --json "$target_dir" >/tmp/methodology-decision.$$ 2>/dev/null; then
  issues+=("Decisions are missing review dates or have overdue reviews.")
fi
rm -f /tmp/methodology-decision.$$

if ! "$SCRIPT_DIR/observable-compliance-check.sh" --json "$target_dir" >/tmp/methodology-observable.$$ 2>/dev/null; then
  issues+=("Methodology usage is not visibly recorded in the current project state.")
fi
rm -f /tmp/methodology-observable.$$

if ! "$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" >/tmp/methodology-stale-claims.$$ 2>/dev/null; then
  stale_claim_count="$(python3 -c 'import json,sys; print(len(json.loads(sys.stdin.read()).get("stale_claims", [])))' </tmp/methodology-stale-claims.$$ 2>/dev/null || printf '1')"
  issues+=("Active claims have expired leases or missing heartbeats (${stale_claim_count} stale).")
fi
rm -f /tmp/methodology-stale-claims.$$

duplicate_claims="$(python3 - "$active_claims_file" <<'PY'
import sys
from collections import Counter
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)

files = []
for line in path.read_text().splitlines():
    stripped = line.strip()
    if stripped.startswith("- ") and not stripped.startswith("- Agent:") and not stripped.startswith("- Task:") and not stripped.startswith("- Claimed at:") and not stripped.startswith("- Notes:"):
        value = stripped[2:].strip()
        if value and "/" in value:
            files.append(value)

dupes = [name for name, count in Counter(files).items() if count > 1]
for item in dupes:
    print(item)
PY
)"
if [[ -n "$(trim_whitespace "$duplicate_claims")" ]]; then
  issues+=("ACTIVE_CLAIMS.md contains overlapping file claims.")
fi

if [[ -f "$commands_file" ]]; then
  runnable_count=0
  while IFS=$'\t' read -r _ _ value; do
    value="$(strip_wrapping_backticks "$(trim_whitespace "$value")")"
    if ! is_placeholder_value "$value" && [[ "$value" != "n/a" && -n "$value" ]]; then
      runnable_count=$((runnable_count + 1))
    fi
  done < <(extract_commands_from_markdown "$commands_file")
  if (( runnable_count == 0 )); then
    issues+=("COMMANDS.md does not contain runnable commands yet.")
  fi
fi

if [[ -f "$exceptions_file" ]] && grep -Eq '^[[:space:]]*- Exception:' "$exceptions_file" 2>/dev/null; then
  if ! grep -Eq '^[[:space:]]*- Risk level:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without a risk level.")
  fi
  if ! grep -Eq '^[[:space:]]*- Compensating control:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without a compensating control.")
  fi
  if ! grep -Eq '^[[:space:]]*- Owner:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without an owner.")
  fi
  if ! grep -Eq '^[[:space:]]*- Status:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without a status.")
  fi
  if ! grep -Eq '^[[:space:]]*- Approved by:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without an approver.")
  fi
  if ! grep -Eq '^[[:space:]]*- Expires on:[[:space:]]*[^[:space:]].+' "$exceptions_file" 2>/dev/null; then
    issues+=("PROCESS_EXCEPTIONS.md has exceptions without an expiry.")
  fi
  expired_exception_count="$(python3 - "$exceptions_file" <<'PY'
import re
import sys
from datetime import date
from pathlib import Path

path = Path(sys.argv[1])
blocks = []
current = {}
for raw in path.read_text().splitlines():
    line = raw.strip()
    if line.startswith("## Exception - "):
        if current:
            blocks.append(current)
        current = {}
        continue
    if line.startswith("- "):
        key, _, value = line[2:].partition(":")
        current[key.strip().lower()] = value.strip()
if current:
    blocks.append(current)

today = date.today()
expired = 0
for block in blocks:
    expires = block.get("expires on", "")
    status = block.get("status", "").lower()
    ci_fail = block.get("ci fail after expiry", "yes").lower()
    if ci_fail not in {"yes", "true", "1"}:
        continue
    if status in {"backfilled", "closed", "waived"}:
        continue
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", expires):
        continue
    try:
        exp = date.fromisoformat(expires)
    except ValueError:
        continue
    if exp < today:
        expired += 1
print(expired)
PY
)"
  if [[ "$expired_exception_count" =~ ^[0-9]+$ ]] && (( expired_exception_count > 0 )); then
    issues+=("PROCESS_EXCEPTIONS.md has ${expired_exception_count} expired exception(s) that still enforce CI failure.")
  fi
fi

check_line_budget "CORE_CONTEXT.md" "$(context_budget_for "CORE_CONTEXT.md")"
check_line_budget "SESSION_STATE.md" "$(context_budget_for "SESSION_STATE.md")"
check_line_budget "HANDOFF.md" "$(context_budget_for "HANDOFF.md")"
if [[ -f "$(project_file_path "$target_dir" "WORK_INDEX.md")" ]]; then
  work_index_entries="$(grep -Ec '^- Task:' "$(project_file_path "$target_dir" "WORK_INDEX.md")" 2>/dev/null || true)"
  work_index_budget="$(context_budget_for "WORK_INDEX.md")"
  if (( work_index_entries > work_index_budget )); then
    issues+=("WORK_INDEX.md exceeds the active-entry budget (${work_index_entries}/${work_index_budget}).")
  fi
fi
active_task_record="$(effective_task_record "$target_dir")"
active_task_name="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$active_task_record" 2>/dev/null || true)"
if [[ -n "$active_task_name" && "$active_task_name" != "setup" ]]; then
  task_state_rel="$(task_state_relpath "$active_task_name")"
  task_handoff_rel="$(task_handoff_relpath "$active_task_name")"
  check_line_budget "$task_state_rel" "$(context_budget_for "$task_state_rel")"
  check_line_budget "$task_handoff_rel" "$(context_budget_for "$task_handoff_rel")"
fi

verify_summary="skipped"
if (( verify_commands == 1 )); then
  if "$SCRIPT_DIR/verify-project.sh" --json --no-log "$target_dir" >/tmp/methodology-verify.$$ 2>/dev/null; then
    verify_summary="passed"
  else
    verify_summary="failed"
    issues+=("verify-project.sh reported failing verification commands.")
  fi
  rm -f /tmp/methodology-verify.$$
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"verify_commands":"%s",' "$(json_escape "$verify_summary")"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "No methodology drift detected."
    if (( verify_commands == 1 )); then
      echo "Verification commands: $verify_summary"
    fi
  else
    echo "Drift issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
    if (( verify_commands == 1 )); then
      echo "Verification commands: $verify_summary"
    fi
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi

exit 1
