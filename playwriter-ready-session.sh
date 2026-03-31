#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_UPDATER="$SCRIPT_DIR/ensure-playwriter-cli.sh"
LAUNCHER="$SCRIPT_DIR/launch-playwriter-brave.sh"
LOCAL_BRIDGE="$SCRIPT_DIR/serve-local-page.sh"

PLAYWRITER_READY_SESSION_TIMEOUT_S="${PLAYWRITER_READY_SESSION_TIMEOUT_S:-12}"
PLAYWRITER_READY_SESSION_ATTEMPTS="${PLAYWRITER_READY_SESSION_ATTEMPTS:-4}"
PLAYWRITER_READY_SESSION_PROFILE_DIR="${PLAYWRITER_READY_SESSION_PROFILE_DIR:-}"
PLAYWRITER_LOCAL_FILE_SCHEME="${PLAYWRITER_LOCAL_FILE_SCHEME:-http}"
PLAYWRITER_BUNDLED_EXTENSION_DIR_DEFAULT="/usr/lib/node_modules/playwriter/dist/extension"

json_mode=0
target_arg=""

usage() {
  cat <<EOF
Usage: playwriter-ready-session.sh [--json] [target-file-or-url]

Launch a dedicated Brave automation profile for Playwriter and return a session
that is already proven usable.

Defaults:
  - local file targets are bridged to localhost using ${PLAYWRITER_LOCAL_FILE_SCHEME}
  - a dedicated automation profile is used instead of the normal visible profile
  - the bundled Playwriter extension is auto-loaded when available

Options:
  --json     Print machine-readable JSON instead of human text
  -h, --help Show this help
EOF
}

while (($# > 0)); do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target may be provided." >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

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

default_target() {
  if [[ -f "$PWD/methodology/methodology-audit.html" ]]; then
    printf '%s' "$PWD/methodology/methodology-audit.html"
    return 0
  fi
  if [[ -f "$PWD/methodology-audit.html" ]]; then
    printf '%s' "$PWD/methodology-audit.html"
    return 0
  fi
  if [[ -f "$SCRIPT_DIR/methodology-audit.html" ]]; then
    printf '%s' "$SCRIPT_DIR/methodology-audit.html"
    return 0
  fi
  printf '%s' "about:blank"
}

json_escape() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

extract_session_id() {
  python3 - "$1" <<'PY'
import re, sys
text = sys.argv[1]
match = re.search(r'Session\s+([0-9]+)\s+created', text)
if not match:
    match = re.search(r'^\s*([0-9]+)\s*$', text, re.M)
print(match.group(1) if match else "")
PY
}

target_user="$(resolve_target_user)"
target_home="$(resolve_user_home "$target_user")"
automation_profile_dir="${PLAYWRITER_READY_SESSION_PROFILE_DIR:-$target_home/.config/BraveSoftware/Brave-Browser-Playwriter-Automation}"
target="${target_arg:-$(default_target)}"
navigate_url="$target"

if [[ "$target" == file://* || ( "$target" != http://* && "$target" != https://* && "$target" != about:* && -e "$target" ) ]]; then
  navigate_url="$("$LOCAL_BRIDGE" --scheme "$PLAYWRITER_LOCAL_FILE_SCHEME" "$target")"
fi

"$CLI_UPDATER" --quiet >/dev/null 2>&1 || true

bundled_extension_dir="${PLAYWRITER_EXTENSION_DIR:-}"
if [[ -z "$bundled_extension_dir" && -d "$PLAYWRITER_BUNDLED_EXTENSION_DIR_DEFAULT" ]]; then
  bundled_extension_dir="$PLAYWRITER_BUNDLED_EXTENSION_DIR_DEFAULT"
fi

launch_output="$(
  PLAYWRITER_BRAVE_PROFILE_DIR="$automation_profile_dir" \
  PLAYWRITER_EXTENSION_DIR="$bundled_extension_dir" \
  PLAYWRITER_BRAVE_PROFILE_NAME="" \
  "$LAUNCHER" "$navigate_url" 2>&1
)"

session_id=""
session_output=""
for ((attempt = 1; attempt <= PLAYWRITER_READY_SESSION_ATTEMPTS; attempt += 1)); do
  session_output="$(timeout "${PLAYWRITER_READY_SESSION_TIMEOUT_S}s" playwriter session new 2>&1 || true)"
  session_id="$(extract_session_id "$session_output")"
  if [[ -n "$session_id" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$session_id" ]]; then
  if (( json_mode == 1 )); then
    printf '{"ok":false,"target_url":%s,"profile_dir":%s,"launch_output":%s,"session_output":%s}\n' \
      "$(json_escape "$navigate_url")" \
      "$(json_escape "$automation_profile_dir")" \
      "$(json_escape "$launch_output")" \
      "$(json_escape "$session_output")"
  else
    printf '%s\n' "$launch_output" >&2
    printf '%s\n' "$session_output" >&2
  fi
  exit 1
fi

target_js="$(json_escape "$navigate_url")"
smoke_output="$(playwriter -s "$session_id" --timeout 12000 -e "$(cat <<EOF
const targetUrl = $target_js;
let page = context.pages()[0] ?? null;
if (!page) {
  page = await context.newPage();
}
if (targetUrl !== "about:blank" && page.url() !== targetUrl) {
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 15000 });
      break;
    } catch (error) {
      if (!String(error).includes("ERR_ABORTED") || attempt === 2) {
        throw error;
      }
      if (page.url() === targetUrl) {
        break;
      }
      await page.waitForTimeout(500);
    }
  }
}
await page.waitForLoadState("domcontentloaded", { timeout: 5000 }).catch(() => {});
let title = "";
try {
  title = await page.title();
} catch (error) {
  title = "";
}
console.log(JSON.stringify({ url: page.url(), title }));
EOF
)" 2>&1 || true)"

if grep -q 'Error executing code:' <<<"$smoke_output"; then
  playwriter session delete "$session_id" >/dev/null 2>&1 || true
  if (( json_mode == 1 )); then
    printf '{"ok":false,"target_url":%s,"profile_dir":%s,"launch_output":%s,"session_output":%s,"smoke_output":%s}\n' \
      "$(json_escape "$navigate_url")" \
      "$(json_escape "$automation_profile_dir")" \
      "$(json_escape "$launch_output")" \
      "$(json_escape "$session_output")" \
      "$(json_escape "$smoke_output")"
  else
    printf '%s\n' "$launch_output" >&2
    printf '%s\n' "$session_output" >&2
    printf '%s\n' "$smoke_output" >&2
  fi
  exit 1
fi

if (( json_mode == 1 )); then
  printf '{"ok":true,"session_id":"%s","target_url":%s,"profile_dir":%s,"launch_output":%s,"session_output":%s,"smoke_output":%s}\n' \
    "$session_id" \
    "$(json_escape "$navigate_url")" \
    "$(json_escape "$automation_profile_dir")" \
    "$(json_escape "$launch_output")" \
    "$(json_escape "$session_output")" \
    "$(json_escape "$smoke_output")"
else
  printf 'Ready Playwriter session: %s\n' "$session_id"
  printf 'Target URL: %s\n' "$navigate_url"
  printf 'Automation profile: %s\n' "$automation_profile_dir"
  printf 'Smoke: %s\n' "$(printf '%s\n' "$smoke_output" | tail -n 1)"
  printf 'Use with: playwriter -s %s -e %q\n' "$session_id" '...'
fi
