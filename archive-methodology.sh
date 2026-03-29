#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: archive-methodology.sh [target-directory]

Archives completed tasks and closed incidents into archive/ and resets the
active sections in the live docs.
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
archive_dir="$target_dir/archive"
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
incidents_file="$(project_file_path "$target_dir" "INCIDENTS.md")"
mkdir -p "$archive_dir"
stamp="$(today_date)"

"$SCRIPT_DIR/archive-cold-docs.sh" "$target_dir" >/dev/null 2>&1 || true

done_tasks="$(awk '
  $0 == "## Done" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- \[[xX]\] / { print }
' "$tasks_file" 2>/dev/null || true)"
cancelled_tasks="$(awk '
  $0 == "## Cancelled" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- \[[ xX]\] / { print }
' "$tasks_file" 2>/dev/null || true)"
closed_incidents="$(awk '
  /^## Incident / { if (in_closed) { print block }; block=$0 ORS; in_incident=1; in_closed=0; next }
  in_incident { block = block $0 ORS }
  /- Status: closed/ { in_closed=1 }
  END { if (in_closed) print block }
' "$incidents_file" 2>/dev/null || true)"

if [[ -n "$(trim_whitespace "$done_tasks")" ]]; then
  printf '# Archived Done Tasks - %s\n\n%s\n' "$stamp" "$done_tasks" > "$archive_dir/tasks-done-$stamp.md"
fi
if [[ -n "$(trim_whitespace "$cancelled_tasks")" ]]; then
  printf '# Archived Cancelled Tasks - %s\n\n%s\n' "$stamp" "$cancelled_tasks" > "$archive_dir/tasks-cancelled-$stamp.md"
fi
if [[ -n "$(trim_whitespace "$closed_incidents")" ]]; then
  printf '# Archived Closed Incidents - %s\n\n%s\n' "$stamp" "$closed_incidents" > "$archive_dir/incidents-closed-$stamp.md"
fi

python3 - "$tasks_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text().splitlines()
out = []
current = None
for line in text:
    if line.startswith("## "):
        current = line
        out.append(line)
        continue
    if current in {"## Done", "## Cancelled"}:
        continue
    out.append(line)

result = "\n".join(out) + "\n"
result = result.replace("## Done\n", "## Done\n\n<!-- Completed tasks with verification recorded. -->\n\n")
result = result.replace("## Cancelled\n", "## Cancelled\n\n<!-- Tasks that will not be completed. -->\n\n")
path.write_text(result)
PY

python3 - "$incidents_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
out = []
buffer = []
keep = True
for line in lines:
    if line.startswith("## Incident "):
        if buffer and keep:
          out.extend(buffer)
        buffer = [line]
        keep = True
        continue
    if buffer:
        buffer.append(line)
        if line.strip() == "- Status: closed":
            keep = False
        continue
    out.append(line)
if buffer and keep:
    out.extend(buffer)
path.write_text("\n".join(out) + "\n")
PY

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Archived methodology history into $archive_dir"
