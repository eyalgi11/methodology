#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: recovery-check.sh [--json] [--repair] [target-directory]

Runs the deterministic recovery checklist for lost context or stale continuity.
EOF
}

target_arg=""
json_mode=0
repair_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --repair) repair_mode=1; shift ;;
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
context_file="$(mktemp "/tmp/$(slugify "$(basename "$target_dir")")-recovery-XXXXXX.md")"
"$SCRIPT_DIR/resume-work.sh" --profile minimal --output "$context_file" "$target_dir" >/dev/null

stale_claims_json="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null || printf '{"stale_claims":[]}')"
stale_claim_count="$(python3 -c 'import json,sys; print(len(json.loads(sys.stdin.read()).get("stale_claims", [])))' <<<"$stale_claims_json" 2>/dev/null || printf '0')"
task_info="$(effective_task_record "$target_dir")"
active_task="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_info" 2>/dev/null || true)"
hotfix_status="$(awk '/^- Status:/{sub(/^- Status:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)"
hotfix_status="$(trim_whitespace "$hotfix_status")"
if is_placeholder_value "$hotfix_status" || [[ "$hotfix_status" == "inactive / active / resolved" ]]; then
  hotfix_status="inactive"
fi
latest_work="$(latest_work_file_info "$target_dir" || true)"
git_delta="$(git_status_short "$target_dir" || true)"
work_index_path="$(project_file_path "$target_dir" "WORK_INDEX.md")"
work_index_ok="yes"
if [[ -n "$active_task" && "$active_task" != "setup" ]] && ! grep -Fq -- "- Task: $active_task" "$work_index_path" 2>/dev/null; then
  work_index_ok="no"
fi

repair_actions=()
if (( repair_mode == 1 )); then
  if ! "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1; then
    "$SCRIPT_DIR/session-snapshot.sh" --next-step "$(best_next_step "$target_dir")" "$target_dir" >/dev/null 2>&1 || true
    repair_actions+=("session-snapshot")
  fi
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
  "$SCRIPT_DIR/refresh-core-context.sh" "$target_dir" >/dev/null 2>&1 || true
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"context_pack":"%s",' "$(json_escape "$context_file")"
  printf '"active_task":"%s",' "$(json_escape "$active_task")"
  printf '"work_index_ok":"%s",' "$(json_escape "$work_index_ok")"
  printf '"stale_claim_count":%s,' "$stale_claim_count"
  printf '"hotfix_status":"%s",' "$(json_escape "$hotfix_status")"
  printf '"git_status":"%s",' "$(json_escape "$git_delta")"
  printf '"repair_actions":'
  print_json_array repair_actions
  printf '}\n'
else
  echo "Recovery check completed for $target_dir"
  echo "Context pack: $context_file"
  echo "Active task: ${active_task:-n/a}"
  echo "Work index points correctly: $work_index_ok"
  echo "Stale claims: $stale_claim_count"
  echo "Hotfix status: ${hotfix_status:-inactive}"
  echo "Git status:"
  if [[ -n "$git_delta" ]]; then
    printf '%s\n' "$git_delta"
  else
    echo "  clean"
  fi
  if (( ${#repair_actions[@]} > 0 )); then
    echo "Repair actions:"
    printf '  - %s\n' "${repair_actions[@]}"
  fi
fi
