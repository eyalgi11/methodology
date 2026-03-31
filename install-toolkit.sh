#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/methodology"
CONFIG_FILE="$CONFIG_DIR/config.env"
LOCAL_BIN_DIR="${HOME}/.local/bin"
shell_name=""
update_shell_rc=1

usage() {
  cat <<EOF
Usage: install-toolkit.sh [--shell bash|zsh] [--no-shell-rc]

Register this cloned methodology repo as the local toolkit install.

What it does:
  - writes METHODOLOGY_HOME to ${CONFIG_FILE}
  - installs a small \`mtool\` wrapper into ${LOCAL_BIN_DIR}
  - optionally appends a shell snippet to ~/.bashrc or ~/.zshrc

This is intended for Linux and WSL environments.
EOF
}

while (($# > 0)); do
  case "$1" in
    --shell)
      shift
      [[ $# -gt 0 ]] || { echo "--shell requires bash or zsh" >&2; exit 1; }
      shell_name="$1"
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
    case "$(basename "${SHELL:-}")" in
      zsh) shell_name="zsh" ;;
      *) shell_name="bash" ;;
    esac
  fi
  case "$shell_name" in
    bash) rc_file="$HOME/.bashrc" ;;
    zsh) rc_file="$HOME/.zshrc" ;;
    *)
      echo "Unsupported shell: $shell_name" >&2
      exit 1
      ;;
  esac
  snippet='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/methodology/config.env" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/methodology/config.env"'
  if [[ ! -f "$rc_file" ]] || ! grep -Fqx "$snippet" "$rc_file" 2>/dev/null; then
    printf '\n%s\n' "$snippet" >> "$rc_file"
  fi
fi

echo "Installed methodology toolkit config at $CONFIG_FILE"
echo "Installed wrapper at $LOCAL_BIN_DIR/mtool"
echo "Toolkit home: $SCRIPT_DIR"
