#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: methodology-audit.sh [--json] [--summary] [target-directory]

Checks whether a project contains the required methodology files and whether
those files still contain untouched template content.
EOF
}

json_mode=0
summary_mode=0
target_arg=""

while (($# > 0)); do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    --summary)
      summary_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one target directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
mode="$(read_maturity_mode "$target_dir")"

missing_files=()
placeholder_files=()
present_files=()

for file_name in "${METHODOLOGY_ROOT_FILES[@]}"; do
  if [[ -f "$(project_file_path "$target_dir" "$file_name")" ]]; then
    present_files+=("$file_name")
    if [[ "$mode" != "template_source" ]] &&
       ! is_manifest_list_member "$file_name" "${METHODOLOGY_PLACEHOLDER_EXEMPT_FILES[@]}" &&
       is_placeholder_file "$target_dir" "$file_name"; then
      placeholder_files+=("$file_name")
    fi
  else
    missing_files+=("$file_name")
  fi
done

for file_name in "${METHODOLOGY_SPEC_TEMPLATE_FILES[@]}"; do
  feature_template_path="$(project_file_path "$target_dir" "$file_name")"
  if [[ -f "$feature_template_path" ]]; then
    present_files+=("$file_name")
    if [[ "$mode" != "template_source" ]] && is_placeholder_file "$target_dir" "$file_name"; then
      placeholder_files+=("$file_name")
    fi
  else
    missing_files+=("$file_name")
  fi
done

ok=1
if (( ${#missing_files[@]} > 0 || ${#placeholder_files[@]} > 0 )); then
  ok=0
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ok == 1 )) && printf true || printf false )"
  printf '"missing":'
  print_json_array missing_files
  printf ','
  printf '"placeholder":'
  print_json_array placeholder_files
  printf ','
  printf '"present":'
  print_json_array present_files
  printf '}\n'
else
  if (( ok == 1 )); then
    echo "Audit passed: methodology files are present and no untouched templates were detected."
  else
    if (( summary_mode == 1 )); then
      echo "Audit warnings for $target_dir"
      if (( ${#missing_files[@]} > 0 )); then
        echo "  Missing files: ${#missing_files[@]}"
      fi
      if (( ${#placeholder_files[@]} > 0 )); then
        echo "  Untouched template docs: ${#placeholder_files[@]}"
        printf '  First few: %s\n' "$(printf '%s, ' "${placeholder_files[@]:0:5}" | sed 's/, $//')"
      fi
    else
      echo "Audit issues found in $target_dir"
      if (( ${#missing_files[@]} > 0 )); then
        echo
        echo "Missing files:"
        printf '  - %s\n' "${missing_files[@]}"
      fi
      if (( ${#placeholder_files[@]} > 0 )); then
        echo
        echo "Untouched template content:"
        printf '  - %s\n' "${placeholder_files[@]}"
      fi
    fi
  fi
fi

if (( ok == 1 )); then
  exit 0
fi

exit 1
