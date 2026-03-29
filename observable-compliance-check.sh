#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: observable-compliance-check.sh [--json] [target-directory]

Checks whether visible methodology evidence exists in SESSION_STATE.md and HANDOFF.md.
EOF
}

target_arg=""
json_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    -h|--help) usage; exit 0 ;;
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
issues=()

auto_section_label_value() {
  local file_path="$1"
  local section_id="$2"
  local label="$3"
  local value
  value="$(python3 - "$file_path" "$section_id" "$label" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path

path = Path(sys.argv[1])
section_id = sys.argv[2]
label = sys.argv[3]
if not path.exists():
    raise SystemExit(0)

start = f"<!-- AUTO:START {section_id} -->"
end = f"<!-- AUTO:END {section_id} -->"
needle = f"- {label}:"
in_block = False
for raw in path.read_text().splitlines():
    line = raw.rstrip()
    if line == start:
        in_block = True
        continue
    if line == end:
        in_block = False
        continue
    if in_block and line.startswith(needle):
        print(line[len(needle):].strip())
        raise SystemExit(0)
PY
)"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  last_markdown_label_value "$file_path" "$label"
}

session_file="$(project_file_path "$target_dir" "SESSION_STATE.md")"
handoff_file="$(project_file_path "$target_dir" "HANDOFF.md")"
multi_agent_plan_file="$(project_file_path "$target_dir" "MULTI_AGENT_PLAN.md")"
active_claims_file="$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")"
process_exceptions_file="$(project_file_path "$target_dir" "PROCESS_EXCEPTIONS.md")"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
delegation_policy="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("delegation_policy","multi_agent_default"))' "$state_file" 2>/dev/null || true)"
task_info="$(effective_task_record "$target_dir")"
expected_task="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("task",""))')"
expected_state="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("state",""))')"
expected_spec="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("spec",""))')"

if ! grep -Eq 'AUTO:START (observable-compliance|resume-work|progress-checkpoint|work-closure)' "$session_file" 2>/dev/null; then
  issues+=("SESSION_STATE.md does not show observable methodology evidence yet.")
fi
if ! grep -Eq 'AUTO:START (observable-compliance|progress-checkpoint|work-closure)' "$handoff_file" 2>/dev/null; then
  issues+=("HANDOFF.md does not show observable methodology evidence yet.")
fi

loaded_docs="$(auto_section_label_value "$session_file" "observable-compliance" "Loaded docs")"
active_task="$(auto_section_label_value "$session_file" "observable-compliance" "Active task")"
task_state="$(auto_section_label_value "$session_file" "observable-compliance" "Task state")"
business_owner="$(auto_section_label_value "$session_file" "observable-compliance" "Business owner")"
leading_metric="$(auto_section_label_value "$session_file" "observable-compliance" "Leading metric")"
customer_signal="$(auto_section_label_value "$session_file" "observable-compliance" "Customer signal")"
decision_deadline="$(auto_section_label_value "$session_file" "observable-compliance" "Decision deadline")"
observed_work_type="$(auto_section_label_value "$session_file" "observable-compliance" "Work type")"
spec_path="$(auto_section_label_value "$session_file" "observable-compliance" "Spec")"
verification_path="$(auto_section_label_value "$session_file" "observable-compliance" "Verification path")"
workspace_path="$(auto_section_label_value "$handoff_file" "observable-compliance" "Active workspace")"
risk_class="$(auto_section_label_value "$handoff_file" "observable-compliance" "Risk class")"
if [[ -z "$risk_class" ]]; then
  risk_class="$(auto_section_label_value "$session_file" "observable-compliance" "Risk class")"
fi
release_risk="$(auto_section_label_value "$handoff_file" "observable-compliance" "Release risk")"
if [[ -z "$release_risk" ]]; then
  release_risk="$(auto_section_label_value "$session_file" "observable-compliance" "Release risk")"
fi

