#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: project-dashboard.sh [--json] [target-directory]

Prints a compact summary of project health, continuity, and verification state.
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
mode="$(read_maturity_mode "$target_dir")"
branch="$(current_git_branch "$target_dir")"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || true)"
business_owner="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("business_owner",""))' "$state_file" 2>/dev/null || true)"
leading_metric="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("leading_metric",""))' "$state_file" 2>/dev/null || true)"
customer_signal="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("customer_signal",""))' "$state_file" 2>/dev/null || true)"
decision_deadline="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("decision_deadline",""))' "$state_file" 2>/dev/null || true)"
dirty="clean"
if [[ -n "$(git_status_short "$target_dir")" ]]; then
  dirty="dirty"
fi

tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
task_record="$(effective_task_record "$target_dir")"
active_task="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_record" 2>/dev/null || true)"
active_task_state="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("state",""))' "$task_record" 2>/dev/null || true)"
active_task_workspace="n/a"
if [[ -n "$active_task" && "$active_task" != "setup" ]]; then
  active_task_workspace="$(display_project_relpath "$target_dir" "$(task_state_relpath "$active_task")")"
fi
in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
done_count="$(count_tasks_in_section "$tasks_file" "## Done" "done")"
in_progress_limit="$(task_limit_for_section "$tasks_file" "## In Progress")"
ready_limit="$(task_limit_for_section "$tasks_file" "## Ready")"
next_step="$(best_next_step "$target_dir")"
next_step="${next_step:-n/a}"
milestone_name="$(awk '/## Current Milestone/{flag=1; next} /## /{if(flag) exit} flag && /- Name:/{sub(/- Name:[[:space:]]*/,""); print; exit}' "$(project_file_path "$target_dir" "MILESTONES.md")" 2>/dev/null || true)"
milestone_name="${milestone_name:-Unset}"
last_verification="$(last_verification_result "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
active_claims="$(safe_grep_count '^## Claim ' "$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")")"
active_experiments="$(safe_grep_count '^- Experiment:[[:space:]]*[^[:space:]].+' "$(project_file_path "$target_dir" "EXPERIMENTS.md")")"
running_experiments="$(safe_grep_count '^[[:space:]]*Status:[[:space:]]*(proposed|running|observing)' "$(project_file_path "$target_dir" "EXPERIMENTS.md")")"
active_release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk",""))' "$state_file" 2>/dev/null || true)"
active_risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class",""))' "$state_file" 2>/dev/null || true)"
stale_claims=0
if stale_json="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null)"; then
  stale_claims="$(python3 -c 'import json,sys; print(len(json.loads(sys.stdin.read()).get("stale_claims", [])))' <<<"$stale_json" 2>/dev/null || printf '0')"
fi

status_summary="current"
if ! "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1; then
  status_summary="stale"
fi
drift_summary="ok"
if ! "$SCRIPT_DIR/drift-check.sh" "$target_dir" >/dev/null 2>&1; then
  drift_summary="issues"
fi
verification_entries="$(safe_grep_count '^## Verification Entry - ' "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
claim_ready_signal="partial"
if [[ -n "$active_task" && "$active_task" != "setup" && "$active_task" != "Define initial project brief and first task" ]]; then
  if [[ -n "$active_claims" && "$active_claims" != "0" ]] && [[ -n "$last_verification" && "$last_verification" != "n/a" ]] && [[ -n "$active_task_workspace" && "$active_task_workspace" != "n/a" ]]; then
    claim_ready_signal="covered"
  else
    claim_ready_signal="missing"
  fi
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"mode":"%s",' "$(json_escape "$mode")"
  printf '"work_type":"%s",' "$(json_escape "$work_type")"
  printf '"branch":"%s",' "$(json_escape "$branch")"
  printf '"git_state":"%s",' "$(json_escape "$dirty")"
  printf '"business_owner":"%s",' "$(json_escape "$business_owner")"
  printf '"leading_metric":"%s",' "$(json_escape "$leading_metric")"
  printf '"customer_signal":"%s",' "$(json_escape "$customer_signal")"
  printf '"decision_deadline":"%s",' "$(json_escape "$decision_deadline")"
  printf '"active_task":"%s",' "$(json_escape "$active_task")"
  printf '"active_task_state":"%s",' "$(json_escape "$active_task_state")"
  printf '"active_risk_class":"%s",' "$(json_escape "$active_risk_class")"
  printf '"active_release_risk":"%s",' "$(json_escape "$active_release_risk")"
  printf '"active_task_workspace":"%s",' "$(json_escape "$active_task_workspace")"
  printf '"in_progress":%s,' "$in_progress_count"
  printf '"in_progress_limit":%s,' "$in_progress_limit"
  printf '"ready":%s,' "$ready_count"
  printf '"ready_limit":%s,' "$ready_limit"
  printf '"done":%s,' "$done_count"
  printf '"active_claims":%s,' "$active_claims"
  printf '"active_experiments":%s,' "$active_experiments"
  printf '"running_experiments":%s,' "$running_experiments"
  printf '"stale_claims":%s,' "$stale_claims"
  printf '"verification_entries":%s,' "$verification_entries"
  printf '"claim_coverage":"%s",' "$(json_escape "$claim_ready_signal")"
  printf '"next_step":"%s",' "$(json_escape "$next_step")"
  printf '"milestone":"%s",' "$(json_escape "$milestone_name")"
  printf '"last_verification":"%s",' "$(json_escape "$last_verification")"
  printf '"continuity":"%s",' "$(json_escape "$status_summary")"
  printf '"drift":"%s"' "$(json_escape "$drift_summary")"
  printf '}\n'
else
  cat <<EOF
Project: $target_dir
Mode: $mode
Work type: ${work_type:-product}
Branch: $branch
Git state: $dirty
Business owner: ${business_owner:-n/a}
Leading metric: ${leading_metric:-n/a}
Customer signal: ${customer_signal:-n/a}
Decision deadline: ${decision_deadline:-n/a}
Active task: ${active_task:-n/a} (${active_task_state:-n/a})
Risk: class=${active_risk_class:-n/a} release=${active_release_risk:-n/a}
Task workspace: $active_task_workspace
Tasks: in-progress=$in_progress_count/$in_progress_limit ready=$ready_count/$ready_limit done=$done_count claims=$active_claims stale-claims=$stale_claims experiments=$active_experiments running-experiments=$running_experiments
Agent metrics: verification-entries=$verification_entries claim-coverage=$claim_ready_signal
Current milestone: $milestone_name
Next step: $next_step
Last verification: $last_verification
Continuity status: $status_summary
Drift status: $drift_summary
EOF
fi
