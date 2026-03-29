#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: refresh-methodology-state.sh [target-directory]

Rebuilds methodology-state.json from the markdown methodology files.
EOF
}

target_arg=""
while (($# > 0)); do
  case "$1" in
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
mode="$(read_maturity_mode "$target_dir")"
mode="$(trim_whitespace "$mode")"
mode="${mode:-prototype}"
work_type="$(read_work_type "$target_dir")"
delegation_policy="$(read_delegation_policy "$target_dir")"
branch="$(current_git_branch "$target_dir")"
next_step="$(best_next_step "$target_dir")"
project_brief_file="$(project_file_path "$target_dir" "PROJECT_BRIEF.md")"
brief_business_owner="$(project_brief_heading_value "$target_dir" "## Business Owner")"
brief_business_owner="$(trim_whitespace "$brief_business_owner")"
brief_leading_metric="$(project_brief_heading_value "$target_dir" "## Leading Metric")"
brief_leading_metric="$(trim_whitespace "$brief_leading_metric")"
brief_guardrail_metrics="$(project_brief_heading_value "$target_dir" "## Guardrail Metrics")"
brief_guardrail_metrics="$(trim_whitespace "$brief_guardrail_metrics")"
brief_launch_window="$(project_brief_heading_value "$target_dir" "## Launch Window / Deadline")"
brief_launch_window="$(trim_whitespace "$brief_launch_window")"
brief_decision_deadline="$(project_brief_heading_value "$target_dir" "## Decision Deadline")"
brief_decision_deadline="$(trim_whitespace "$brief_decision_deadline")"
brief_review_date="$(project_brief_heading_value "$target_dir" "## Review Date")"
brief_review_date="$(trim_whitespace "$brief_review_date")"
brief_customer_signal="$(project_brief_heading_value "$target_dir" "## Customer Evidence")"
brief_customer_signal="$(trim_whitespace "$brief_customer_signal")"
brief_customer_evidence_present=false
if awk '
  $0 == "## Customer Evidence" { flag = 1; next }
  /^## / && flag { exit }
  flag && $0 !~ /^<!--/ && $0 !~ /^[[:space:]]*$/ { found = 1 }
  END { exit(found ? 0 : 1) }
' "$project_brief_file" >/dev/null 2>&1; then
  brief_customer_evidence_present=true
fi
hotfix_status="$(awk '/^- Status:/{sub(/^- Status:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
hotfix_status="$(trim_whitespace "$hotfix_status")"
if is_placeholder_value "$hotfix_status" || [[ "$hotfix_status" == "inactive / active / resolved" ]]; then
  hotfix_status=""
fi
hotfix_status="${hotfix_status:-inactive}"
hotfix_summary="$(awk '/^- Hotfix summary:/{sub(/^- Hotfix summary:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
hotfix_summary="$(trim_whitespace "$hotfix_summary")"
if is_placeholder_value "$hotfix_summary"; then
  hotfix_summary=""
fi

tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
task_info="$(effective_task_record "$target_dir")"
active_task="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("task",""))')"
active_task_state="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("state",""))')"
active_spec="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("spec",""))')"
active_workspace_path="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("workspace",""))')"
active_handoff_path="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("handoff",""))')"
active_task_manifest=""
if [[ -n "$active_task" ]]; then
  ensure_task_workspace "$target_dir" "$active_task" "${active_task_state:-n/a}" "${active_spec:-n/a}"
  update_task_manifest "$target_dir" "$active_task" "${active_task_state:-n/a}" "${active_spec:-n/a}" "" "" "$next_step" "$next_step"
  active_task_manifest="$(display_project_relpath "$target_dir" "$(task_manifest_relpath "$active_task")")"
fi
active_spec_file=""
if [[ -n "$active_spec" && "$active_spec" != "n/a" ]]; then
  active_spec_file="$(project_file_path "$target_dir" "$active_spec")"
fi
task_manifest_json="{}"
if [[ -n "$active_task" ]]; then
  task_manifest_json="$(task_manifest_json "$target_dir" "$active_task")"
fi
active_release_risk="$(printf '%s' "$task_manifest_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("release_risk",""))' 2>/dev/null || true)"
active_risk_class="$(printf '%s' "$task_manifest_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("risk_class",""))' 2>/dev/null || true)"
if [[ -z "$active_release_risk" && -n "$active_spec_file" && -f "$active_spec_file" ]]; then
  active_release_risk="$(printf '%s' "$(spec_metadata_json "$active_spec_file")" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("release_risk",""))' 2>/dev/null || true)"
