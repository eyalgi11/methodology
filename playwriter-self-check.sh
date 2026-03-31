#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/launch-playwriter-brave.sh"
LOCAL_BRIDGE="$SCRIPT_DIR/serve-local-page.sh"
CLI_UPDATER="$SCRIPT_DIR/ensure-playwriter-cli.sh"
PLAYWRITER_EXTENSION_ID="${PLAYWRITER_EXTENSION_ID:-jfeammnjpkecdekppnclgkkffahnhfhe}"
PLAYWRITER_SELF_CHECK_TIMEOUT_MS="${PLAYWRITER_SELF_CHECK_TIMEOUT_MS:-20000}"

smoke_test=1
target_arg=""

usage() {
  cat <<EOF
Usage: playwriter-self-check.sh [--quick] [target-file-or-url]

Validate the Playwriter self-launch path end to end:
  - Brave availability
  - playwriter CLI availability
  - installed Playwriter extension detection
  - localhost bridge for local files
  - Playwriter Brave launch
  - browser connection
  - optional smoke navigation

Defaults:
  - smoke test: enabled
  - target: current repo audit page when available, otherwise the methodology
            source audit page, otherwise about:blank

Options:
  --quick    Run dependency and bridge checks only; skip launch and smoke test
  -h, --help Show this help
EOF
}

