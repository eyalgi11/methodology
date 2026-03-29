#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: auto-update-from-git.sh [target-directory]

Refreshes state docs from the current git branch, status, changed files, and
recent commits.
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
if ! has_git_repo "$target_dir"; then
  echo "Target is not a git repository: $target_dir" >&2
  exit 1
fi

branch="$(current_git_branch "$target_dir")"
session_state_file="$(project_file_path "$target_dir" "SESSION_STATE.md")"
handoff_file="$(project_file_path "$target_dir" "HANDOFF.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"
release_notes_file="$(project_file_path "$target_dir" "RELEASE_NOTES.md")"
status_output="$(git -C "$target_dir" status --short 2>/dev/null || true)"
recent_commits="$(git -C "$target_dir" log --oneline -n 5 2>/dev/null || true)"
mapfile -t recent_files < <(recent_work_files "$target_dir" 10)

session_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Branch: ${branch}
- Git status:
$(if [[ -n "$status_output" ]]; then printf '%s\n' "$status_output" | sed 's/^/  - /'; else printf '  - clean\n'; fi)
- Recent work files:
$(if ((${#recent_files[@]} > 0)); then printf '%s\n' "${recent_files[@]}" | sed 's/^/  - /'; else printf '  - none detected\n'; fi)
EOF
)
append_or_replace_auto_section "$session_state_file" "git-update" "## Git Update" "$session_body"

handoff_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Branch: ${branch}
- Recent commits:
$(if [[ -n "$recent_commits" ]]; then printf '%s\n' "$recent_commits" | sed 's/^/  - /'; else printf '  - none available\n'; fi)
- Uncommitted files:
$(if [[ -n "$status_output" ]]; then printf '%s\n' "$status_output" | sed 's/^/  - /'; else printf '  - none\n'; fi)
EOF
)
append_or_replace_auto_section "$handoff_file" "git-update" "## Git Update" "$handoff_body"

health_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Branch: ${branch}
- Working tree state: $(if [[ -n "$status_output" ]]; then printf 'dirty'; else printf 'clean'; fi)
- Recent commits captured: $(if [[ -n "$recent_commits" ]]; then printf 'yes'; else printf 'no'; fi)
EOF
)
append_or_replace_auto_section "$project_health_file" "git-update" "## Git Update" "$health_body"

release_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Branch: ${branch}
- Recent commits:
$(if [[ -n "$recent_commits" ]]; then printf '%s\n' "$recent_commits" | sed 's/^/  - /'; else printf '  - none available\n'; fi)
EOF
)
append_or_replace_auto_section "$release_notes_file" "git-update" "## Git Change Summary" "$release_body"

echo "Updated methodology docs from git state for $target_dir"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
