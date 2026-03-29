#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: session-snapshot.sh [options] [target-directory]

Writes current working context into SESSION_STATE.md and HANDOFF.md.

Options:
  --objective TEXT
  --status TEXT
  --next-step TEXT
  --completed TEXT
  --remaining TEXT
  --verification TEXT
  --risks TEXT
  --json
EOF
}

json_mode=0
target_arg=""
objective=""
current_status=""
next_step=""
completed=""
remaining=""
verification=""
risks=""

while (($# > 0)); do
  case "$1" in
    --objective) objective="$2"; shift 2 ;;
    --status) current_status="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    --completed) completed="$2"; shift 2 ;;
    --remaining) remaining="$2"; shift 2 ;;
    --verification) verification="$2"; shift 2 ;;
    --risks) risks="$2"; shift 2 ;;
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
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
branch="$(current_git_branch "$target_dir")"
task_record="$(effective_task_record "$target_dir")"
active_task="$(printf '%s' "$task_record" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("task",""))')"
active_state="$(printf '%s' "$task_record" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("state",""))')"
active_spec="$(printf '%s' "$task_record" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("spec",""))')"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
business_owner="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("business_owner",""))' "$state_file" 2>/dev/null || true)"
leading_metric="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("leading_metric",""))' "$state_file" 2>/dev/null || true)"
customer_signal="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("customer_signal",""))' "$state_file" 2>/dev/null || true)"
decision_deadline="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("decision_deadline",""))' "$state_file" 2>/dev/null || true)"
active_risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class",""))' "$state_file" 2>/dev/null || true)"
active_release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk",""))' "$state_file" 2>/dev/null || true)"

mapfile -t status_lines < <(git_status_short "$target_dir")
mapfile -t recent_files < <(recent_work_files "$target_dir" 10)

if [[ -z "$objective" ]]; then
  objective="Resume the highest-priority in-progress task from TASKS.md and HANDOFF.md."
fi

