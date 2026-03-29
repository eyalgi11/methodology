#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: knowledge-extract.sh [target-directory]

Performs a deeper repo scan than repo-intake.sh and writes extracted knowledge
into REPO_MAP.md, ARCHITECTURE.md, COMMANDS.md, and DEPENDENCIES.md.
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
"$SCRIPT_DIR/repo-intake.sh" "$target_dir" >/dev/null
repo_map_file="$(project_file_path "$target_dir" "REPO_MAP.md")"
architecture_file="$(project_file_path "$target_dir" "ARCHITECTURE.md")"
commands_file="$(project_file_path "$target_dir" "COMMANDS.md")"
dependencies_file="$(project_file_path "$target_dir" "DEPENDENCIES.md")"

mapfile -t top_dirs < <(find "$target_dir" -maxdepth 1 -mindepth 1 -type d ! -name .git ! -name node_modules ! -name dist ! -name build ! -name coverage -printf '%f\n' | sort | head -n 12)
mapfile -t env_files < <(find "$target_dir" -maxdepth 2 -type f \( -name '.env*' -o -name '*.env' \) -printf '%P\n' | sort | head -n 10)
mapfile -t test_files < <(find "$target_dir" \( -type d \( -name .git -o -name node_modules -o -name dist -o -name build \) -prune \) -o -type f \( -name '*test*' -o -name '*spec*' \) -printf '%P\n' | sort | head -n 12)

script_inventory="none detected"
if [[ -f "$target_dir/package.json" ]] && command -v node >/dev/null 2>&1; then
  script_inventory="$(cd "$target_dir" && node -e 'const p=require("./package.json"); const keys=Object.keys(p.scripts||{}); process.stdout.write(keys.join(", "));' 2>/dev/null || true)"
  script_inventory="${script_inventory:-none detected}"
fi

repo_body=$(cat <<EOF
- Extracted at: $(timestamp_now)
- Top-level directories:
$(if ((${#top_dirs[@]} > 0)); then printf '%s\n' "${top_dirs[@]}" | sed 's/^/  - /'; else printf '  - none detected\n'; fi)
- Environment/config files:
$(if ((${#env_files[@]} > 0)); then printf '%s\n' "${env_files[@]}" | sed 's/^/  - /'; else printf '  - none detected\n'; fi)
- Test files:
$(if ((${#test_files[@]} > 0)); then printf '%s\n' "${test_files[@]}" | sed 's/^/  - /'; else printf '  - none detected\n'; fi)
EOF
)
append_or_replace_auto_section "$repo_map_file" "knowledge-extract" "## Knowledge Extraction" "$repo_body"

architecture_body=$(cat <<EOF
- Extracted at: $(timestamp_now)
- Package scripts: ${script_inventory}
- Test files detected: ${#test_files[@]}
- Environment/config files detected: ${#env_files[@]}
EOF
)
append_or_replace_auto_section "$architecture_file" "knowledge-extract" "## Knowledge Extraction" "$architecture_body"

commands_body=$(cat <<EOF
- Extracted at: $(timestamp_now)
- Package scripts detected: ${script_inventory}
- Follow-up: validate that COMMANDS.md reflects the scripts that matter for daily work.
EOF
)
append_or_replace_auto_section "$commands_file" "knowledge-extract" "## Knowledge Extraction" "$commands_body"

dependencies_body=$(cat <<EOF
- Extracted at: $(timestamp_now)
- Environment/config files detected: ${#env_files[@]}
- Test files detected: ${#test_files[@]}
- Follow-up: document critical libraries and services, not just every package.
EOF
)
append_or_replace_auto_section "$dependencies_file" "knowledge-extract" "## Knowledge Extraction" "$dependencies_body"

echo "Knowledge extraction updated methodology docs for $target_dir"
