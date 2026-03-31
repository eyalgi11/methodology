#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYWRITER_EXTENSION_ID="${PLAYWRITER_EXTENSION_ID:-jfeammnjpkecdekppnclgkkffahnhfhe}"
PLAYWRITER_EXTENSION_DIR="${PLAYWRITER_EXTENSION_DIR:-}"
PLAYWRITER_LOCAL_FILE_SCHEME="${PLAYWRITER_LOCAL_FILE_SCHEME:-http}"
PLAYWRITER_AUTO_UPDATE="${PLAYWRITER_AUTO_UPDATE:-1}"
PLAYWRITER_REMOTE_DEBUG_PORT="${PLAYWRITER_REMOTE_DEBUG_PORT:-}"

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

build_desktop_env_args() {
  local key
  for key in \
    HOME \
    XDG_RUNTIME_DIR \
    DISPLAY \
    WAYLAND_DISPLAY \
    XAUTHORITY \
    DBUS_SESSION_BUS_ADDRESS \
    XDG_SESSION_TYPE \
    XDG_CURRENT_DESKTOP \
    DESKTOP_SESSION
  do
    if [[ -n "${!key:-}" ]]; then
      printf '%s\0%s=%s\0' "$key" "$key" "${!key}"
    fi
  done
}

profile_has_extension() {
  local profile_name="$1"
  local extensions_root="$BRAVE_USER_DATA_DIR/$profile_name/Extensions/$PLAYWRITER_EXTENSION_ID"
  [[ -d "$extensions_root" ]]
}

target_user="$(resolve_target_user)"
target_home="$(resolve_user_home "$target_user")"
BRAVE_USER_DATA_DIR="${PLAYWRITER_BRAVE_USER_DATA_DIR:-$target_home/.config/BraveSoftware/Brave-Browser}"
PLAYWRITER_BRAVE_PROFILE_NAME="${PLAYWRITER_BRAVE_PROFILE_NAME:-}"
PLAYWRITER_BRAVE_PROFILE_DIR="${PLAYWRITER_BRAVE_PROFILE_DIR:-}"

detect_profile_name() {
  local profile_dir
  for profile_dir in "$BRAVE_USER_DATA_DIR/Default" "$BRAVE_USER_DATA_DIR"/Profile\ *; do
    [[ -d "$profile_dir" ]] || continue
    if profile_has_extension "$(basename "$profile_dir")"; then
      printf '%s' "$(basename "$profile_dir")"
      return 0
    fi
  done
  if [[ -d "$BRAVE_USER_DATA_DIR/Default" ]]; then
    printf '%s' "Default"
  fi
}

detect_extension_dir() {
  local profile_name="${1:-Default}"
  local extensions_root="$BRAVE_USER_DATA_DIR/$profile_name/Extensions/$PLAYWRITER_EXTENSION_ID"
  [[ -d "$extensions_root" ]] || return 0
  find "$extensions_root" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1
}

read_env_args() {
  local env_pairs=()
  while IFS= read -r -d '' _key && IFS= read -r -d '' _pair; do
    env_pairs+=("$_pair")
  done < <(build_desktop_env_args)
  printf '%s\0' "${env_pairs[@]}"
}

if [[ -z "$PLAYWRITER_BRAVE_PROFILE_DIR" ]]; then
  if [[ -z "$PLAYWRITER_BRAVE_PROFILE_NAME" ]]; then
    PLAYWRITER_BRAVE_PROFILE_NAME="$(detect_profile_name || true)"
  fi
  if [[ -z "$PLAYWRITER_BRAVE_PROFILE_NAME" ]]; then
    PLAYWRITER_BRAVE_PROFILE_NAME="Default"
  fi
fi

if [[ -z "$PLAYWRITER_EXTENSION_DIR" ]]; then
  if [[ -n "$PLAYWRITER_BRAVE_PROFILE_DIR" ]]; then
    PLAYWRITER_EXTENSION_DIR="$(detect_extension_dir "Default" || true)"
  else
    PLAYWRITER_EXTENSION_DIR="$(detect_extension_dir "$PLAYWRITER_BRAVE_PROFILE_NAME" || true)"
  fi
