#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: bootstrap-methodology.sh [--surface core|full|auto] [--mode MODE] [target-directory]

Copies missing methodology files into an existing directory.
EOF
}

surface="auto"
mode_override=""
target_dir_arg="$PWD"

while (($# > 0)); do
  case "$1" in
    --surface)
      surface="$2"
      shift 2
      ;;
    --mode)
      mode_override="$2"
      shift 2
      ;;
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
      target_dir_arg="$1"
      shift
      ;;
  esac
done

if [[ "$surface" != "core" && "$surface" != "full" && "$surface" != "auto" ]]; then
  echo "--surface must be one of: core, full, auto" >&2
  exit 1
fi

if [[ ! -d "$target_dir_arg" ]]; then
  echo "Target directory does not exist: $target_dir_arg" >&2
  exit 1
fi

target_dir="$(resolve_target_dir "$target_dir_arg")"
ensure_git_repo "$target_dir"
mkdir -p "$target_dir/$PROJECT_METHODOLOGY_DIR_NAME"
write_toolkit_path_hint "$target_dir"

copy_if_missing() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" ]]; then
    echo "skip  $dst"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  if [[ -f "$dst" ]]; then
    python3 - "$dst" "$SCRIPT_DIR" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
toolkit_home = sys.argv[2]
text = path.read_text()
updated = text.replace("__METHODOLOGY_HOME__", toolkit_home)
if updated != text:
    path.write_text(updated)
PY
  fi
  echo "create $dst"
}

if [[ "$surface" == "auto" ]]; then
  mode_for_surface="${mode_override:-$(read_maturity_mode "$target_dir")}"
  surface="$(bootstrap_surface_for "$mode_for_surface")"
fi

if [[ "$surface" == "core" ]]; then
  files_to_copy=("${METHODOLOGY_CORE_FILES[@]}")
else
  files_to_copy=("${METHODOLOGY_ROOT_FILES[@]}")
fi

for file_name in "${files_to_copy[@]}"; do
  copy_if_missing "$SCRIPT_DIR/$file_name" "$(project_file_path "$target_dir" "$file_name")"
done
for file_name in "${METHODOLOGY_SPEC_TEMPLATE_FILES[@]}"; do
  copy_if_missing "$SCRIPT_DIR/$file_name" "$(project_file_path "$target_dir" "$file_name")"
done

if [[ -f "$SCRIPT_DIR/fix-project-perms.sh" ]]; then
  bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null || true
fi
