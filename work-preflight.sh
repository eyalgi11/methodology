#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: work-preflight.sh [--task TASK] [--profile PROFILE] [--json] [target-directory]

Runs the main startup and readiness checks, then prints one short remediation list
before substantial implementation starts.
EOF
}

target_arg=""
task=""
profile="minimal"
json_mode=0

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target directory may be provided." >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
"$SCRIPT_DIR/methodology-entry.sh" --profile "$profile" "$target_dir" >/dev/null

state_file="$(project_file_path "$target_dir" "methodology-state.json")"
mode="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("maturity_mode","prototype"))' "$state_file" 2>/dev/null || true)"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
delegation_policy="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("delegation_policy","multi_agent_default"))' "$state_file" 2>/dev/null || true)"
active_task="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task",""))' "$state_file" 2>/dev/null || true)"
active_state="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task_state",""))' "$state_file" 2>/dev/null || true)"
active_spec="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_spec",""))' "$state_file" 2>/dev/null || true)"
task="${task:-$active_task}"

blockers=()
warnings=()
checks=()

record_check() {
  local label="$1"
  local status="$2"
  local message="$3"
  checks+=("${label}|${status}|${message}")
}

capture_issues() {
  local label="$1"
  local severity="$2"
  shift 2
  local output
  if output="$("$@" 2>/dev/null)"; then
    record_check "$label" "ok" ""
    return 0
  fi

  mapfile -t found < <(printf '%s' "$output" | python3 -c 'import json,sys
text=sys.stdin.read().strip()
if not text:
    raise SystemExit(0)
try:
    data=json.loads(text)
    issues=data.get("issues", [])
except Exception:
    issues=[line.strip(" -") for line in text.splitlines() if line.strip().startswith("-")]
for item in issues:
    print(item)
' 2>/dev/null || true)
  if (( ${#found[@]} == 0 )); then
    found+=("${label} failed.")
  fi
  local item
  for item in "${found[@]}"; do
    if [[ "$severity" == "blocker" ]]; then
      blockers+=("$item")
    else
      warnings+=("$item")
    fi
  done
  record_check "$label" "$severity" "${found[0]}"
  return 1
}

capture_issues "observable_compliance" "blocker" "$SCRIPT_DIR/observable-compliance-check.sh" --json "$target_dir" || true
capture_issues "mode_check" "blocker" "$SCRIPT_DIR/mode-check.sh" --json --light "$target_dir" || true

if [[ "$mode" == "product" || "$mode" == "production" ]]; then
  capture_issues "metrics_check" "warning" "$SCRIPT_DIR/metrics-check.sh" --json --no-write "$target_dir" || true
fi

if [[ -n "$task" && "$task" != "setup" && "$task" != "Define initial project brief and first task" && "$active_state" != "done" && "$active_state" != "cancelled" ]]; then
  capture_issues "ready_check" "blocker" "$SCRIPT_DIR/ready-check.sh" --json --task "$task" "$target_dir" || true
fi

summary="Ready to implement."
if (( ${#blockers[@]} > 0 )); then
  summary="Preflight blockers found."
elif (( ${#warnings[@]} > 0 )); then
  summary="Preflight passed with warnings."
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"mode":"%s",' "$(json_escape "$mode")"
  printf '"work_type":"%s",' "$(json_escape "$work_type")"
  printf '"delegation_policy":"%s",' "$(json_escape "$delegation_policy")"
  printf '"task":"%s",' "$(json_escape "$task")"
  printf '"task_state":"%s",' "$(json_escape "$active_state")"
  printf '"active_spec":"%s",' "$(json_escape "$active_spec")"
  printf '"ok":%s,' "$( (( ${#blockers[@]} == 0 )) && printf true || printf false )"
  printf '"summary":"%s",' "$(json_escape "$summary")"
  printf '"blockers":'
  print_json_array blockers
  printf ','
  printf '"warnings":'
  print_json_array warnings
  printf '}\n'
else
  echo "Preflight: $summary"
  echo "Mode: ${mode:-prototype} | Work type: ${work_type:-product} | Delegation: ${delegation_policy:-multi_agent_default}"
  echo "Task: ${task:-n/a} (${active_state:-n/a})"
  echo "Spec: ${active_spec:-n/a}"
  if (( ${#blockers[@]} > 0 )); then
    echo "Blockers:"
    printf '  - %s\n' "${blockers[@]}"
  fi
  if (( ${#warnings[@]} > 0 )); then
    echo "Warnings:"
    printf '  - %s\n' "${warnings[@]}"
  fi
  if (( ${#blockers[@]} == 0 && ${#warnings[@]} == 0 )); then
    echo "No remediation needed."
  fi
fi

if (( ${#blockers[@]} == 0 )); then
  exit 0
fi
exit 1