fi

usage() {
  cat <<EOF
Usage: launch-playwriter-brave.sh [--print] [url]

Launch Brave with a Playwriter-friendly Brave profile.

Defaults:
  user data dir: ${PLAYWRITER_BRAVE_PROFILE_DIR:-$BRAVE_USER_DATA_DIR}
  profile:       ${PLAYWRITER_BRAVE_PROFILE_NAME:-"(isolated user-data-dir mode)"}
  url:         about:blank

Environment overrides:
  PLAYWRITER_BRAVE_USER_DATA_DIR Main Brave user-data-dir to reuse
  PLAYWRITER_BRAVE_PROFILE_NAME  Visible Brave profile directory name to use
                                 (for example: Default, "Profile 1")
  PLAYWRITER_BRAVE_PROFILE_DIR   Optional isolated Brave user-data-dir fallback
  PLAYWRITER_EXTENSION_ID        Extension ID to allowlist for tab capture
  PLAYWRITER_EXTENSION_DIR       Optional unpacked extension path to load
  PLAYWRITER_LOCAL_FILE_SCHEME   Local file bridge scheme for file targets
                                 (`http` or `https`, default: http)
  PLAYWRITER_REMOTE_DEBUG_PORT   Optional Chrome DevTools port for direct-mode
                                 automation fallback (for example: 9222)

Notes:
  - By default this reuses a real Brave profile so Playwriter can use the
    extension the same way the normal browser does.
  - This automates normal launch, not first-time extension installation.
  - Set PLAYWRITER_BRAVE_PROFILE_DIR only when you intentionally want an
    isolated fallback user-data-dir instead of a normal visible Brave profile.
EOF
}

print_only=0
url="about:blank"

while (($# > 0)); do
  case "$1" in
    --print|--dry-run)
      print_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ "$PLAYWRITER_AUTO_UPDATE" == "1" ]]; then
  "$SCRIPT_DIR/ensure-playwriter-cli.sh" --quiet || true
fi

if [[ "$url" == file://* || ( "$url" != http://* && "$url" != https://* && -e "$url" ) ]]; then
  url="$("$SCRIPT_DIR/serve-local-page.sh" --scheme "$PLAYWRITER_LOCAL_FILE_SCHEME" "$url")"
fi

browser_bin=""
for candidate in brave-browser brave; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser_bin="$(command -v "$candidate")"
    break
  fi
done

if [[ -z "$browser_bin" ]]; then
  echo "Brave browser is not installed or not on PATH." >&2
  exit 1
fi

desktop_env_args=()
while IFS= read -r -d '' item; do
  [[ -n "$item" ]] && desktop_env_args+=("$item")
done < <(read_env_args)

for i in "${!desktop_env_args[@]}"; do
  case "${desktop_env_args[$i]}" in
    HOME=*) desktop_env_args[$i]="HOME=$target_home" ;;
    XDG_RUNTIME_DIR=*) desktop_env_args[$i]="XDG_RUNTIME_DIR=/run/user/$(id -u "$target_user")" ;;
  esac
done
if [[ " ${desktop_env_args[*]} " != *" HOME="* ]]; then
  desktop_env_args+=("HOME=$target_home")
fi
if [[ " ${desktop_env_args[*]} " != *" XDG_RUNTIME_DIR="* ]]; then
  desktop_env_args+=("XDG_RUNTIME_DIR=/run/user/$(id -u "$target_user")")
fi

args=(
  "$browser_bin"
  "--new-window"
  "--no-first-run"
  "--no-default-browser-check"
  "--allow-insecure-localhost"
  "--ignore-certificate-errors"
  "--allowlisted-extension-id=$PLAYWRITER_EXTENSION_ID"
  "--auto-accept-this-tab-capture"
)

