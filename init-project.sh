#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: init-project.sh [--git] <target-directory>

Creates a project directory if needed and bootstraps the methodology.

Options:
  --git        Backward-compatible no-op. Git initialization is now mandatory.
  --surface    core, full, or auto (default: auto)
  --mode       prototype, product, production, or template_source
  -h, --help   Show this help text

Examples:
  init-project.sh ~/projects/new-app
  init-project.sh --git ~/projects/new-app
EOF
}

init_git=0
target_dir=""
surface="auto"
mode_override=""

while (($# > 0)); do
  case "$1" in
    --git)
      init_git=1
      shift
      ;;
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
      if [[ -n "$target_dir" ]]; then
        echo "Only one target directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_dir="$1"
      shift
      ;;
  esac
done

if [[ -z "$target_dir" ]]; then
  usage >&2
  exit 1
fi

mkdir -p "$target_dir"
target_dir="$(resolve_target_dir "$target_dir")"

ensure_git_repo "$target_dir"

bootstrap_args=(--surface "$surface")
if [[ -n "$mode_override" ]]; then
  bootstrap_args+=(--mode "$mode_override")
fi
"$SCRIPT_DIR/bootstrap-methodology.sh" "${bootstrap_args[@]}" "$target_dir"
bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null || true

echo
echo "Project initialized at: $target_dir"
echo "Next steps:"
echo "  1. Fill in PROJECT_BRIEF.md and COMMANDS.md"
echo "  2. Update ROADMAP.md and TASKS.md with the current milestone"
echo "  3. Run work-preflight.sh before substantial implementation"
