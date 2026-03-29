#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: record-learning.sh --target TARGET --summary "Lesson" [options] [target-directory]

Stores a durable lesson in anti-patterns, working agreements, or decisions.

Targets:
  anti-pattern
  working-agreement
  decision
EOF
}

target_arg=""
learning_target=""
summary=""
title=""
context="Derived from incident, regression, or rework."
review_by=""

while (($# > 0)); do
  case "$1" in
    --target) learning_target="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --context) context="$2"; shift 2 ;;
    --review-by) review_by="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
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

if [[ -z "$learning_target" || -z "$summary" ]]; then
  echo "--target and --summary are required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
review_by="${review_by:-$(date -d '+30 days' '+%Y-%m-%d')}"
anti_patterns_file="$(project_file_path "$target_dir" "ANTI_PATTERNS.md")"
working_agreements_file="$(project_file_path "$target_dir" "WORKING_AGREEMENTS.md")"
decisions_file="$(project_file_path "$target_dir" "DECISIONS.md")"

case "$learning_target" in
  anti-pattern)
    printf '\n- %s\n' "$summary" >> "$anti_patterns_file"
    ;;
  working-agreement)
    python3 - "$working_agreements_file" "$summary" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
summary = sys.argv[2]
lines = path.read_text().splitlines()
out = []
inserted = False
in_section = False
for line in lines:
    if line == "## Learning Loop":
        in_section = True
        out.append(line)
        continue
    if line.startswith("## ") and in_section and not inserted:
        out.append(f"- {summary}")
        inserted = True
        in_section = False
    out.append(line)
if in_section and not inserted:
    out.append(f"- {summary}")
    inserted = True
if not inserted:
    if out and out[-1] != "":
        out.append("")
    out.extend(["## Captured Learnings", f"- {summary}"])
path.write_text("\n".join(out) + "\n")
PY
    ;;
  decision)
    python3 - "$decisions_file" "${title:-$summary}" "$context" "$summary" "$review_by" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
title = sys.argv[2]
context = sys.argv[3]
decision = sys.argv[4]
review_by = sys.argv[5]
text = path.read_text() if path.exists() else "# Decisions\n"
matches = []
in_comment = False
for raw_line in text.splitlines():
    stripped = raw_line.strip()
    if stripped.startswith("<!--"):
        in_comment = True
    if in_comment:
        if stripped.endswith("-->"):
            in_comment = False
        continue
    match = re.match(r"## ADR-(\d+):", raw_line)
    if match:
        matches.append(int(match.group(1)))
next_num = max(matches, default=0) + 1
entry = (
    f"\n## ADR-{next_num:03d}: {title}\n"
    f"- Date: {__import__('datetime').date.today().isoformat()}\n"
    f"- Context: {context}\n"
    f"- Options considered: pending\n"
    f"- Decision: {decision}\n"
    f"- Consequences: pending\n"
    f"- Review by: {review_by}\n"
    f"- Status: active\n"
)
path.write_text(text.rstrip() + "\n" + entry)
PY
    ;;
  *)
    echo "Invalid --target: $learning_target" >&2
    exit 1
    ;;
esac

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Recorded learning in $learning_target for $target_dir"
