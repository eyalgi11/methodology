#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: test-gap-report.sh [--json] [target-directory]

Reports likely testing gaps based on recent code changes, available test files,
and test commands in COMMANDS.md.
EOF
}

target_arg=""
json_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
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
commands_file="$(project_file_path "$target_dir" "COMMANDS.md")"
verification_log_file="$(project_file_path "$target_dir" "VERIFICATION_LOG.md")"
mapfile -t recent_files < <(recent_work_files "$target_dir" 15)
mapfile -t test_files < <(find "$target_dir" \( -type d \( -name .git -o -name node_modules -o -name dist -o -name build \) -prune \) -o -type f \( -name '*test*' -o -name '*spec*' \) -printf '%P\n' | sort | head -n 30)
test_command_count=0
while IFS=$'\t' read -r section _ value; do
  value="$(strip_wrapping_backticks "$(trim_whitespace "$value")")"
  if [[ "$section" == "Test" ]] && ! is_placeholder_value "$value" && [[ -n "$value" ]]; then
    test_command_count=$((test_command_count + 1))
  fi
done < <(extract_commands_from_markdown "$commands_file")

issues=()
if (( test_command_count == 0 )); then
  issues+=("COMMANDS.md does not define runnable test commands.")
fi
if (( ${#test_files[@]} == 0 )); then
  issues+=("No test files were detected in the repository.")
fi
if (( ${#recent_files[@]} > 0 && ${#test_files[@]} == 0 )); then
  issues+=("Recent work files exist without any detected tests.")
fi

report_body=$(cat <<EOF
- Generated at: $(timestamp_now)
- Recent work files reviewed: ${#recent_files[@]}
- Test files detected: ${#test_files[@]}
- Runnable test commands: ${test_command_count}
- Issues found: ${#issues[@]}
EOF
)
append_or_replace_auto_section "$verification_log_file" "test-gap-report" "## Auto Test Gap Report" "$report_body"

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "No obvious test gaps detected."
  else
    echo "Test gap issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
exit 1
