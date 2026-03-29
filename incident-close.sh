#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: incident-close.sh --id INCIDENT_ID [options] [target-directory]

Marks an incident as closed and records fix/follow-up details.
EOF
}

target_arg=""
incident_id=""
fix_text="fix not recorded"
follow_up="none recorded"
learning_target=""
learning_note=""
learning_review_by=""

while (($# > 0)); do
  case "$1" in
    --id) incident_id="$2"; shift 2 ;;
    --fix) fix_text="$2"; shift 2 ;;
    --follow-up) follow_up="$2"; shift 2 ;;
    --learning-target) learning_target="$2"; shift 2 ;;
    --learning-note) learning_note="$2"; shift 2 ;;
    --learning-review-by) learning_review_by="$2"; shift 2 ;;
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

if [[ -z "$incident_id" ]]; then
  echo "--id is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
incidents_file="$(project_file_path "$target_dir" "INCIDENTS.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"
python3 - "$incidents_file" "$incident_id" "$fix_text" "$follow_up" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
incident_id = sys.argv[2]
fix_text = sys.argv[3]
follow_up = sys.argv[4]
lines = path.read_text().splitlines()
out = []
in_target = False
found = False
for line in lines:
    if line == f"## Incident {incident_id}":
        in_target = True
        found = True
        out.append(line)
        continue
    if line.startswith("## ") and in_target:
        in_target = False
    if in_target:
        if line.startswith("- Status:"):
            out.append("- Status: closed")
            continue
        if line.startswith("- Fix:"):
            out.append(f"- Fix: {fix_text}")
            continue
        if line.startswith("- Follow-up actions:"):
            out.append(f"- Follow-up actions: {follow_up}")
            continue
    out.append(line)

if not found:
    raise SystemExit(f"Incident not found: {incident_id}")

path.write_text("\n".join(out) + "\n")
PY

health_body=$(cat <<EOF
- Incident closed at: $(timestamp_now)
- Incident ID: ${incident_id}
- Fix: ${fix_text}
- Follow-up: ${follow_up}
EOF
)
append_or_replace_auto_section "$project_health_file" "incident-close" "## Resolved Incident" "$health_body"

if [[ -n "$learning_target" && -n "$learning_note" ]]; then
  learning_args=(--target "$learning_target" --summary "$learning_note")
  if [[ -n "$learning_review_by" ]]; then
    learning_args+=(--review-by "$learning_review_by")
  fi
  "$SCRIPT_DIR/record-learning.sh" "${learning_args[@]}" "$target_dir" >/dev/null
fi

echo "Closed incident: $incident_id"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
