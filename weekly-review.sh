#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: weekly-review.sh [target-directory]

Appends a compact operating review to WEEKLY_REVIEW.md and refreshes score/state.
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
"$SCRIPT_DIR/methodology-score.sh" "$target_dir" >/dev/null
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
open_questions_file="$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")"
risk_register_file="$(project_file_path "$target_dir" "RISK_REGISTER.md")"
blockers_file="$(project_file_path "$target_dir" "BLOCKERS.md")"
score_file="$(project_file_path "$target_dir" "METHODOLOGY_SCORE.md")"
weekly_review_file="$(project_file_path "$target_dir" "WEEKLY_REVIEW.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"

planned_count="$(count_tasks_in_section "$tasks_file" "## Planned")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
done_count="$(count_tasks_in_section "$tasks_file" "## Done" "done")"
question_count="$(count_open_questions "$open_questions_file")"
risk_count="$(count_active_risks "$risk_register_file")"
blocker_count="$(grep -Ec '^- Blocker:' "$blockers_file" 2>/dev/null || true)"
score_value="$(awk '/^- Score:/{sub(/^- Score:[[:space:]]*/,""); print; exit}' "$score_file" 2>/dev/null)"
score_value="$(trim_whitespace "$score_value")"
score_value="${score_value:-0}"

{
  printf '\n## Weekly Review - %s\n' "$(today_date)"
  printf -- '- Generated at: %s\n' "$(timestamp_now)"
  printf -- '- Planned tasks: %s\n' "$planned_count"
  printf -- '- Ready tasks: %s\n' "$ready_count"
  printf -- '- In-progress tasks: %s\n' "$in_progress_count"
  printf -- '- Done tasks: %s\n' "$done_count"
  printf -- '- Open questions: %s\n' "$question_count"
  printf -- '- Active risks: %s\n' "$risk_count"
  printf -- '- Active blockers: %s\n' "$blocker_count"
  printf -- '- Methodology score: %s\n' "$score_value"
} >> "$weekly_review_file"

append_or_replace_auto_section "$project_health_file" "weekly-review" "## Weekly Review Snapshot" "- Last weekly review: $(today_date)
- Methodology score: ${score_value}
- Active blockers: ${blocker_count}"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Appended weekly review for $target_dir"
