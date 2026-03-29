#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: new-experiment.sh --title "..." --hypothesis "..." --metric "..." [options] [target-directory]

Creates a bounded experiment entry in EXPERIMENTS.md.
EOF
}

target_arg=""
title=""
hypothesis=""
metric=""
owner="Lead"
baseline="unknown"
threshold="define threshold"
time_to_signal="define time-to-signal"
max_budget="define max budget / max runs"
stop_rule="stop when threshold is met, risk rises, or budget is exhausted"
rollback_rule="revert to baseline/default behavior"
related="n/a"
next_review="$(today_date)"

while (($# > 0)); do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --hypothesis) hypothesis="$2"; shift 2 ;;
    --metric) metric="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --baseline) baseline="$2"; shift 2 ;;
    --threshold) threshold="$2"; shift 2 ;;
    --time-to-signal) time_to_signal="$2"; shift 2 ;;
    --max-budget) max_budget="$2"; shift 2 ;;
    --stop-rule) stop_rule="$2"; shift 2 ;;
    --rollback-rule) rollback_rule="$2"; shift 2 ;;
    --related) related="$2"; shift 2 ;;
    --next-review) next_review="$2"; shift 2 ;;
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

if [[ -z "$title" || -z "$hypothesis" || -z "$metric" ]]; then
  echo "--title, --hypothesis, and --metric are required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
experiments_file="$(project_file_path "$target_dir" "EXPERIMENTS.md")"

{
  printf '\n- Experiment: %s\n' "$title"
  printf '  Owner: %s\n' "$owner"
  printf '  Hypothesis: %s\n' "$hypothesis"
  printf '  Primary metric: %s\n' "$metric"
  printf '  Baseline: %s\n' "$baseline"
  printf '  Success threshold: %s\n' "$threshold"
  printf '  Time-to-signal: %s\n' "$time_to_signal"
  printf '  Max budget / max runs: %s\n' "$max_budget"
  printf '  Stop rule: %s\n' "$stop_rule"
  printf '  Rollback rule: %s\n' "$rollback_rule"
  printf '  Status: proposed\n'
  printf '  Related task / spec: %s\n' "$related"
  printf '  Next review: %s\n' "$next_review"
} >> "$experiments_file"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Created experiment entry in $experiments_file"
