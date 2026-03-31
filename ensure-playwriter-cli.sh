#!/usr/bin/env bash
set -euo pipefail

force_update=0
quiet=0

resolve_target_user() {
  local user="${PLAYWRITER_BROWSER_USER:-${SUDO_USER:-}}"
  if [[ -n "$user" ]]; then
    printf '%s' "$user"
    return 0
  fi
  local owner
  owner="$(stat -c '%U' "$PWD" 2>/dev/null || true)"
  if [[ -n "$owner" && "$owner" != "root" && "$owner" != "UNKNOWN" ]]; then
    printf '%s' "$owner"
    return 0
  fi
  id -un
}

resolve_user_home() {
  local user="$1"
  local home_dir
  home_dir="$(getent passwd "$user" | cut -d: -f6)"
  if [[ -n "$home_dir" ]]; then
    printf '%s' "$home_dir"
  else
    printf '%s' "$HOME"
  fi
}

target_user="$(resolve_target_user)"
target_home="$(resolve_user_home "$target_user")"
AUTO_UPDATE_TTL_SECONDS="${PLAYWRITER_AUTO_UPDATE_TTL_SECONDS:-86400}"
PLAYWRITER_UPDATE_STATE_DIR="${PLAYWRITER_UPDATE_STATE_DIR:-$target_home/.local/share/methodology-playwriter}"
STATE_FILE="$PLAYWRITER_UPDATE_STATE_DIR/cli-update-state.json"

usage() {
  cat <<EOF
Usage: ensure-playwriter-cli.sh [--force] [--quiet]

Ensure the Playwriter CLI is installed and periodically updated to the latest
published npm version.

Defaults:
  - checks at most once per ${AUTO_UPDATE_TTL_SECONDS}s
  - installs or updates with: npm install -g playwriter@latest

Options:
  --force    Ignore the TTL and check for/update immediately
  --quiet    Suppress normal status output
  -h, --help Show this help
EOF
}

while (($# > 0)); do
  case "$1" in
    --force)
      force_update=1
      shift
      ;;
    --quiet)
      quiet=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

say() {
  if (( quiet == 0 )); then
    printf '%s\n' "$1"
  fi
}

read_state() {
  local field="$1"
  [[ -f "$STATE_FILE" ]] || return 0
  python3 - "$STATE_FILE" "$field" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
field = sys.argv[2]
try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(0)
value = data.get(field, "")
print(value if value is not None else "")
PY
}

write_state() {
  local checked_at="$1"
  local current_version="$2"
  local latest_version="$3"
  mkdir -p "$PLAYWRITER_UPDATE_STATE_DIR"
  python3 - "$STATE_FILE" "$checked_at" "$current_version" "$latest_version" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = {
    "checked_at": int(sys.argv[2]),
    "current_version": sys.argv[3],
    "latest_version": sys.argv[4],
}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  chown "$target_user:$(id -gn "$target_user")" "$STATE_FILE" 2>/dev/null || true
}

extract_cli_version() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import re, sys
text = sys.argv[1]
match = re.search(r'playwriter/([0-9.]+)', text)
print(match.group(1) if match else "")
PY
}

current_version() {
  if ! command -v playwriter >/dev/null 2>&1; then
    return 0
  fi
  extract_cli_version "$(playwriter --version 2>/dev/null || true)"
}

latest_version() {
  npm view playwriter version 2>/dev/null || true
}

install_latest() {
  say "Updating Playwriter CLI to latest..."
  npm install -g playwriter@latest >/dev/null
}

mkdir -p "$PLAYWRITER_UPDATE_STATE_DIR"

now="$(date +%s)"
last_checked="$(read_state checked_at)"
if [[ -z "$last_checked" ]]; then
  last_checked=0
fi

current="$(current_version)"
if [[ -n "$current" && $force_update -eq 0 ]]; then
  age=$((now - last_checked))
  if (( age >= 0 && age < AUTO_UPDATE_TTL_SECONDS )); then
    say "Playwriter CLI recently checked; keeping current version $current."
    exit 0
  fi
fi

latest="$(latest_version)"

if [[ -z "$current" ]]; then
  if [[ -z "$latest" ]]; then
    echo "Playwriter CLI is not installed and npm could not determine the latest version." >&2
    exit 1
  fi
  install_latest
  current="$(current_version)"
  write_state "$now" "$current" "$latest"
  say "Playwriter CLI installed at version $current."
  exit 0
fi

if [[ -z "$latest" ]]; then
  say "Could not reach npm to check the latest Playwriter version; keeping current version $current."
  exit 0
fi

if [[ "$current" != "$latest" ]]; then
  install_latest
  current="$(current_version)"
  now="$(date +%s)"
  write_state "$now" "$current" "$latest"
  say "Playwriter CLI updated to version $current."
  exit 0
fi

write_state "$now" "$current" "$latest"
say "Playwriter CLI is already current at version $current."
