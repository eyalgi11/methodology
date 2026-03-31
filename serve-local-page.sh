#!/usr/bin/env bash
set -euo pipefail

DEFAULT_HTTPS_START_PORT="${METHODOLOGY_LOCAL_HTTPS_START_PORT:-8876}"
DEFAULT_HTTP_START_PORT="${METHODOLOGY_LOCAL_HTTP_START_PORT:-8877}"
HOST_BIND="${METHODOLOGY_LOCAL_HTTPS_BIND:-127.0.0.1}"
URL_HOST="${METHODOLOGY_LOCAL_HTTPS_HOSTNAME:-localhost}"

resolve_target_user() {
  local user="${METHODOLOGY_LOCAL_HTTPS_USER:-${SUDO_USER:-}}"
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
DEFAULT_ROOT="${METHODOLOGY_LOCAL_HTTPS_DEFAULT_ROOT:-$target_home}"
RUNTIME_DIR="${METHODOLOGY_LOCAL_HTTPS_DIR:-$target_home/.local/share/methodology-local-https}"
CERT_FILE="$RUNTIME_DIR/localhost.crt"
KEY_FILE="$RUNTIME_DIR/localhost.key"

usage() {
  cat <<EOF
Usage: serve-local-page.sh [--root DIR] [--port PORT] [--scheme http|https] [--print-root] <file-path-or-file-url>

Convert a local HTML/file path into an HTTPS localhost URL and start or reuse a
local HTTPS file server for browser automation.

Defaults:
  root directory: $DEFAULT_ROOT
  hostname:       $URL_HOST
  bind address:   $HOST_BIND
  https port:     starting at $DEFAULT_HTTPS_START_PORT
  http port:      starting at $DEFAULT_HTTP_START_PORT

Examples:
  serve-local-page.sh /home/eyal/system-docs/methodology/methodology-audit.html
  serve-local-page.sh file:///home/eyal/projects/foo/methodology/methodology-audit.html
EOF
}

root_arg=""
port_arg=""
scheme_arg="https"
print_root=0
target_arg=""

while (($# > 0)); do
  case "$1" in
    --root)
      shift
      [[ $# -gt 0 ]] || { echo "--root requires a path" >&2; exit 1; }
      root_arg="$1"
      shift
      ;;
    --port)
      shift
      [[ $# -gt 0 ]] || { echo "--port requires a number" >&2; exit 1; }
      port_arg="$1"
      shift
      ;;
    --scheme)
      shift
      [[ $# -gt 0 ]] || { echo "--scheme requires http or https" >&2; exit 1; }
      scheme_arg="$1"
      shift
      ;;
    --print-root)
      print_root=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target path may be provided." >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

[[ -n "$target_arg" ]] || { usage >&2; exit 1; }
[[ "$scheme_arg" == "http" || "$scheme_arg" == "https" ]] || { echo "--scheme must be http or https" >&2; exit 1; }

if [[ "$scheme_arg" == "http" ]]; then
  default_start_port="$DEFAULT_HTTP_START_PORT"
else
  default_start_port="$DEFAULT_HTTPS_START_PORT"
fi

STATE_FILE="$RUNTIME_DIR/server-$scheme_arg.json"
LOG_FILE="$RUNTIME_DIR/server-$scheme_arg.log"

normalize_target_path() {
  local raw="$1"
  if [[ "$raw" == file://* ]]; then
    python3 - "$raw" <<'PY'
import sys
from urllib.parse import urlparse, unquote
parsed = urlparse(sys.argv[1])
print(unquote(parsed.path))
PY
  else
    python3 - "$raw" <<'PY'
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
  fi
}

target_path="$(normalize_target_path "$target_arg")"
[[ -e "$target_path" ]] || { echo "Local path does not exist: $target_path" >&2; exit 1; }
target_path="$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")"

root_dir="${root_arg:-$DEFAULT_ROOT}"
root_dir="$(cd "$root_dir" && pwd)"
if [[ "$target_path" != "$root_dir"* ]]; then
  root_dir="/"
fi

if (( print_root == 1 )); then
  printf '%s\n' "$root_dir"
  exit 0
fi

mkdir -p "$RUNTIME_DIR"
chown "$target_user:$(id -gn "$target_user")" "$RUNTIME_DIR" 2>/dev/null || true

ensure_cert() {
  if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    return 0
  fi
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
  chown "$target_user:$(id -gn "$target_user")" "$CERT_FILE" "$KEY_FILE" 2>/dev/null || true
}

port_is_listening() {
  local port="$1"
  python3 - "$HOST_BIND" "$port" <<'PY'
import socket, sys
host = sys.argv[1]
port = int(sys.argv[2])
sock = socket.socket()
sock.settimeout(0.3)
try:
    sock.connect((host, port))
except OSError:
    raise SystemExit(1)
finally:
    sock.close()
PY
}

pick_free_port() {
  python3 - "$HOST_BIND" "${1:-$default_start_port}" <<'PY'
import socket, sys
host = sys.argv[1]
start = int(sys.argv[2])
for port in range(start, start + 50):
    sock = socket.socket()
    try:
        sock.bind((host, port))
    except OSError:
        sock.close()
        continue
    sock.close()
    print(port)
    raise SystemExit(0)
raise SystemExit(1)
PY
}

read_state_field() {
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
if value is None:
    value = ""
print(value)
PY
}

write_state() {
  local pid="$1"
  local port="$2"
  local root="$3"
  python3 - "$STATE_FILE" "$pid" "$port" "$root" "$LOG_FILE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = {
    "pid": int(sys.argv[2]),
    "port": int(sys.argv[3]),
    "root": sys.argv[4],
    "log": sys.argv[5],
}
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  chown "$target_user:$(id -gn "$target_user")" "$STATE_FILE" 2>/dev/null || true
}

start_server() {
  local port="$1"
  : >"$LOG_FILE"
  chown "$target_user:$(id -gn "$target_user")" "$LOG_FILE" 2>/dev/null || true
  local pid=""
  local server_cmd=(
    python3 -m http.server "$port"
    --bind "$HOST_BIND"
    --directory "$root_dir"
  )
  if [[ "$scheme_arg" == "https" ]]; then
    ensure_cert
    server_cmd+=(
      --tls-cert "$CERT_FILE"
      --tls-key "$KEY_FILE"
    )
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid -f "${server_cmd[@]}" >"$LOG_FILE" 2>&1
    sleep 0.1
    pid="$(pgrep -f "python3 -m http.server $port --bind $HOST_BIND --directory $root_dir" | head -n 1 || true)"
  else
    nohup "${server_cmd[@]}" >"$LOG_FILE" 2>&1 &
    pid=$!
  fi
  for _ in $(seq 1 40); do
    if port_is_listening "$port"; then
      pid="${pid:-0}"
      write_state "$pid" "$port" "$root_dir"
      return 0
    fi
    sleep 0.1
  done
  echo "Failed to start local HTTPS server. See $LOG_FILE" >&2
  exit 1
}

server_pid="$(read_state_field pid)"
server_port="$(read_state_field port)"
server_root="$(read_state_field root)"

if [[ -n "$port_arg" ]]; then
  server_port="$port_arg"
fi

reuse_server=0
if [[ -n "$server_pid" && -n "$server_port" && -n "$server_root" && "$server_root" == "$root_dir" ]] \
  && kill -0 "$server_pid" 2>/dev/null && port_is_listening "$server_port"; then
  reuse_server=1
fi

if (( reuse_server == 0 )); then
  if [[ -z "$server_port" ]]; then
    server_port="$(pick_free_port "$default_start_port")"
  elif ! port_is_listening "$server_port"; then
    server_port="$(pick_free_port "$default_start_port")"
  fi
  start_server "$server_port"
fi

relative_path="$(python3 - "$root_dir" "$target_path" <<'PY'
import os, sys
root = os.path.abspath(sys.argv[1])
target = os.path.abspath(sys.argv[2])
rel = os.path.relpath(target, root)
if rel.startswith(".."):
    rel = target.lstrip("/")
print(rel)
PY
)"

url_path="$(python3 - "$relative_path" <<'PY'
import sys
from urllib.parse import quote
path = sys.argv[1].replace("\\", "/")
print("/" + quote(path, safe="/-._~"))
PY
)"

printf '%s://%s:%s%s\n' "$scheme_arg" "$URL_HOST" "$server_port" "$url_path"
