#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: adopt-methodology.sh [target-directory]

Adopts the methodology into an existing codebase without overwriting existing
project files. This adds missing methodology files, runs repo discovery, and
rehydrates the project state.
EOF
}

target_arg=""

while (($# > 0)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="${target_arg:-$PWD}"
target_dir="$(resolve_target_dir "$target_dir")"
ensure_git_repo "$target_dir"

echo "Checking layout..."
bash "$SCRIPT_DIR/migrate-methodology-layout.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Bootstrapping methodology..."
"$SCRIPT_DIR/bootstrap-methodology.sh" "$target_dir" >/dev/null
echo "Running repo intake..."
"$SCRIPT_DIR/repo-intake.sh" "$target_dir" >/dev/null
echo "Extracting repo knowledge..."
"$SCRIPT_DIR/knowledge-extract.sh" "$target_dir" >/dev/null
"$SCRIPT_DIR/archive-cold-docs.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Re-entering through methodology..."
"$SCRIPT_DIR/methodology-entry.sh" "$target_dir" >/dev/null

echo "Methodology adopted into existing codebase: $target_dir"
echo "Recommended next steps:"
echo "  1. Fill in PROJECT_BRIEF.md with the real project context"
echo "  2. Update TASKS.md and SESSION_STATE.md to reflect the actual next work"
echo "  3. Run methodology-audit.sh to see which templates still need real content"
