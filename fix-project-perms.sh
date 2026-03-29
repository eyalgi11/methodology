#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: fix-project-perms.sh [--user USER] [target-directory]

Normalizes ownership and basic edit permissions for project files so they remain
editable from a non-sudo shell after work performed in a sudo/root shell.
EOF
}

target_arg=""
target_user="${SUDO_USER:-}"

while (($# > 0)); do
  case "$1" in
    --user)
      target_user="$2"
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
target_dir="$(cd "$target_dir" && pwd)"

if [[ -z "$target_user" ]]; then
  repo_owner="$(stat -c '%U' "$target_dir" 2>/dev/null || true)"
  if [[ -n "$repo_owner" && "$repo_owner" != "root" && "$repo_owner" != "UNKNOWN" ]]; then
    target_user="$repo_owner"
  else
    target_user="$(id -un)"
  fi
fi

if ! id "$target_user" >/dev/null 2>&1; then
  echo "Unknown target user: $target_user" >&2
  exit 1
fi

target_group="$(id -gn "$target_user")"

if [[ "$EUID" -ne 0 ]]; then
  echo "skip  permission normalization (not running as root)"
  exit 0
fi

mapfile -d '' root_owned_paths < <(find "$target_dir" -xdev \( -uid 0 -o -gid 0 \) -print0)

if (( ${#root_owned_paths[@]} == 0 )); then
  echo "skip  permission normalization (no root-owned paths in $target_dir)"
  exit 0
fi

if find "$target_dir" -xdev \( -uid 0 -o -gid 0 \) -exec chown "$target_user:$target_group" {} + 2>/dev/null; then
  find "$target_dir" -xdev -user "$target_user" -exec chmod u+rwX {} +
  echo "Normalized ownership and edit permissions for $target_dir to $target_user:$target_group"
else
  echo "warn  ownership normalization was blocked by the current filesystem or sandbox for $target_dir"
  echo "warn  if root-owned files remain, run chown manually on the real machine"
fi
