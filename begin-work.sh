#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: begin-work.sh --task "Task" --state STATE [options] [target-directory]

Writes an observable start-of-work checkpoint into SESSION_STATE.md and HANDOFF.md.

Options:
  --task TEXT
  --state TEXT
  --spec PATH
  --verification-path TEXT
  --doc FILE        May be repeated
EOF
}

target_arg=""
task=""
state=""
spec_path=""
verification_path=""
docs=()

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --spec) spec_path="$2"; shift 2 ;;
    --verification-path) verification_path="$2"; shift 2 ;;
    --doc) docs+=("$2"); shift 2 ;;
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

if [[ -z "$task" || -z "$state" ]]; then
  echo "--task and --state are required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
ensure_task_workspace "$target_dir" "$task" "$state" "$spec_path"
task_state_path="$(task_state_file "$target_dir" "$task")"
task_handoff_path="$(task_handoff_file "$target_dir" "$task")"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
business_owner="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("business_owner",""))' "$state_file" 2>/dev/null || true)"
leading_metric="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("leading_metric",""))' "$state_file" 2>/dev/null || true)"
customer_signal="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("customer_signal",""))' "$state_file" 2>/dev/null || true)"
decision_deadline="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("decision_deadline",""))' "$state_file" 2>/dev/null || true)"
release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk",""))' "$state_file" 2>/dev/null || true)"
risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class",""))' "$state_file" 2>/dev/null || true)"

if (( ${#docs[@]} == 0 )); then
  for file_name in PROJECT_BRIEF.md ROADMAP.md TASKS.md WORK_INDEX.md SESSION_STATE.md HANDOFF.md; do
    [[ -f "$(project_file_path "$target_dir" "$file_name")" ]] && docs+=("$(display_project_relpath "$target_dir" "$file_name")")
  done
fi
if [[ -n "$spec_path" ]]; then
  already_listed=0
  for file_name in "${docs[@]}"; do
    if [[ "$file_name" == "$spec_path" ]]; then
      already_listed=1
      break
    fi
  done
  if (( already_listed == 0 )); then
    docs+=("$spec_path")
  fi
fi

verification_path="${verification_path:-Review the spec, run the repo verification commands, and record the result in VERIFICATION_LOG.md.}"
docs_summary="none recorded"
if (( ${#docs[@]} > 0 )); then
  docs_summary="$(printf '%s, ' "${docs[@]}")"
  docs_summary="${docs_summary%, }"
fi
workspace_state_rel="$(display_project_relpath "$target_dir" "$(task_state_relpath "$task")")"
workspace_handoff_rel="$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task")")"

session_body=$(cat <<EOF
- Started at: $(timestamp_now)
- Active workspace: ${workspace_state_rel}
- Loaded docs: ${docs_summary}
- Active task: ${task}
- Task state: ${state}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${risk_class:-n/a}
- Release risk: ${release_risk:-n/a}
- Spec: ${spec_path:-n/a}
- Verification path: ${verification_path}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "observable-compliance" "## Observable Compliance" "$session_body"

handoff_body=$(cat <<EOF
- Checked at: $(timestamp_now)
- Active workspace: ${workspace_handoff_rel}
- Loaded docs: ${docs_summary}
- Current task: ${task}
- Current state: ${state}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${risk_class:-n/a}
- Release risk: ${release_risk:-n/a}
- Spec: ${spec_path:-n/a}
- Verification path: ${verification_path}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "observable-compliance" "## Observable Compliance" "$handoff_body"

task_state_body=$(cat <<EOF
- Started at: $(timestamp_now)
- Loaded docs: ${docs_summary}
- Task state: ${state}
- Work type: ${work_type:-product}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${risk_class:-n/a}
- Release risk: ${release_risk:-n/a}
- Spec: ${spec_path:-n/a}
- Verification path: ${verification_path}
EOF
)
append_or_replace_auto_section "$task_state_path" "observable-compliance" "## Observable Compliance" "$task_state_body"
append_or_replace_auto_section "$task_handoff_path" "observable-compliance" "## Observable Compliance" "$task_state_body"
update_task_manifest "$target_dir" "$task" "$state" "${spec_path:-n/a}" "$verification_path" "Work started." "Continue active implementation." "Resume active implementation from the task handoff."
update_work_index_entry "$target_dir" "$task" "$state"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Observable start checkpoint recorded for $task"
