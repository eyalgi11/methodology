#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: set-maturity-mode.sh <prototype|product|production> [target-directory]
EOF
}

mode="${1:-}"
target_arg="${2:-$PWD}"

if [[ -z "$mode" ]]; then
  usage >&2
  exit 1
fi

case "$mode" in
  prototype|product|production|template_source) ;;
  *) echo "Invalid mode: $mode" >&2; exit 1 ;;
esac

target_dir="$(resolve_target_dir "$target_arg")"
mode_file="$(project_file_path "$target_dir" "METHODOLOGY_MODE.md")"

python3 - "$mode_file" "$mode" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
mode = sys.argv[2]
lines = path.read_text().splitlines()
out = []
updated = False
for line in lines:
    if line.startswith("- Mode:"):
        out.append(f"- Mode: {mode}")
        updated = True
    else:
        out.append(line)
if not updated:
    out.insert(1, f"- Mode: {mode}")
path.write_text("\n".join(out) + "\n")
PY

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Set maturity mode to $mode for $target_dir"
