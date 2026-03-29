#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: methodology-score.sh [target-directory]

Calculates a methodology hygiene score with real coverage, freshness,
execution, and verification signals.
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
score=0

coverage=0
freshness=0
execution=0
verification=0
penalties=0

if [[ "$mode" == "template_source" ]]; then
  if [[ -f "$(project_file_path "$target_dir" "AGENTS.md")" ]]; then coverage=$((coverage + 15)); fi
  if [[ -f "$(project_file_path "$target_dir" "WORK_INDEX.md")" ]]; then coverage=$((coverage + 15)); fi
  if bash "$SCRIPT_DIR/methodology-audit.sh" --json "$target_dir" >/dev/null 2>&1; then coverage=$((coverage + 20)); fi
  score=$((coverage + 50))
else
  ! is_placeholder_file "$target_dir" "PROJECT_BRIEF.md" && coverage=$((coverage + 10))
  ! is_placeholder_file "$target_dir" "COMMANDS.md" && coverage=$((coverage + 10))
  ! is_placeholder_file "$target_dir" "REPO_MAP.md" && coverage=$((coverage + 5))
  ! is_placeholder_file "$target_dir" "WORK_INDEX.md" && coverage=$((coverage + 5))

  if "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1; then freshness=$((freshness + 15)); else penalties=$((penalties + 10)); fi
  if "$SCRIPT_DIR/observable-compliance-check.sh" "$target_dir" >/dev/null 2>&1; then freshness=$((freshness + 10)); else penalties=$((penalties + 10)); fi
  if "$SCRIPT_DIR/stale-claims-check.sh" "$target_dir" >/dev/null 2>&1; then freshness=$((freshness + 5)); else penalties=$((penalties + 5)); fi

  task_info="$(effective_task_record "$target_dir")"
  active_task="$(printf '%s' "$task_info" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("task",""))')"
  if [[ -n "$active_task" ]]; then
    execution=$((execution + 10))
    [[ -f "$(task_state_file "$target_dir" "$active_task")" ]] && execution=$((execution + 5))
    [[ -f "$(task_handoff_file "$target_dir" "$active_task")" ]] && execution=$((execution + 5))
  else
    penalties=$((penalties + 10))
  fi
  if [[ "$(best_next_step "$target_dir")" != "" ]]; then execution=$((execution + 5)); else penalties=$((penalties + 5)); fi

  last_verification="$(last_verification_result "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
  if [[ "$last_verification" == "passed" ]]; then verification=$((verification + 15)); fi
  if ! is_placeholder_file "$target_dir" "MANUAL_CHECKS.md"; then verification=$((verification + 5)); fi
  if "$SCRIPT_DIR/mode-check.sh" --light "$target_dir" >/dev/null 2>&1; then verification=$((verification + 5)); fi
fi

score=$((coverage + freshness + execution + verification - penalties))
(( score < 0 )) && score=0
(( score > 100 )) && score=100

score_body=$(cat <<EOF
- Score: ${score}
- Updated at: $(timestamp_now)
- Coverage: ${coverage}
- Freshness: ${freshness}
- Execution hygiene: ${execution}
- Verification hygiene: ${verification}
- Penalties: ${penalties}
- Meaning:
  - 0-39: weak methodology hygiene
  - 40-69: workable but inconsistent
  - 70-89: strong operating baseline
  - 90-100: very strong methodology hygiene
EOF
)

append_or_replace_auto_section "$(project_file_path "$target_dir" "METHODOLOGY_SCORE.md")" "methodology-score" "## Latest Score" "$score_body"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Methodology score for $target_dir: $score"
