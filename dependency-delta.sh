#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: dependency-delta.sh [--json] [target-directory]

Compares currently declared dependencies with DEPENDENCIES.md and reports any
dependency names not yet documented there.
EOF
}

target_arg=""
json_mode=0
write_mode=1
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --no-write) write_mode=0; shift ;;
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
deps_file="$(project_file_path "$target_dir" "DEPENDENCIES.md")"

detected_deps=()

if [[ -f "$target_dir/package.json" ]] && command -v node >/dev/null 2>&1; then
  while IFS= read -r item; do
    [[ -n "$item" ]] && detected_deps+=("$item")
  done < <(cd "$target_dir" && node -e 'const p=require("./package.json"); console.log(Object.keys({...p.dependencies,...p.devDependencies}).join("\n"));' 2>/dev/null || true)
fi

if [[ -f "$target_dir/requirements.txt" ]]; then
  while IFS= read -r item; do
    item="$(printf '%s' "$item" | sed -E 's/[<>=!].*$//' | xargs)"
    [[ -n "$item" && "$item" != \#* ]] && detected_deps+=("$item")
  done < "$target_dir/requirements.txt"
fi

if [[ -f "$target_dir/Cargo.toml" ]]; then
  while IFS= read -r item; do
    [[ -n "$item" ]] && detected_deps+=("$item")
  done < <(awk -F= '/^[A-Za-z0-9_-]+[[:space:]]*=/{gsub(/[[:space:]]+/,"",$1); print $1}' "$target_dir/Cargo.toml" 2>/dev/null || true)
fi

if [[ -f "$target_dir/go.mod" ]]; then
  while IFS= read -r item; do
    [[ -n "$item" ]] && detected_deps+=("$item")
  done < <(awk '/^require /{print $2}' "$target_dir/go.mod" 2>/dev/null || true)
fi

if [[ ${#detected_deps[@]} -gt 0 ]]; then
  mapfile -t detected_deps < <(printf '%s\n' "${detected_deps[@]}" | awk 'NF && !seen[tolower($0)]++')
fi

undocumented=()
deps_text="$(tr '[:upper:]' '[:lower:]' < "$deps_file" 2>/dev/null || true)"
for dep in "${detected_deps[@]}"; do
  dep_lower="$(printf '%s' "$dep" | tr '[:upper:]' '[:lower:]')"
  if [[ "$deps_text" != *"$dep_lower"* ]]; then
    undocumented+=("$dep")
  fi
done

inventory_body=$(cat <<EOF
- Generated at: $(timestamp_now)
- Detected dependency count: ${#detected_deps[@]}
$(if [[ ${#detected_deps[@]} -gt 0 ]]; then printf '%s\n' "${detected_deps[@]}" | sed 's/^/- /'; else printf '%s\n' '- none detected'; fi)
EOF
)
if (( write_mode == 1 )); then
  append_or_replace_auto_section "$deps_file" "dependency-delta" "## Auto Dependency Inventory" "$inventory_body"
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#undocumented[@]} == 0 )) && printf true || printf false )"
  printf '"detected":'
  print_json_array detected_deps
  printf ','
  printf '"undocumented":'
  print_json_array undocumented
  printf '}\n'
else
  if (( ${#undocumented[@]} == 0 )); then
    echo "No undocumented dependencies detected."
  else
    echo "Undocumented dependencies found in $target_dir"
    printf '  - %s\n' "${undocumented[@]}"
  fi
fi

if (( ${#undocumented[@]} == 0 )); then
  exit 0
fi
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
exit 1
