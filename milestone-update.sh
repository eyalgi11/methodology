#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: milestone-update.sh [target-directory]

Updates MILESTONES.md and PROJECT_HEALTH.md with an auto-generated delivery
summary based on tasks, risks, questions, and verification state.
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
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
open_questions_file="$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")"
risk_register_file="$(project_file_path "$target_dir" "RISK_REGISTER.md")"
milestones_file="$(project_file_path "$target_dir" "MILESTONES.md")"
verification_log_file="$(project_file_path "$target_dir" "VERIFICATION_LOG.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"

in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
question_count="$(count_open_questions "$open_questions_file")"
risk_count="$(count_active_risks "$risk_register_file")"
high_risk_count="$(count_high_risks "$risk_register_file")"
current_milestone_name="$(awk '/## Current Milestone/{flag=1; next} /## /{if(flag) exit} flag && /- Name:/{sub(/- Name:[[:space:]]*/,""); print; exit}' "$milestones_file" 2>/dev/null)"
current_milestone_name="${current_milestone_name:-Unset}"
last_verification="$(last_verification_result "$verification_log_file")"

confidence="high"
if (( risk_count > 0 || ready_count > 5 || question_count > 3 )); then
  confidence="medium"
fi
if (( high_risk_count > 0 || question_count > 6 )); then
  confidence="low"
fi

milestone_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Current milestone: ${current_milestone_name}
- Confidence: ${confidence}
- In progress tasks: ${in_progress_count}
- Ready tasks: ${ready_count}
- Open questions: ${question_count}
- Active risks: ${risk_count}
- Last verification result: ${last_verification}
EOF
)
append_or_replace_auto_section "$milestones_file" "milestone-update" "## Auto Delivery Summary" "$milestone_body"

health_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Milestone: ${current_milestone_name}
- Milestone confidence: ${confidence}
- Last verification result: ${last_verification}
- High-severity risks: ${high_risk_count}
- Open questions: ${question_count}
EOF
)
append_or_replace_auto_section "$project_health_file" "milestone-update" "## Milestone Health" "$health_body"

echo "Updated milestone summary for $target_dir"
echo "Confidence: $confidence"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
