#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: verify-project.sh [options] [target-directory]

Runs verification commands from COMMANDS.md and appends the results to
VERIFICATION_LOG.md by default.

Options:
  --sections LIST   Comma-separated sections to run (default: Test,Quality,Build / Release)
  --scope TEXT      Scope label for VERIFICATION_LOG.md
  --environment-label TEXT  warm-env verified, cold-start verified, partially verified
  --artifact-path TEXT      Path to saved logs/artifacts (default: n/a)
  --human-follow-up yes|no  Whether a human still needs to check something (default: no)
  --json            Print JSON summary
  --no-log          Do not append to VERIFICATION_LOG.md
EOF
}

json_mode=0
write_log=1
target_arg=""
scope_label="project verification"
sections_csv="Test,Quality,Build / Release"
environment_label="warm-env verified"
artifact_path="n/a"
human_follow_up="no"

while (($# > 0)); do
  case "$1" in
    --sections) sections_csv="$2"; shift 2 ;;
    --scope) scope_label="$2"; shift 2 ;;
    --environment-label) environment_label="$2"; shift 2 ;;
    --artifact-path) artifact_path="$2"; shift 2 ;;
    --human-follow-up) human_follow_up="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
    --no-log) write_log=0; shift ;;
    -h|--help) usage; exit 0 ;;
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

if [[ "$human_follow_up" != "yes" && "$human_follow_up" != "no" ]]; then
  echo "--human-follow-up must be yes or no." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
commands_file="$(project_file_path "$target_dir" "COMMANDS.md")"
exceptions_file="$(project_file_path "$target_dir" "PROCESS_EXCEPTIONS.md")"
if [[ ! -f "$commands_file" ]]; then
  echo "COMMANDS.md not found in $target_dir" >&2
  exit 1
fi

IFS=',' read -r -a selected_sections <<< "$sections_csv"
for idx in "${!selected_sections[@]}"; do
  selected_sections[$idx]="$(trim_whitespace "${selected_sections[$idx]}")"
done

