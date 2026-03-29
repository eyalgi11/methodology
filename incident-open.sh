#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: incident-open.sh --summary "Incident summary" [options] [target-directory]

Appends a new incident record to INCIDENTS.md and updates PROJECT_HEALTH.md.
EOF
}

target_arg=""
summary=""
impact="impact not recorded"
severity="medium"
while (($# > 0)); do
  case "$1" in
    --summary) summary="$2"; shift 2 ;;
    --impact) impact="$2"; shift 2 ;;
    --severity) severity="$2"; shift 2 ;;
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

if [[ -z "$summary" ]]; then
  echo "--summary is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
incidents_file="$(project_file_path "$target_dir" "INCIDENTS.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"
incident_id="$(today_date)-$(slugify "$summary")"

{
  printf '\n## Incident %s\n' "$incident_id"
  printf -- '- Date: %s\n' "$(timestamp_now)"
  printf -- '- Summary: %s\n' "$summary"
  printf -- '- Impact: %s\n' "$impact"
  printf -- '- Severity: %s\n' "$severity"
  printf -- '- Status: open\n'
  printf -- '- Root cause: pending\n'
  printf -- '- Fix: pending\n'
  printf -- '- Follow-up actions: pending\n'
} >> "$incidents_file"

health_body=$(cat <<EOF
- Incident opened at: $(timestamp_now)
- Incident ID: ${incident_id}
- Severity: ${severity}
- Summary: ${summary}
EOF
)
append_or_replace_auto_section "$project_health_file" "incident-open" "## Active Incident" "$health_body"

echo "Opened incident: $incident_id"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
