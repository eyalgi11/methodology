#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: progress-checkpoint.sh --summary "What changed" [options] [target-directory]

Writes an observable in-flight checkpoint into SESSION_STATE.md and HANDOFF.md.

Options:
  --summary TEXT
  --task TEXT
  --state TEXT
  --updated-doc FILE   May be repeated
  --verification TEXT
  --next-step TEXT
  --claim-id TEXT
EOF
}

target_arg=""
summary=""
task=""
state=""
verification=""
next_step=""
claim_id=""
updated_docs=()

while (($# > 0)); do
  case "$1" in
    --summary) summary="$2"; shift 2 ;;
    --task) task="$2"; shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --updated-doc) updated_docs+=("$2"); shift 2 ;;
    --verification) verification="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    --claim-id) claim_id="$2"; shift 2 ;;
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

if [[ -z "$summary" ]]; then
  echo "--summary is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
business_owner="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("business_owner",""))' "$state_file" 2>/dev/null || true)"
leading_metric="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("leading_metric",""))' "$state_file" 2>/dev/null || true)"
customer_signal="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("customer_signal",""))' "$state_file" 2>/dev/null || true)"
decision_deadline="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("decision_deadline",""))' "$state_file" 2>/dev/null || true)"
release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk",""))' "$state_file" 2>/dev/null || true)"
risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class",""))' "$state_file" 2>/dev/null || true)"
next_step="${next_step:-$(best_next_step "$target_dir")}"
next_step="${next_step:-Review TASKS.md and pick the next concrete step.}"
verification="${verification:-No new verification recorded in this checkpoint.}"
if [[ -n "$task" && -z "$state" ]]; then
  state="$(task_workspace_current_state "$target_dir" "$task")"
  state="${state:-n/a}"
fi
if [[ -n "$task" ]]; then
  ensure_task_workspace "$target_dir" "$task" "${state:-n/a}"
  task_state_path="$(task_state_file "$target_dir" "$task")"
  task_handoff_path="$(task_handoff_file "$target_dir" "$task")"
  workspace_state_rel="$(display_project_relpath "$target_dir" "$(task_state_relpath "$task")")"
fi
docs_summary="none recorded"
if (( ${#updated_docs[@]} > 0 )); then
  docs_summary="$(printf '%s, ' "${updated_docs[@]}")"
  docs_summary="${docs_summary%, }"
fi

session_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Task workspace: ${workspace_state_rel:-n/a}
- Task: ${task:-n/a}
- Task state: ${state:-n/a}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${risk_class:-n/a}
- Release risk: ${release_risk:-n/a}
- Summary: ${summary}
- Methodology docs updated: ${docs_summary}
- Verification: ${verification}
- Next step: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "progress-checkpoint" "## Progress Checkpoint" "$session_body"

handoff_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Task workspace: ${workspace_state_rel:-n/a}
- Task: ${task:-n/a}
- Task state: ${state:-n/a}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${risk_class:-n/a}
- Release risk: ${release_risk:-n/a}
- Summary: ${summary}
- Docs updated: ${docs_summary}
- Verification: ${verification}
- Resume here: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "progress-checkpoint" "## Progress Checkpoint" "$handoff_body"

if [[ -n "${task_state_path:-}" ]]; then
  append_or_replace_auto_section "$task_state_path" "progress-checkpoint" "## Progress Checkpoint" "$session_body"
  append_or_replace_auto_section "$task_handoff_path" "progress-checkpoint" "## Progress Checkpoint" "$handoff_body"
  update_task_manifest "$target_dir" "$task" "${state:-n/a}" "n/a" "$verification" "$summary" "$next_step" "$next_step"
  update_work_index_entry "$target_dir" "$task" "${state:-n/a}"
fi

if [[ -n "$claim_id" ]]; then
  "$SCRIPT_DIR/claim-work.sh" --heartbeat --claim-id "$claim_id" "$target_dir" >/dev/null 2>&1 || true
fi

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Progress checkpoint recorded."
