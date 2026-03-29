#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: migrate-methodology-layout.sh [target-directory]

Moves methodology docs from the project root into methodology/ while keeping
the repo-level AGENTS.md and root specs/ directory in place.
EOF
}

target_arg=""
while (($# > 0)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
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

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
methodology_dir="$target_dir/$PROJECT_METHODOLOGY_DIR_NAME"
mkdir -p "$methodology_dir"

matches_template() {
  local file_path="$1"
  local relative_path="$2"
  local baseline_path
  baseline_path="$(template_path "$relative_path")"
  [[ -f "$file_path" && -f "$baseline_path" ]] && cmp -s "$file_path" "$baseline_path"
}

prefer_legacy_live_state() {
  local relative_path="$1"
  local legacy_path="$2"
  local new_path="$3"

  case "$relative_path" in
    CORE_CONTEXT.md|SESSION_STATE.md|HANDOFF.md|docs-archive-index.json|methodology-state.json)
      ;;
    *)
      return 1
      ;;
  esac

  local legacy_size new_size
  legacy_size="$(wc -c < "$legacy_path" 2>/dev/null || echo 0)"
  new_size="$(wc -c < "$new_path" 2>/dev/null || echo 0)"
  [[ "$legacy_size" =~ ^[0-9]+$ && "$new_size" =~ ^[0-9]+$ ]] || return 1
  (( legacy_size > new_size ))
}

for file_name in "${METHODOLOGY_ROOT_FILES[@]}"; do
  if [[ "$file_name" == "AGENTS.md" ]]; then
    continue
  fi

  legacy_path="$target_dir/$file_name"
  new_path="$(project_file_path "$target_dir" "$file_name")"

  if [[ "$legacy_path" == "$new_path" ]]; then
    continue
  fi
  if [[ ! -e "$legacy_path" ]]; then
    continue
  fi

  mkdir -p "$(dirname "$new_path")"
  if [[ -e "$new_path" ]]; then
    if cmp -s "$legacy_path" "$new_path"; then
      rm -f "$legacy_path"
      echo "cleanup $legacy_path"
    elif matches_template "$new_path" "$file_name"; then
      mv -f "$legacy_path" "$new_path"
      echo "adopt $legacy_path -> $new_path"
    elif prefer_legacy_live_state "$file_name" "$legacy_path" "$new_path"; then
      mv -f "$legacy_path" "$new_path"
      echo "adopt $legacy_path -> $new_path"
    elif matches_template "$legacy_path" "$file_name"; then
      rm -f "$legacy_path"
      echo "cleanup $legacy_path"
    else
      echo "warn  both legacy and methodology copies exist for $file_name; leaving legacy file in place" >&2
    fi
    continue
  fi

  mv "$legacy_path" "$new_path"
  echo "move  $legacy_path -> $new_path"
done

if [[ -f "$SCRIPT_DIR/fix-project-perms.sh" ]]; then
  bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null 2>&1 || true
fi