fi
if [[ -z "$active_risk_class" && -n "$active_spec_file" && -f "$active_spec_file" ]]; then
  active_risk_class="$(printf '%s' "$(spec_metadata_json "$active_spec_file")" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("risk_class",""))' 2>/dev/null || true)"
fi
active_release_risk="$(trim_whitespace "${active_release_risk//\`/}")"
active_risk_class="$(trim_whitespace "${active_risk_class//\`/}")"
if is_placeholder_value "$active_release_risk"; then active_release_risk=""; fi
if is_placeholder_value "$active_risk_class"; then active_risk_class=""; fi
active_release_risk="${active_release_risk:-n/a}"
active_risk_class="${active_risk_class:-n/a}"
planned_count="$(count_tasks_in_section "$tasks_file" "## Planned")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
blocked_count="$(count_tasks_in_section "$tasks_file" "## Blocked")"
done_count="$(count_tasks_in_section "$tasks_file" "## Done" "done")"
cancelled_count="$(count_tasks_in_section "$tasks_file" "## Cancelled")"
ready_limit="$(task_limit_for_section "$tasks_file" "## Ready")"
in_progress_limit="$(task_limit_for_section "$tasks_file" "## In Progress")"
open_questions="$(count_open_questions "$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")")"
active_risks="$(count_active_risks "$(project_file_path "$target_dir" "RISK_REGISTER.md")")"
active_blockers="$(safe_grep_count '^- Blocker:' "$(project_file_path "$target_dir" "BLOCKERS.md")")"
active_claims="$(safe_grep_count '^## Claim ' "$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")")"
manual_test_readiness="$(awk '
  /^- Manual-test readiness:/ { capture = 1; next }
  capture && /^  - / {
    value = $0
    sub(/^  - /, "", value)
    print value
    exit
  }
' "$(project_file_path "$target_dir" "MANUAL_CHECKS.md")" 2>/dev/null || true)"
manual_test_readiness="$(trim_whitespace "$manual_test_readiness")"
manual_test_readiness="${manual_test_readiness//\`/}"
if is_placeholder_value "$manual_test_readiness"; then
  manual_test_readiness=""
fi
manual_test_readiness="${manual_test_readiness:-n/a}"
active_claim_ids_json="$(python3 - "$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print("[]")
    raise SystemExit(0)

ids = []
for line in path.read_text().splitlines():
    if line.startswith("- Claim ID:"):
        ids.append(line.split(":",1)[1].strip())
print(json.dumps(ids))
PY
)"
active_experiments="$(safe_grep_count '^- Experiment:[[:space:]]*[^[:space:]].+' "$(project_file_path "$target_dir" "EXPERIMENTS.md")")"
running_experiments="$(safe_grep_count '^[[:space:]]*Status:[[:space:]]*(proposed|running|observing)' "$(project_file_path "$target_dir" "EXPERIMENTS.md")")"
stale_claim_count="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("stale_claims", [])))' 2>/dev/null || printf '0')"
last_verification="$(last_verification_result "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
continuity_status="current"
if ! "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1; then
  continuity_status="stale"
fi
score="$(awk '/^- Score:/{sub(/^- Score:[[:space:]]*/,""); print; exit}' "$(project_file_path "$target_dir" "METHODOLOGY_SCORE.md")" 2>/dev/null || true)"
score="$(trim_whitespace "$score")"
score="${score:-0}"
recommended_startup_profile="normal"
if [[ "$hotfix_status" == "active" || "$continuity_status" == "stale" || "$stale_claim_count" != "0" ]]; then
  recommended_startup_profile="deep"
elif [[ -n "$active_workspace_path" ]]; then
  recommended_startup_profile="minimal"