if [[ -n "$PLAYWRITER_REMOTE_DEBUG_PORT" ]]; then
  args+=("--remote-debugging-port=$PLAYWRITER_REMOTE_DEBUG_PORT")
fi

launch_description=""
extension_message=""

if [[ -n "$PLAYWRITER_BRAVE_PROFILE_DIR" ]]; then
  mkdir -p "$PLAYWRITER_BRAVE_PROFILE_DIR"
  chown -R "$target_user:$(id -gn "$target_user")" "$PLAYWRITER_BRAVE_PROFILE_DIR" 2>/dev/null || true
  args+=("--user-data-dir=$PLAYWRITER_BRAVE_PROFILE_DIR")
  launch_description="$PLAYWRITER_BRAVE_PROFILE_DIR"
  if [[ -n "$PLAYWRITER_EXTENSION_DIR" ]]; then
    args+=(
      "--disable-extensions-except=$PLAYWRITER_EXTENSION_DIR"
      "--load-extension=$PLAYWRITER_EXTENSION_DIR"
    )
    extension_message="Auto-loading Playwriter extension from:
  $PLAYWRITER_EXTENSION_DIR"
  fi
else
  args+=(
    "--user-data-dir=$BRAVE_USER_DATA_DIR"
    "--profile-directory=$PLAYWRITER_BRAVE_PROFILE_NAME"
  )
  launch_description="$BRAVE_USER_DATA_DIR ($PLAYWRITER_BRAVE_PROFILE_NAME)"
  if profile_has_extension "$PLAYWRITER_BRAVE_PROFILE_NAME"; then
    extension_message="Using installed Playwriter extension from visible Brave profile:
  $PLAYWRITER_BRAVE_PROFILE_NAME"
  elif [[ -n "$PLAYWRITER_EXTENSION_DIR" ]]; then
    args+=(
      "--disable-extensions-except=$PLAYWRITER_EXTENSION_DIR"
      "--load-extension=$PLAYWRITER_EXTENSION_DIR"
    )
    extension_message="Visible Brave profile does not contain the extension; auto-loading:
  $PLAYWRITER_EXTENSION_DIR"
  fi
fi

args+=("$url")

if (( print_only == 1 )); then
  if [[ "$(id -un)" != "$target_user" ]]; then
    printf '%q ' sudo -u "$target_user" env "${desktop_env_args[@]}"
  fi
  printf '%q ' "${args[@]}"
  printf '\n'
  exit 0
fi

if [[ "$(id -un)" == "$target_user" ]]; then
  nohup "${args[@]}" </dev/null >/dev/null 2>&1 &
else
  printf -v launch_cmd '%q ' env "${desktop_env_args[@]}" "${args[@]}"
  launch_cmd="${launch_cmd}</dev/null >/dev/null 2>&1 &"
  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$target_user" bash -lc "nohup ${launch_cmd}" </dev/null >/dev/null 2>&1 &
  elif command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- bash -lc "nohup ${launch_cmd}" </dev/null >/dev/null 2>&1 &
  else
    echo "Need sudo or runuser to launch Brave as $target_user." >&2
    exit 1
  fi
fi
disown || true

if [[ -n "$PLAYWRITER_BRAVE_PROFILE_DIR" && -z "$PLAYWRITER_EXTENSION_DIR" ]]; then
  cat <<EOF
Launched Brave with the Playwriter profile:
  $launch_description

One-time setup still needed in that profile:
  1. Install/enable the Playwriter extension.
  2. After that, future launches can reuse this profile automatically.
EOF
elif [[ -n "$extension_message" ]]; then
  cat <<EOF
Launched Brave with the Playwriter profile:
  $launch_description

$extension_message
EOF
else
  cat <<EOF
Launched Brave with the Playwriter profile:
  $launch_description

If Playwriter still says no browser is connected, reset the session or click the
extension once on the target tab to grant tab access for that page.
EOF
fi
