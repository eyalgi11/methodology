#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: record-methodology-failure.sh --summary "Failure" --location "Where" --expected "Expected" --actual "Actual" --improvement "Suggested improvement" [options] [target-directory]

Records a methodology failure observed inside a methodology-managed project so it
can feed back into future toolkit improvements.
EOF
}

target_arg=""
summary=""
location=""
trigger="not recorded"
expected=""
actual=""
impact="not recorded"
workaround="not recorded"
improvement=""
owner="Lead"
status="open"
source_follow_up="not yet filed"
evidence="pending"

while (($# > 0)); do
  case "$1" in
    --summary) summary="$2"; shift 2 ;;
    --location) location="$2"; shift 2 ;;
    --trigger) trigger="$2"; shift 2 ;;
    --expected) expected="$2"; shift 2 ;;
    --actual) actual="$2"; shift 2 ;;
    --impact) impact="$2"; shift 2 ;;
    --workaround) workaround="$2"; shift 2 ;;
    --improvement) improvement="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --source-follow-up) source_follow_up="$2"; shift 2 ;;
    --evidence) evidence="$2"; shift 2 ;;
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

if [[ -z "$summary" || -z "$location" || -z "$expected" || -z "$actual" || -z "$improvement" ]]; then
  echo "--summary, --location, --expected, --actual, and --improvement are required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
failures_file="$(project_file_path "$target_dir" "METHODOLOGY_FAILURES.md")"

{
  printf '\n## Methodology Failure - %s\n' "$(timestamp_now)"
  printf -- '- Date observed: %s\n' "$(timestamp_now)"
  printf -- '- Failure: %s\n' "$summary"
  printf -- '- Where it failed: %s\n' "$location"
  printf -- '- Trigger / reproduction: %s\n' "$trigger"
  printf -- '- Expected methodology behavior: %s\n' "$expected"
  printf -- '- Actual behavior: %s\n' "$actual"
  printf -- '- Impact on work: %s\n' "$impact"
  printf -- '- Workaround used: %s\n' "$workaround"
  printf -- '- Suggested improvement: %s\n' "$improvement"
  printf -- '- Owner: %s\n' "$owner"
  printf -- '- Status: %s\n' "$status"
  printf -- '- Source repo follow-up: %s\n' "$source_follow_up"
  printf -- '- Evidence / related task / spec: %s\n' "$evidence"
} >> "$failures_file"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Recorded methodology failure for $target_dir"

