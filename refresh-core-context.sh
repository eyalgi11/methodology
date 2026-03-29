#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: refresh-core-context.sh [target-directory]

Refreshes CORE_CONTEXT.md as the compact session-start summary for the project.
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
next_step="$(best_next_step "$target_dir")"
next_step="${next_step:-Review TASKS.md and pick the next concrete step.}"
last_verification="$(last_verification_result "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
open_questions="$(count_open_questions "$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")")"
active_risks="$(count_active_risks "$(project_file_path "$target_dir" "RISK_REGISTER.md")")"
active_experiments="$(safe_grep_count '^- Experiment:[[:space:]]*[^[:space:]].+' "$(project_file_path "$target_dir" "EXPERIMENTS.md")")"
recommended_profile="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("recommended_startup_profile","normal"))' "$(project_file_path "$target_dir" "methodology-state.json")" 2>/dev/null || printf 'normal')"

task_info="$(effective_task_record "$target_dir")"
task_name="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("task","Define initial project brief and first task"))')"
task_state="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("state","setup"))')"
spec_path="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("spec",""))')"

hotfix_status="$(awk '/^- Status:/{sub(/^- Status:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
hotfix_status="$(trim_whitespace "$hotfix_status")"
if [[ "$hotfix_status" == "active" ]]; then
  hotfix_summary="$(awk '/^- Hotfix summary:/{sub(/^- Hotfix summary:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
  hotfix_summary="$(trim_whitespace "$hotfix_summary")"
  hotfix_next="$(awk '/^- Exit criteria:/{sub(/^- Exit criteria:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
  hotfix_next="$(trim_whitespace "$hotfix_next")"
  task_name="HOTFIX: ${hotfix_summary:-Runtime stabilization}"
  task_state="hotfix"
  spec_path=""
  next_step="${hotfix_next:-Finish the runtime stabilization, then refresh TASKS.md and HANDOFF.md before resuming planned work.}"
fi

manual_readiness="$(awk '
  /^- Manual-test readiness:/ { capture = 1; next }
  capture && /^  - / {
    value = $0
    sub(/^  - /, "", value)
    print value
    exit
  }
' "$(project_file_path "$target_dir" "MANUAL_CHECKS.md")" 2>/dev/null || true)"
manual_readiness="$(trim_whitespace "$manual_readiness")"
manual_readiness="${manual_readiness:-n/a}"
task_workspace_rel="n/a"
task_handoff_rel="n/a"
if [[ -n "$task_name" && "$task_name" != "Define initial project brief and first task" ]]; then
  task_workspace_rel="$(display_project_relpath "$target_dir" "$(task_state_relpath "$task_name")")"
  task_handoff_rel="$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task_name")")"
fi

cat > "$(project_file_path "$target_dir" "CORE_CONTEXT.md")" <<EOF
# Core Context

- Refreshed at: $(timestamp_now)
- Project: $(basename "$target_dir")
- Mode: $mode
- Recommended startup profile: ${recommended_profile}
- Active task: $task_name
- Task state: $task_state
- Active spec: ${spec_path:-n/a}
- Task workspace: ${task_workspace_rel}
- Task handoff: ${task_handoff_rel}
- Next step: $next_step
- Last verification: $last_verification
- Open questions: $open_questions
- Active risks: $active_risks
- Active experiments: $active_experiments
- Manual-test readiness: $manual_readiness

## Default Read Order
- $(display_project_relpath "$target_dir" "methodology-state.json")
- $(display_project_relpath "$target_dir" "CORE_CONTEXT.md")
- $(display_project_relpath "$target_dir" "WORK_INDEX.md")
- $(display_project_relpath "$target_dir" "TASKS.md")
- $(display_project_relpath "$target_dir" "SESSION_STATE.md")
- $(display_project_relpath "$target_dir" "HANDOFF.md")
$(if [[ "$task_workspace_rel" != "n/a" ]]; then printf -- "- %s\n" "$task_workspace_rel"; fi)
$(if [[ "$task_handoff_rel" != "n/a" ]]; then printf -- "- %s\n" "$task_handoff_rel"; fi)
$(if [[ -n "$spec_path" ]]; then printf -- "- %s\n" "$spec_path"; fi)

## Load On Demand
- $(display_project_relpath "$target_dir" "PROJECT_BRIEF.md")
- $(display_project_relpath "$target_dir" "ROADMAP.md")
- $(display_project_relpath "$target_dir" "DECISIONS.md")
- $(display_project_relpath "$target_dir" "COMMANDS.md")
- $(display_project_relpath "$target_dir" "REPO_MAP.md")
- $(display_project_relpath "$target_dir" "LOCAL_ENV.md")
- $(display_project_relpath "$target_dir" "HOTFIX.md")
- $(display_project_relpath "$target_dir" "MANUAL_CHECKS.md")
- $(display_project_relpath "$target_dir" "DOCS_ARCHIVE.md")
- $(display_project_relpath "$target_dir" "docs-archive-index.json")
- $(display_project_relpath "$target_dir" "RISK_REGISTER.md")
- $(display_project_relpath "$target_dir" "OPEN_QUESTIONS.md")
- $(display_project_relpath "$target_dir" "PROJECT_HEALTH.md")
- $(display_project_relpath "$target_dir" "EXPERIMENTS.md")
- $(display_project_relpath "$target_dir" "EXPERIMENT_LOG.md")

## Source Of Truth
- TASKS.md: lifecycle truth
- WORK_INDEX.md: active-workspace pointer truth
- work/<task>/STATE.md: execution truth
- work/<task>/HANDOFF.md: resume truth
- ACTIVE_CLAIMS.md plus claims/<claim-id>.md: ownership truth
- LOCAL_ENV.md: runtime truth
- HOTFIX.md: override truth during runtime stabilization
EOF

echo "Refreshed CORE_CONTEXT.md for $target_dir"