section_selected() {
  local candidate="$1"
  local wanted
  for wanted in "${selected_sections[@]}"; do
    if [[ "$candidate" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

command_value_for_label() {
  local wanted_section="$1"
  local wanted_label="$2"
  local aliases=()
  mapfile -t aliases < <(command_label_aliases "$wanted_label")
  local section
  local label
  local value
  while IFS=$'\t' read -r section label value; do
    if [[ "$section" != "$wanted_section" ]]; then
      continue
    fi
    local alias
    local matched=0
    for alias in "${aliases[@]}"; do
      if [[ "$label" == "$alias" ]]; then
        matched=1
        break
      fi
    done
    if (( matched == 0 )); then
      continue
    fi
    value="$(strip_wrapping_backticks "$(trim_whitespace "$value")")"
    if is_placeholder_value "$value" || [[ "$value" == "n/a" || -z "$value" ]]; then
      continue
    fi
    printf '%s\n' "$value"
    return 0
  done < <(extract_commands_from_markdown "$commands_file")
  return 1
}

selected_command_present() {
  local wanted_label="$1"
  local aliases=()
  mapfile -t aliases < <(command_label_aliases "$wanted_label")
  local label
  for label in "${command_labels[@]}"; do
    local alias
    for alias in "${aliases[@]}"; do
      if [[ "$label" == "Test :: ${alias}" ]]; then
        return 0
      fi
    done
  done
  return 1
}

has_process_exception_match() {
  local pattern="$1"
  [[ -f "$exceptions_file" ]] || return 1
  grep -Eiq "$pattern" "$exceptions_file"
}

mobile_command_is_native_appium() {
  local value="$1"
  local lowered
  lowered="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  [[ "$lowered" == *appium* ]]
}

list_changed_paths() {
  local path
  if has_git_repo "$target_dir"; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && printf '%s\n' "$path"
    done < <(
      git -C "$target_dir" status --short --untracked-files=all 2>/dev/null | while IFS= read -r line; do
        path="${line:3}"
        if [[ "$path" == *" -> "* ]]; then
          path="${path##* -> }"
        fi
        printf '%s\n' "$path"
      done | awk '!seen[$0]++'
    )
    return 0
  fi

  recent_work_files "$target_dir" 20
}

path_requires_browser_automation() {
  local path="$1"
  case "$path" in
    apps/web/*|web/*|frontend/*|pages/*|public/*|*.html|*.css|*.scss|*.sass|*.less)
      return 0
      ;;
    */apps/web/*|*/web/*|*/frontend/*|*/pages/*|*/public/*)
      return 0
      ;;
  esac
  return 1
}

path_requires_mobile_automation() {
  local path="$1"
  case "$path" in
    apps/mobile/*|mobile/*|android/*|ios/*|app.json|app.config.js|app.config.ts|app.config.mjs|app.config.cjs)
      return 0
      ;;
    */apps/mobile/*|*/mobile/*|*/android/*|*/ios/*)
      return 0
      ;;
  esac
  return 1
}

path_requires_desktop_browser_like_automation() {
  local path="$1"
  case "$path" in
    apps/desktop/*|desktop/*|electron/*|src-electron/*|src-tauri/*|tauri/*|tauri.conf.json|tauri.conf.json5|tauri.conf.toml)
      return 0
      ;;
    */apps/desktop/*|*/desktop/*|*/electron/*|*/src-electron/*|*/src-tauri/*|*/tauri/*)
      return 0
      ;;
  esac
  return 1
}

path_requires_native_desktop_automation() {
  local path="$1"
  case "$path" in
    windows/*|macos/*)
      return 0
      ;;
    */windows/*|*/macos/*)
      return 0
      ;;
  esac
  return 1
}

commands_to_run=()
command_labels=()

while IFS=$'\t' read -r section label value; do
  [[ -z "$section" ]] && continue
  if ! section_selected "$section"; then
    continue
  fi
  value="$(strip_wrapping_backticks "$(trim_whitespace "$value")")"
  if is_placeholder_value "$value" || [[ "$value" == "n/a" ]]; then
    continue
  fi
  commands_to_run+=("$value")
  command_labels+=("$section :: $label")
done < <(extract_commands_from_markdown "$commands_file")

requires_browser_automation=0
requires_mobile_automation=0
requires_desktop_browser_like_automation=0
requires_native_desktop_automation=0
while IFS= read -r changed_path; do
  if path_requires_browser_automation "$changed_path"; then
    requires_browser_automation=1
  fi
  if path_requires_mobile_automation "$changed_path"; then
    requires_mobile_automation=1
  fi
  if path_requires_desktop_browser_like_automation "$changed_path"; then
    requires_desktop_browser_like_automation=1
  fi
  if path_requires_native_desktop_automation "$changed_path"; then
    requires_native_desktop_automation=1
  fi
done < <(list_changed_paths)

automation_failures=()
browser_command_label="Browser automation"
mobile_command_label="Mobile automation"
desktop_command_label="Desktop automation"
browser_command_value="$(command_value_for_label "Test" "$browser_command_label" || true)"
mobile_command_value="$(command_value_for_label "Test" "$mobile_command_label" || true)"
desktop_command_value="$(command_value_for_label "Test" "$desktop_command_label" || true)"

if (( requires_browser_automation == 1 )); then
  if has_process_exception_match 'playwriter|browser automation'; then
    human_follow_up="yes"
  elif [[ -z "$browser_command_value" ]]; then
    automation_failures+=("Web-facing changes detected, but COMMANDS.md does not define a runnable '${browser_command_label}' command and no PROCESS_EXCEPTIONS.md entry was found.")
  elif ! selected_command_present "$browser_command_label"; then
    automation_failures+=("Web-facing changes detected, but '${browser_command_label}' was not included in the current verify-project.sh run.")
  fi
fi

if (( requires_mobile_automation == 1 )); then
  if has_process_exception_match 'appium|mobile automation|native appium'; then
    human_follow_up="yes"
  elif [[ -z "$mobile_command_value" ]]; then
    automation_failures+=("Mobile-facing changes detected, but COMMANDS.md does not define a runnable full native Appium '${mobile_command_label}' command and no PROCESS_EXCEPTIONS.md entry was found.")
  elif ! mobile_command_is_native_appium "$mobile_command_value"; then
    automation_failures+=("Mobile-facing changes detected, but '${mobile_command_label}' is not a full native Appium command. Partial device checks do not satisfy the methodology.")
  elif ! selected_command_present "$mobile_command_label"; then
    automation_failures+=("Mobile-facing changes detected, but '${mobile_command_label}' was not included in the current verify-project.sh run.")
  fi
fi

if (( requires_desktop_browser_like_automation == 1 )); then
  if has_process_exception_match 'desktop automation|electron|tauri|playwriter|playwright|appium|mac2|winappdriver|windows driver'; then
    human_follow_up="yes"
  elif [[ -z "$desktop_command_value" && -z "$browser_command_value" ]]; then
    automation_failures+=("Desktop app changes detected, but neither '${desktop_command_label}' nor '${browser_command_label}' is defined as a runnable command in COMMANDS.md, and no PROCESS_EXCEPTIONS.md entry was found.")
  elif ! selected_command_present "$desktop_command_label" && ! selected_command_present "$browser_command_label"; then
    automation_failures+=("Desktop app changes detected, but neither '${desktop_command_label}' nor '${browser_command_label}' was included in the current verify-project.sh run.")
  fi
fi

if (( requires_native_desktop_automation == 1 )); then
  if has_process_exception_match 'desktop automation|native desktop|appium|mac2|winappdriver|windows driver'; then
    human_follow_up="yes"
  elif [[ -z "$desktop_command_value" ]]; then
    automation_failures+=("Native desktop changes detected, but COMMANDS.md does not define a runnable '${desktop_command_label}' command and no PROCESS_EXCEPTIONS.md entry was found.")
  elif ! selected_command_present "$desktop_command_label"; then
    automation_failures+=("Native desktop changes detected, but '${desktop_command_label}' was not included in the current verify-project.sh run.")
  fi
fi

if [[ ${#commands_to_run[@]} -eq 0 ]]; then
  echo "No runnable verification commands were found in COMMANDS.md for sections: $sections_csv" >&2
  exit 1
fi

if [[ ${#automation_failures[@]} -gt 0 ]]; then
  if (( json_mode == 1 )); then
    printf '{'
    printf '"target":"%s",' "$(json_escape "$target_dir")"
    printf '"result":"failed",'
    printf '"successes":[],"failures":'
    print_json_array automation_failures
    printf '}\n'
  else
    echo "Verification failed for $target_dir"
    echo "UI automation requirements were not met:"
    printf '  - %s\n' "${automation_failures[@]}"
  fi
  exit 1
fi

successes=()
failures=()
all_command_lines=()
log_details=""

for idx in "${!commands_to_run[@]}"; do
  label="${command_labels[$idx]}"
  cmd="${commands_to_run[$idx]}"
  tmp_output="$(mktemp)"
  status=0
  if (cd "$target_dir" && bash -lc "$cmd") >"$tmp_output" 2>&1; then
    successes+=("$label => $cmd")
    result_label="PASS"
  else
    status=$?
    failures+=("$label => $cmd (exit $status)")
    result_label="FAIL"
  fi

  output_preview="$(head -n 20 "$tmp_output")"
  rm -f "$tmp_output"

  all_command_lines+=("$label => $cmd [$result_label]")
  log_details+="- ${label}: \`${cmd}\` => ${result_label}"$'\n'
  if [[ -n "$output_preview" ]]; then
    while IFS= read -r output_line; do
      log_details+="  - ${output_line}"$'\n'
    done <<< "$output_preview"
  fi
done

overall_result="passed"
if [[ ${#failures[@]} -gt 0 ]]; then
  overall_result="failed"
fi

if (( write_log == 1 )); then
  {
    printf '\n## Verification Entry - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf -- '- Date: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf -- '- Scope: %s\n' "$scope_label"
    printf -- '- Environment label: %s\n' "$environment_label"
    printf -- '- Timestamp: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf -- '- Commands / checks run:\n'
    printf '%s' "$log_details"
    printf -- '- Pass / fail: %s\n' "$overall_result"
    printf -- '- Artifact / log path: %s\n' "$artifact_path"
    printf -- '- Human follow-up required: %s\n' "$human_follow_up"
    printf -- '- Result: %s\n' "$overall_result"
    if [[ ${#failures[@]} -gt 0 ]]; then
      printf -- '- Known gaps: %s\n' "One or more verification commands failed."
    else
      printf -- '- Known gaps: none recorded\n'
    fi
  } >> "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")"
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"result":"%s",' "$(json_escape "$overall_result")"
  printf '"successes":'
  print_json_array successes
  printf ','
  printf '"failures":'
  print_json_array failures
  printf '}\n'
else
  echo "Verification ${overall_result} for $target_dir"
  if [[ ${#successes[@]} -gt 0 ]]; then
    echo "Passed commands:"
    printf '  - %s\n' "${successes[@]}"
  fi
  if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Failed commands:"
    printf '  - %s\n' "${failures[@]}"
  fi
fi

if [[ "$overall_result" == "passed" ]]; then
  exit 0
fi

exit 1