fi
next_recommended_command="$(if [[ -n "$active_task" ]]; then printf '/home/eyal/system-docs/methodology/progress-checkpoint.sh --task %q --summary %q %q' "$active_task" "Update progress and verification state." "$target_dir"; else printf '/home/eyal/system-docs/methodology/methodology-entry.sh --profile %q %q' "$recommended_startup_profile" "$target_dir"; fi)"

cat > "$(project_file_path "$target_dir" "methodology-state.json")" <<EOF
{
  "schema_version": "$(json_escape "$METHODOLOGY_SCHEMA_VERSION")",
  "generator_version": "$(json_escape "$METHODOLOGY_GENERATOR_VERSION")",
  "project_name": "$(json_escape "$(basename "$target_dir")")",
  "maturity_mode": "$(json_escape "$mode")",
  "work_type": "$(json_escape "$work_type")",
  "delegation_policy": "$(json_escape "$delegation_policy")",
  "current_branch": "$(json_escape "$branch")",
  "template_source_mode": $( [[ "$mode" == "template_source" ]] && printf true || printf false ),
  "business_owner": "$(json_escape "$brief_business_owner")",
  "leading_metric": "$(json_escape "$brief_leading_metric")",
  "guardrail_metrics": "$(json_escape "$brief_guardrail_metrics")",
  "launch_window": "$(json_escape "$brief_launch_window")",
  "decision_deadline": "$(json_escape "$brief_decision_deadline")",
  "review_date": "$(json_escape "$brief_review_date")",
  "customer_signal": "$(json_escape "$brief_customer_signal")",
  "customer_evidence_present": $brief_customer_evidence_present,
  "hotfix_status": "$(json_escape "$hotfix_status")",
  "hotfix_active": $( [[ "$hotfix_status" == "active" ]] && printf true || printf false ),
  "hotfix_summary": "$(json_escape "$hotfix_summary")",
  "active_task": "$(json_escape "$active_task")",
  "active_task_state": "$(json_escape "$active_task_state")",
  "active_spec": "$(json_escape "$active_spec")",
  "active_task_manifest": "$(json_escape "$active_task_manifest")",
  "active_release_risk": "$(json_escape "$active_release_risk")",
  "active_risk_class": "$(json_escape "$active_risk_class")",
  "active_workspace_path": "$(json_escape "${active_workspace_path:-$(if [[ -n "$active_task" ]]; then display_project_relpath "$target_dir" "$(task_state_relpath "$active_task")"; fi)}")",
  "active_handoff_path": "$(json_escape "${active_handoff_path:-$(if [[ -n "$active_task" ]]; then display_project_relpath "$target_dir" "$(task_handoff_relpath "$active_task")"; fi)}")",
  "current_task_state_file": "$(json_escape "$(if [[ -n "$active_task" ]]; then display_project_relpath "$target_dir" "$(task_state_relpath "$active_task")"; fi)")",
  "manual_test_readiness": "$(json_escape "$manual_test_readiness")",
  "continuity_status": "$(json_escape "$continuity_status")",
  "recommended_startup_profile": "$(json_escape "$recommended_startup_profile")",
  "next_step": "$(json_escape "$next_step")",
  "next_recommended_command": "$(json_escape "$next_recommended_command")",
  "task_counts": {
    "planned": $planned_count,
    "ready": $ready_count,
    "in_progress": $in_progress_count,
    "blocked": $blocked_count,
    "done": $done_count,
    "cancelled": $cancelled_count
  },
  "wip_limits": {
    "ready": $ready_limit,
    "in_progress": $in_progress_limit
  },
  "open_questions": $open_questions,
  "active_risks": $active_risks,
  "active_blockers": $active_blockers,
  "active_claims": $active_claims,
  "active_claim_ids": $active_claim_ids_json,
  "active_experiments": $active_experiments,
  "running_experiments": $running_experiments,
  "stale_claim_count": $stale_claim_count,
  "last_verification_result": "$(json_escape "$last_verification")",
  "methodology_score": $score,
  "updated_at": "$(json_escape "$(timestamp_now)")"
}
EOF

echo "Refreshed methodology-state.json for $target_dir"