while (($# > 0)); do
  case "$1" in
    --quick)
      smoke_test=0
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

target_user="$(resolve_target_user)"
target_home="$(resolve_user_home "$target_user")"
lock_file="${PLAYWRITER_SELF_CHECK_LOCK_FILE:-$target_home/.local/share/methodology-local-https/playwriter-self-check.lock}"
BRAVE_USER_DATA_DIR="${PLAYWRITER_BRAVE_USER_DATA_DIR:-$target_home/.config/BraveSoftware/Brave-Browser}"
PLAYWRITER_BRAVE_PROFILE_NAME="${PLAYWRITER_BRAVE_PROFILE_NAME:-}"

detect_extension_dir() {
  local profile_name="$1"
  local extensions_root="$BRAVE_USER_DATA_DIR/$profile_name/Extensions/$PLAYWRITER_EXTENSION_ID"
  [[ -d "$extensions_root" ]] || return 0
  find "$extensions_root" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1
}

detect_extension_profile() {
  local profile_dir
  for profile_dir in "$BRAVE_USER_DATA_DIR/Default" "$BRAVE_USER_DATA_DIR"/Profile\ *; do
    [[ -d "$profile_dir" ]] || continue
    if [[ -n "$(detect_extension_dir "$(basename "$profile_dir")" || true)" ]]; then
      printf '%s' "$(basename "$profile_dir")"
      return 0
    fi
  done
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
  if [[ -f "/home/eyal/system-docs/methodology/methodology-audit.html" ]]; then
    printf '%s' "/home/eyal/system-docs/methodology/methodology-audit.html"
    return 0
  fi
  printf '%s' "about:blank"
}

json_quote() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

extract_version() {
  python3 - "$1" <<'PY'
import re, sys
text = sys.argv[1]
match = re.search(r'playwriter/([0-9.]+)', text)
print(match.group(1) if match else "")
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

wait_for_browser_connection() {
  local out=""
  for _ in 1 2 3 4 5; do
    if out="$(playwriter browser list 2>&1)"; then
      printf '%s' "$out"
      return 0
    fi
    sleep 1
  done
  printf '%s' "$out"
  return 1
}

curl_check() {
  local url="$1"
  if [[ "$url" == https://* ]]; then
    curl -fsSk --max-time 5 "$url" >/dev/null
  else
    curl -fsS --max-time 5 "$url" >/dev/null
  fi
}

target="${target_arg:-$(default_target)}"
is_local_target=0
if [[ "$target" == file://* || ( "$target" != http://* && "$target" != https://* && "$target" != about:* && -e "$target" ) ]]; then
  is_local_target=1
fi

mkdir -p "$(dirname "$lock_file")"
exec 9>"$lock_file"
if command -v flock >/dev/null 2>&1; then
  flock 9
fi

status=0
pass_count=0
warn_count=0
fail_count=0

pass() {
  printf 'PASS  %s\n' "$1"
  pass_count=$((pass_count + 1))
}

warn() {
  printf 'WARN  %s\n' "$1"
  warn_count=$((warn_count + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  fail_count=$((fail_count + 1))
  status=1
}

session_id=""
cleanup() {
  if [[ -n "$session_id" ]]; then
    playwriter session delete "$session_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

printf 'Playwriter self-check\n'
printf 'Target: %s\n' "$target"

if "$CLI_UPDATER" --quiet; then
  pass "Playwriter CLI install/update check completed"
else
  fail "Playwriter CLI install/update check failed"
fi

if command -v brave >/dev/null 2>&1 || command -v brave-browser >/dev/null 2>&1; then
  pass "Brave is available on PATH"
else
  fail "Brave is not available on PATH"
fi

playwriter_version=""
if command -v playwriter >/dev/null 2>&1; then
  playwriter_version_raw="$(playwriter --version 2>/dev/null || true)"
  playwriter_version="$(extract_version "$playwriter_version_raw")"
  if [[ -n "$playwriter_version" ]]; then
    pass "Playwriter CLI is available (version $playwriter_version)"
  else
    pass "Playwriter CLI is available"
  fi
else
  fail "Playwriter CLI is not available on PATH"
fi

extension_profile="${PLAYWRITER_BRAVE_PROFILE_NAME:-$(detect_extension_profile || true)}"
extension_dir=""
if [[ -n "$extension_profile" ]]; then
  extension_dir="$(detect_extension_dir "$extension_profile" || true)"
fi
extension_version=""
if [[ -n "$extension_dir" ]]; then
  extension_version="$(basename "$extension_dir")"
  pass "Playwriter extension detected in Brave profile $extension_profile ($extension_version)"
  if [[ -n "$playwriter_version" ]]; then
    extension_core="${extension_version%%_*}"
    if [[ "$extension_core" != "$playwriter_version" ]]; then
      warn "CLI version ($playwriter_version) and installed extension version ($extension_version) differ; acceptable if smoke navigation passes"
    fi
  fi
else
  fail "Playwriter extension was not found in any visible Brave profile"
fi

http_url=""
https_url=""
navigate_url="$target"

if (( is_local_target == 1 )); then
  if https_url="$("$LOCAL_BRIDGE" --scheme https "$target" 2>/dev/null)"; then
    if curl_check "$https_url"; then
      pass "Local HTTPS bridge is reachable ($https_url)"
    else
      fail "Local HTTPS bridge started but did not respond cleanly ($https_url)"
    fi
  else
    fail "Could not create the local HTTPS bridge for $target"
  fi

  if http_url="$("$LOCAL_BRIDGE" --scheme http "$target" 2>/dev/null)"; then
    if curl_check "$http_url"; then
      pass "Local HTTP fallback is reachable ($http_url)"
    else
      fail "Local HTTP fallback started but did not respond cleanly ($http_url)"
    fi
  else
    fail "Could not create the local HTTP fallback for $target"
  fi

  navigate_url="$http_url"
fi

if (( smoke_test == 0 )); then
  printf 'Summary: %d pass, %d warn, %d fail\n' "$pass_count" "$warn_count" "$fail_count"
  exit "$status"
fi

launch_output=""
if launch_output="$("$LAUNCHER" "$target" 2>&1)"; then
  pass "Playwriter Brave profile launched"
else
  fail "Could not launch the dedicated Playwriter Brave profile"
  printf '%s\n' "$launch_output" >&2
  printf 'Summary: %d pass, %d warn, %d fail\n' "$pass_count" "$warn_count" "$fail_count"
  exit "$status"
fi

browser_list_output="$(wait_for_browser_connection || true)"
if grep -q 'browser:' <<<"$browser_list_output"; then
  pass "Playwriter browser connection is available"
else
  fail "Playwriter did not see a connected browser after launch"
  if [[ -n "$browser_list_output" ]]; then
    printf '%s\n' "$browser_list_output" >&2
  fi
  printf 'Summary: %d pass, %d warn, %d fail\n' "$pass_count" "$warn_count" "$fail_count"
  exit "$status"
fi

session_create_output="$(playwriter session new 2>&1 || true)"
session_id="$(extract_session_id "$session_create_output")"
if [[ -z "$session_id" ]]; then
  fail "Could not create a Playwriter session for smoke navigation"
  if [[ -n "$session_create_output" ]]; then
    printf '%s\n' "$session_create_output" >&2
  fi
  printf 'Summary: %d pass, %d warn, %d fail\n' "$pass_count" "$warn_count" "$fail_count"
  exit "$status"
fi

session_reset_output=""
if session_reset_output="$(playwriter session reset "$session_id" 2>&1)"; then
  pass "Playwriter session reset succeeded before smoke navigation"
else
  warn "Playwriter session reset did not succeed cleanly before smoke navigation"
  if [[ -n "$session_reset_output" ]]; then
    printf '%s\n' "$session_reset_output" >&2
  fi
fi

target_js="$(json_quote "$navigate_url")"
smoke_output=""
if smoke_output="$(playwriter -s "$session_id" --timeout "$PLAYWRITER_SELF_CHECK_TIMEOUT_MS" -e "$(cat <<EOF
const targetUrl = $target_js;
let page = context.pages().find((candidate) => candidate.url() === targetUrl) ?? context.pages()[0] ?? null;
if (!page) {
  page = await context.newPage();
}
if (page.url() !== targetUrl && targetUrl !== "about:blank") {
  await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 15000 });
}
await page.waitForLoadState("domcontentloaded", { timeout: 5000 }).catch(() => {});
let title = "";
for (let attempt = 1; attempt <= 2; attempt += 1) {
  try {
    title = await page.title();
    break;
  } catch (error) {
    if (attempt === 2) {
      throw error;
    }
    await page.waitForTimeout(500);
  }
}
console.log(JSON.stringify({ url: page.url(), title }));
EOF
)" 2>&1)"; then
  smoke_summary="$(printf '%s\n' "$smoke_output" | tail -n 1)"
  pass "Smoke navigation succeeded ($smoke_summary)"
else
  fail "Smoke navigation failed for $navigate_url"
  printf '%s\n' "$smoke_output" >&2
fi

printf 'Summary: %d pass, %d warn, %d fail\n' "$pass_count" "$warn_count" "$fail_count"
exit "$status"