loaded_docs="$(trim_whitespace "$loaded_docs")"
active_task="$(trim_whitespace "$active_task")"
task_state="$(trim_whitespace "$task_state")"
business_owner="$(trim_whitespace "$business_owner")"
leading_metric="$(trim_whitespace "$leading_metric")"
customer_signal="$(trim_whitespace "$customer_signal")"
decision_deadline="$(trim_whitespace "$decision_deadline")"
observed_work_type="$(trim_whitespace "$observed_work_type")"
spec_path="$(trim_whitespace "$spec_path")"
verification_path="$(trim_whitespace "$verification_path")"
workspace_path="$(trim_whitespace "$workspace_path")"
risk_class="$(trim_whitespace "$risk_class")"
release_risk="$(trim_whitespace "$release_risk")"

if is_placeholder_value "$loaded_docs" || [[ -z "$loaded_docs" || "$loaded_docs" == "none recorded" ]]; then
  issues+=("Observable compliance is missing real loaded-doc evidence.")
fi
if is_placeholder_value "$verification_path" || [[ -z "$verification_path" ]]; then
  issues+=("Observable compliance is missing a real verification path.")
fi
if [[ -z "$observed_work_type" ]]; then
  issues+=("Observable compliance is missing the work type.")
fi
if work_type_requires_business_context "${work_type:-product}"; then
  if is_placeholder_value "$business_owner" || [[ -z "$business_owner" ]]; then
    issues+=("Observable compliance is missing the business owner.")
  fi
  if is_placeholder_value "$leading_metric" || [[ -z "$leading_metric" ]]; then
    issues+=("Observable compliance is missing the leading metric.")
  fi
  if is_placeholder_value "$customer_signal" || [[ -z "$customer_signal" ]]; then
    issues+=("Observable compliance is missing the customer signal.")
  fi
  if is_placeholder_value "$decision_deadline" || [[ -z "$decision_deadline" ]]; then
    issues+=("Observable compliance is missing the decision or review date.")
  fi
fi
if [[ -n "$expected_task" && "$active_task" != "$expected_task" ]]; then
  issues+=("Observable compliance task does not match the active task in TASKS.md.")
fi
if [[ -n "$expected_state" && "$task_state" != "$expected_state" ]]; then
  issues+=("Observable compliance task state does not match TASKS.md.")
fi
if [[ -n "$spec_path" && "$spec_path" != "n/a" && ! -f "$(project_file_path "$target_dir" "$spec_path")" ]]; then
  issues+=("Observable compliance references a spec path that does not exist.")
fi
if [[ -n "$active_task" && "$active_task" != "Define initial project brief and first task" ]]; then
  expected_workspace="$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$active_task")")"
  if [[ -z "$workspace_path" || "$workspace_path" == "n/a" ]]; then
    issues+=("Observable compliance does not point to the active task handoff workspace.")
  elif [[ "$workspace_path" != "$expected_workspace" ]]; then
    issues+=("Observable compliance workspace does not match the active task workspace.")
  fi
fi
if [[ -n "$expected_task" && "$expected_task" != "Define initial project brief and first task" && -z "$release_risk" ]]; then
  issues+=("Observable compliance is missing the release risk for active meaningful work.")
fi
if [[ -n "$expected_task" && "$expected_task" != "Define initial project brief and first task" ]]; then
  if is_placeholder_value "$risk_class" || [[ -z "$risk_class" ]]; then
    issues+=("Observable compliance is missing the risk class for active meaningful work.")
  elif [[ ! "$risk_class" =~ ^R[0-3]$ ]]; then
    issues+=("Observable compliance has an invalid risk class.")
  fi
fi

meaningful_active_work=0
if [[ -n "$expected_task" && "$expected_task" != "Define initial project brief and first task" && "$expected_state" != "done" && "$expected_state" != "cancelled" ]]; then
  meaningful_active_work=1
fi

if (( meaningful_active_work == 1 )); then
  worker_setup_json="$(python3 - "$multi_agent_plan_file" "$expected_task" <<'PY'
