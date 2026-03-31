#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shell_name=""
update_shell_rc=1
target_user=""

resolve_target_user() {
  if [[ -n "$target_user" ]]; then
    printf '%s' "$target_user"
    return 0
  fi
  if [[ -n "${METHODOLOGY_INSTALL_USER:-}" ]]; then
    printf '%s' "$METHODOLOGY_INSTALL_USER"
    return 0
  fi
  if [[ -n "${SUDO_USER:-}" ]]; then
    printf '%s' "$SUDO_USER"
    return 0
  fi
  local repo_owner
  repo_owner="$(stat -c '%U' "$SCRIPT_DIR" 2>/dev/null || true)"
  if [[ -n "$repo_owner" && "$repo_owner" != "root" && "$repo_owner" != "UNKNOWN" ]]; then
    printf '%s' "$repo_owner"
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

usage() {
  cat <<EOF
Usage: install-toolkit.sh [--shell bash|zsh|all] [--user USER] [--no-shell-rc]

Register this cloned methodology repo as the local toolkit install.

What it does:
  - writes METHODOLOGY_HOME to ${CONFIG_FILE}
  - installs a small \`mtool\` wrapper into ${LOCAL_BIN_DIR}
  - optionally appends shared shell snippets to ~/.bashrc and ~/.zshrc
  - enables portable shell helpers like \`mstart\`, \`mresume\`, \`mupdate\`, and \`madopt\`

This is intended for Linux and WSL environments.
EOF
}

while (($# > 0)); do
  case "$1" in
    --shell)
      shift
      [[ $# -gt 0 ]] || { echo "--shell requires bash, zsh, or all" >&2; exit 1; }
      shell_name="$1"
      shift
      ;;
    --user)
      shift
      [[ $# -gt 0 ]] || { echo "--user requires a username" >&2; exit 1; }
      target_user="$1"
      shift
      ;;
    --no-shell-rc)
      update_shell_rc=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

target_user="$(resolve_target_user)"
target_home="$(resolve_user_home "$target_user")"
CONFIG_DIR="$target_home/.config/methodology"
CONFIG_FILE="$CONFIG_DIR/config.env"
LOCAL_BIN_DIR="$target_home/.local/bin"

mkdir -p "$CONFIG_DIR" "$LOCAL_BIN_DIR"
cat > "$CONFIG_FILE" <<EOF
export METHODOLOGY_HOME="$SCRIPT_DIR"
EOF

cat > "$LOCAL_BIN_DIR/mtool" <<EOF
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="${CONFIG_FILE}"
if [[ -f "\$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "\$CONFIG_FILE"
fi
: "\${METHODOLOGY_HOME:?METHODOLOGY_HOME is not set. Run install-toolkit.sh first.}"
[[ \$# -gt 0 ]] || { echo "Usage: mtool <script-name> [args...]" >&2; exit 1; }
script_name="\$1"
shift
exec "\$METHODOLOGY_HOME/\$script_name" "\$@"
EOF
chmod +x "$LOCAL_BIN_DIR/mtool"

if (( update_shell_rc )); then
  if [[ -z "$shell_name" ]]; then
    shell_name="all"
  fi
  case "$shell_name" in
    bash) rc_files=("$target_home/.bashrc") ;;
    zsh) rc_files=("$target_home/.zshrc") ;;
    all) rc_files=("$target_home/.bashrc" "$target_home/.zshrc") ;;
    *)
      echo "Unsupported shell: $shell_name" >&2
      exit 1
      ;;
  esac
  config_snippet='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/methodology/config.env" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/methodology/config.env"'
  shell_snippet='[ -n "${METHODOLOGY_HOME:-}" ] && [ -f "$METHODOLOGY_HOME/shell-methodology.sh" ] && source "$METHODOLOGY_HOME/shell-methodology.sh"'
  for rc_file in "${rc_files[@]}"; do
    if [[ ! -f "$rc_file" ]] || ! grep -Fqx "$config_snippet" "$rc_file" 2>/dev/null; then
      printf '\n%s\n' "$config_snippet" >> "$rc_file"
    fi
    if [[ ! -f "$rc_file" ]] || ! grep -Fqx "$shell_snippet" "$rc_file" 2>/dev/null; then
      printf '%s\n' "$shell_snippet" >> "$rc_file"
    fi
  done
fi

if [[ "$EUID" -eq 0 ]]; then
  chown -R "$target_user:$(id -gn "$target_user")" "$CONFIG_DIR" "$LOCAL_BIN_DIR" 2>/dev/null || true
fi

echo "Installed methodology toolkit config at $CONFIG_FILE"
echo "Installed wrapper at $LOCAL_BIN_DIR/mtool"
echo "Toolkit home: $SCRIPT_DIR"
