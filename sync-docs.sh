#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: sync-docs.sh [target-directory]

Refreshes auto summary sections across SESSION_STATE.md, HANDOFF.md,
PROJECT_HEALTH.md, and MILESTONES.md using current task/risk/question state.
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
in_progress_count="$(count_tasks_in_section "$tasks_file" "## In Progress")"
ready_count="$(count_tasks_in_section "$tasks_file" "## Ready")"
done_count="$(count_tasks_in_section "$tasks_file" "## Done" "done")"
next_task="$(first_real_task_in_section "$tasks_file" "## In Progress")"
if [[ -z "$next_task" ]]; then
  next_task="$(first_real_task_in_section "$tasks_file" "## Ready")"
fi
next_task="${next_task:-No ready task recorded.}"

question_count="$(count_open_questions "$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")")"
risk_count="$(count_active_risks "$(project_file_path "$target_dir" "RISK_REGISTER.md")")"
milestone_name="$(awk '/## Current Milestone/{flag=1; next} /## /{if(flag) exit} flag && /- Name:/{sub(/- Name:[[:space:]]*/,""); print; exit}' "$(project_file_path "$target_dir" "MILESTONES.md")" 2>/dev/null || true)"
milestone_name="${milestone_name:-Unset}"

sync_body=$(cat <<EOF
- Synced at: $(timestamp_now)
- In progress tasks: ${in_progress_count}
- Ready tasks: ${ready_count}
- Done tasks: ${done_count}
- Next task: ${next_task}
- Open questions: ${question_count}
- Active risks: ${risk_count}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "doc-sync" "## Auto Sync" "$sync_body"
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "doc-sync" "## Auto Sync" "$sync_body"

health_status="green"
if (( risk_count > 0 || question_count > 3 )); then
  health_status="yellow"
fi
if (( risk_count > 3 )); then
  health_status="red"
fi

health_body=$(cat <<EOF
- Synced at: $(timestamp_now)
- Health: ${health_status}
- Current milestone: ${milestone_name}
- Next task: ${next_task}
- Open questions: ${question_count}
- Active risks: ${risk_count}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "PROJECT_HEALTH.md")" "doc-sync" "## Auto Sync Summary" "$health_body"

milestone_body=$(cat <<EOF
- Synced at: $(timestamp_now)
- Current milestone: ${milestone_name}
- In progress tasks: ${in_progress_count}
- Ready tasks: ${ready_count}
- Recommended next focus: ${next_task}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "MILESTONES.md")" "doc-sync" "## Auto Sync Summary" "$milestone_body"

echo "Synchronized methodology summaries for $target_dir"
echo "Next task: $next_task"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/archive-cold-docs.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/refresh-core-context.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/compact-hot-docs.sh" "$target_dir" >/dev/null 2>&1 || true
