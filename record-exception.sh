#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: record-exception.sh --summary "Skipped step" --reason "Why" [options] [target-directory]

Records a documented process exception for cases where the normal methodology
was intentionally bypassed.
EOF
}

target_arg=""
summary=""
reason=""
risk_level="medium"
compensating_control="documented local control"
owner="Lead"
status="open"
approved_by="Lead"
expires_on="next review"
ci_fail_after_expiry="yes"
backfill="not scheduled"
evidence="pending"
related_task="n/a"
related_release="n/a"

while (($# > 0)); do
  case "$1" in
    --summary) summary="$2"; shift 2 ;;
    --reason) reason="$2"; shift 2 ;;
    --risk-level) risk_level="$2"; shift 2 ;;
    --compensating-control) compensating_control="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --approved-by) approved_by="$2"; shift 2 ;;
    --expires-on) expires_on="$2"; shift 2 ;;
    --ci-fail-after-expiry) ci_fail_after_expiry="$2"; shift 2 ;;
    --backfill) backfill="$2"; shift 2 ;;
    --evidence) evidence="$2"; shift 2 ;;
    --task) related_task="$2"; shift 2 ;;
    --release) related_release="$2"; shift 2 ;;
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

if [[ -z "$summary" || -z "$reason" ]]; then
  echo "--summary and --reason are required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
exceptions_file="$(project_file_path "$target_dir" "PROCESS_EXCEPTIONS.md")"
{
  printf '\n## Exception - %s\n' "$(timestamp_now)"
  printf -- '- Exception: %s\n' "$summary"
  printf -- '- Reason: %s\n' "$reason"
  printf -- '- Risk level: %s\n' "$risk_level"
  printf -- '- Compensating control: %s\n' "$compensating_control"
  printf -- '- Owner: %s\n' "$owner"
  printf -- '- Status: %s\n' "$status"
  printf -- '- Approved by: %s\n' "$approved_by"
  printf -- '- Expires on: %s\n' "$expires_on"
  printf -- '- CI fail after expiry: %s\n' "$ci_fail_after_expiry"
  printf -- '- Backfill required by: %s\n' "$backfill"
  printf -- '- Evidence of backfill: %s\n' "$evidence"
  printf -- '- Related task / spec: %s\n' "$related_task"
  printf -- '- Related release / incident: %s\n' "$related_release"
} >> "$exceptions_file"

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Recorded process exception for $target_dir"
