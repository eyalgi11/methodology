#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: decision-review.sh [--json] [target-directory]

Finds ADR records that are missing review dates or have overdue review dates.
EOF
}

target_arg=""
json_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
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
decisions_file="$(project_file_path "$target_dir" "DECISIONS.md")"
issues=()

mapfile -t review_issues < <(python3 - "$decisions_file" "$(today_date)" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
today = dt.date.fromisoformat(sys.argv[2])
if not path.exists():
    raise SystemExit(0)

sections = []
current = None
in_comment = False
for line in path.read_text().splitlines():
    stripped = line.strip()
    if stripped.startswith("<!--"):
        in_comment = True
    if in_comment:
        if stripped.endswith("-->"):
            in_comment = False
        continue
    if line.startswith("## ADR-"):
        if current:
            sections.append(current)
        current = {"title": line[3:].strip(), "review_by": "", "status": "active"}
        continue
    if current is None:
        continue
    if line.startswith("- Review by:"):
        current["review_by"] = line.split(":", 1)[1].strip()
    elif line.startswith("- Status:"):
        current["status"] = line.split(":", 1)[1].strip().lower() or "active"
if current:
    sections.append(current)

for section in sections:
    title = section["title"]
    status = section["status"]
    review_by = section["review_by"]
    if status in {"superseded", "rejected", "archived"}:
        continue
    if not review_by:
        print(f"{title}: missing review date")
        continue
    try:
        review_date = dt.date.fromisoformat(review_by)
    except ValueError:
        print(f"{title}: invalid review date {review_by}")
        continue
    if review_date < today:
        print(f"{title}: review date {review_by} is overdue")
PY
)

if (( ${#review_issues[@]} > 0 )); then
  issues+=("${review_issues[@]}")
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "Decision review check passed."
  else
    echo "Decision review issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
exit 1