if [[ -z "$current_status" ]]; then
  if [[ ${#status_lines[@]} -gt 0 ]]; then
    current_status="Working tree has uncommitted changes and the current session snapshot reflects active work in progress."
  elif [[ ${#recent_files[@]} -gt 0 ]]; then
    current_status="No uncommitted changes detected; recent work files suggest the repo has prior context that can be resumed."
  else
    current_status="No recent non-methodology work files were detected."
  fi
fi

if [[ -z "$verification" ]]; then
  last_result="$(awk '/^- Result:/ {result=$0} END {print result}' "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")" 2>/dev/null || true)"
  if [[ -n "$last_result" ]]; then
    verification="${last_result#- Result: }"
  else
    verification="No verification summary supplied. Check VERIFICATION_LOG.md for details or add a new entry."
  fi
fi

if [[ -z "$risks" ]]; then
  risks="No explicit blocker summary supplied. Review OPEN_QUESTIONS.md and RISK_REGISTER.md before major changes."
fi

if [[ -z "$completed" ]]; then
  completed="Captured current repo state, branch, and recent file activity."
fi

if [[ -z "$remaining" ]]; then
  remaining="Review open tasks and continue the highest-priority work item."
fi

if [[ -z "$next_step" ]]; then
  if [[ ${#recent_files[@]} -gt 0 ]]; then
    next_step="Open ${recent_files[0]} and reconcile it with TASKS.md, HANDOFF.md, and SESSION_STATE.md."
  else
    next_step="Review TASKS.md and define the next concrete implementation step."
  fi
fi

touched_items=()
if [[ ${#status_lines[@]} -gt 0 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && touched_items+=("$line")
  done < <(printf '%s\n' "${status_lines[@]}" | head -n 12)
elif [[ ${#recent_files[@]} -gt 0 ]]; then
  touched_items=("${recent_files[@]}")
else
  touched_items=("No touched files detected.")
fi

session_body=$(cat <<EOF
- Snapshot at: ${timestamp}
- Branch: ${branch}
- Active task: ${active_task:-n/a}
- Active task state: ${active_state:-n/a}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${active_risk_class:-n/a}
- Release risk: ${active_release_risk:-n/a}
- Task workspace: $(if [[ -n "$active_task" ]]; then display_project_relpath "$target_dir" "$(task_state_relpath "$active_task")"; else printf 'n/a'; fi)
- Objective summary: ${objective}
- Status summary: ${current_status}
- Verification summary: ${verification}
- Next step: ${next_step}
EOF
)

handoff_body=$(cat <<EOF
- Snapshot at: ${timestamp}
- Active task: ${active_task:-n/a}
- Active task state: ${active_state:-n/a}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${active_risk_class:-n/a}
- Release risk: ${active_release_risk:-n/a}
- Task handoff: $(if [[ -n "$active_task" ]]; then display_project_relpath "$target_dir" "$(task_handoff_relpath "$active_task")"; else printf 'n/a'; fi)
- Completed summary: ${completed}
- Remaining summary: ${remaining}
- Verification summary: ${verification}
- Risks summary: ${risks}
- Resume here: ${next_step}
EOF
)

printf '%s\n' "$session_body" > "$(project_file_path "$target_dir" "SESSION_STATE.md")"
printf '%s\n' "$handoff_body" > "$(project_file_path "$target_dir" "HANDOFF.md")"

if [[ -n "$active_task" ]]; then
  ensure_task_workspace "$target_dir" "$active_task" "${active_state:-n/a}" "$active_spec"
  task_detail_state=$(cat <<EOF
# Task State

- Task: ${active_task}
- Task slug: $(task_slug "$active_task")
- Schema version: ${METHODOLOGY_SCHEMA_VERSION}
- Generator version: ${METHODOLOGY_GENERATOR_VERSION}
- Task state: ${active_state:-n/a}
- Spec: ${active_spec:-n/a}
- Updated at: ${timestamp}

## Objective
- ${objective}

## Current Status
- ${current_status}

## Verification
- ${verification}

## Blockers / Assumptions
- ${risks}

## Next Step
- ${next_step}
EOF
)
  task_detail_handoff=$(cat <<EOF
# Task Handoff

- Task: ${active_task}
- Task slug: $(task_slug "$active_task")
- Schema version: ${METHODOLOGY_SCHEMA_VERSION}
- Generator version: ${METHODOLOGY_GENERATOR_VERSION}
- Task state: ${active_state:-n/a}
- Spec: ${active_spec:-n/a}
- Updated at: ${timestamp}

## Completed
- ${completed}

## Remaining
- ${remaining}

## Verification Run
- ${verification}

## Risks / Blockers
- ${risks}

## Resume Here
- ${next_step}
EOF
)
  printf '%s\n' "$task_detail_state" > "$(task_state_file "$target_dir" "$active_task")"
  printf '%s\n' "$task_detail_handoff" > "$(task_handoff_file "$target_dir" "$active_task")"
  update_task_manifest "$target_dir" "$active_task" "${active_state:-n/a}" "${active_spec:-n/a}" "${verification}" "${current_status}" "${next_step}" "${next_step}"
  update_work_index_entry "$target_dir" "$active_task" "${active_state:-n/a}"
fi

health_snapshot_body=$(cat <<EOF
- Reviewed at: ${timestamp}
- Current branch: ${branch}
- Latest touched item: ${touched_items[0]}
- Snapshot source: session-snapshot.sh
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "PROJECT_HEALTH.md")" "session-snapshot" "## Auto Snapshot" "$health_snapshot_body"

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"branch":"%s",' "$(json_escape "$branch")"
  printf '"touched_files":'
  print_json_array touched_items
  printf ','
  printf '"next_step":"%s"' "$(json_escape "$next_step")"
  printf '}\n'
else
  echo "Session snapshot updated for $target_dir"
  echo "Branch: $branch"
  echo "Next step: $next_step"
fi
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