import json
import sys
from pathlib import Path

plan_path = Path(sys.argv[1])
expected_task = sys.argv[2].strip()
data = {"lead": False, "workers_for_task": 0}
if not plan_path.exists():
    print(json.dumps(data))
    raise SystemExit(0)

lead = ""
current = None
workers = 0

for raw in plan_path.read_text().splitlines():
    line = raw.rstrip()
    stripped = line.strip()
    if line.startswith("- Lead agent:"):
      lead = line.split(":", 1)[1].strip()
    if line.startswith("- Worker:"):
      worker = line.split(":", 1)[1].strip()
      current = {"worker": worker, "task": "", "workspace": ""}
      continue
    if current is not None and line.startswith("  - Task:"):
      current["task"] = line.split(":", 1)[1].strip()
      continue
    if current is not None and line.startswith("  - Task workspace:"):
      current["workspace"] = line.split(":", 1)[1].strip()
      task_text = current["task"]
      if worker and worker.lower() not in {"", "role", "worker", "agent"}:
        if expected_task and expected_task in task_text:
          workers += 1
        elif expected_task and expected_task.lower().replace(" ", "-") in current["workspace"].lower():
          workers += 1
      current = None

data["lead"] = bool(lead and "<" not in lead and "Lead agent" not in lead)
data["workers_for_task"] = workers
print(json.dumps(data))
PY
)"
  plan_has_lead="$(printf '%s' "$worker_setup_json" | python3 -c 'import json,sys; print("yes" if json.load(sys.stdin).get("lead") else "no")' 2>/dev/null || printf 'no')"
  plan_worker_count="$(printf '%s' "$worker_setup_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("workers_for_task", 0))' 2>/dev/null || printf '0')"
  live_claim_count="$(safe_grep_count '^## Claim ' "$active_claims_file")"
  single_agent_exception_present="$(python3 - "$process_exceptions_file" "$expected_task" "$expected_spec" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_task = sys.argv[2].strip().lower()
expected_spec = sys.argv[3].strip().lower()
if not path.exists():
    print("no")
    raise SystemExit(0)

current = {}
matched = False
for raw in path.read_text().splitlines():
    line = raw.strip()
    if not line:
        continue
    if (line.startswith("- Date:") or line.startswith("## Exception")) and current:
        text = " ".join([
            current.get("Exception", ""),
            current.get("Reason", ""),
        ]).lower()
        related = " ".join([
            current.get("Related task / spec", ""),
            current.get("Related release / incident", ""),
        ]).lower()
        status = current.get("Status", "").lower()
        if ("single-agent" in text or "single agent" in text) and status != "expired":
            if (expected_task and expected_task in related) or (expected_spec and expected_spec in related) or not related:
                matched = True
                break
        current = {}
    if line.startswith("- ") and ":" in line:
        key, value = line[2:].split(":", 1)
        current[key.strip()] = value.strip()

if current and not matched:
    text = " ".join([
        current.get("Exception", ""),
        current.get("Reason", ""),
    ]).lower()
    related = " ".join([
        current.get("Related task / spec", ""),
        current.get("Related release / incident", ""),
    ]).lower()
    status = current.get("Status", "").lower()
    if ("single-agent" in text or "single agent" in text) and status != "expired":
        if (expected_task and expected_task in related) or (expected_spec and expected_spec in related) or not related:
            matched = True

print("yes" if matched else "no")
PY
)"

  if [[ "$delegation_policy" != "single_agent_by_platform_policy" && "$single_agent_exception_present" != "yes" ]]; then
    if [[ "$plan_has_lead" != "yes" || "$plan_worker_count" == "0" || "$live_claim_count" == "0" ]]; then
      issues+=("Meaningful active work does not show a visible multi-agent setup in MULTI_AGENT_PLAN.md plus ACTIVE_CLAIMS.md, and no single-agent exception is recorded.")
    fi
  fi
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "Observable methodology compliance is present."
  else
    echo "Observable methodology compliance issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
exit 1
