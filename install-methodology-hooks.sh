#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: install-methodology-hooks.sh [--uninstall] [target-directory]

Installs warning-only git hooks that run methodology status, audit, and drift
checks before commit and push. Hooks never block the git operation.
EOF
}

target_arg=""
uninstall=0
while (($# > 0)); do
  case "$1" in
    --uninstall) uninstall=1; shift ;;
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

target_dir="${target_arg:-$PWD}"
if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Target is not a git repository: $target_dir" >&2
  exit 1
fi

repo_root="$(git -C "$target_dir" rev-parse --show-toplevel)"
hooks_dir="$repo_root/.git/hooks"
mkdir -p "$hooks_dir"

if (( uninstall == 1 )); then
  rm -f "$hooks_dir/pre-commit" "$hooks_dir/pre-push"
  echo "Removed methodology git hooks from $repo_root"
  exit 0
fi

for hook_name in pre-commit pre-push; do
  cat > "$hooks_dir/$hook_name" <<EOF
#!/usr/bin/env bash
set +e

repo_root="\$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "\$repo_root" ]]; then
  exit 0
fi

echo "[methodology] running warning-only checks for \$repo_root"
"$SCRIPT_DIR/methodology-status.sh" "\$repo_root" >/dev/null 2>&1 || echo "[methodology] continuity files are stale or missing"
"$SCRIPT_DIR/methodology-audit.sh" "\$repo_root" >/dev/null 2>&1 || echo "[methodology] methodology files are missing or still placeholders"
"$SCRIPT_DIR/drift-check.sh" "\$repo_root" >/dev/null 2>&1 || echo "[methodology] documentation drift detected"
exit 0
EOF
  chmod +x "$hooks_dir/$hook_name"
done

echo "Installed warning-only methodology git hooks in $repo_root/.git/hooks"

