#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: methodology-status.sh [--json] [target-directory]

Warns when continuity/state files are missing or older than the latest
non-methodology work file in the project.
EOF
}

json_mode=0
target_arg=""

while (($# > 0)); do
  case "$1" in
    --json)
      json_mode=1
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
if [[ "$mode" == "template_source" ]]; then
  if (( json_mode == 1 )); then
    printf '{"target":"%s","ok":true,"missing":[],"stale":[],"current":[],"latest_work_file":"","latest_work_timestamp":""}\n' "$(json_escape "$target_dir")"
  else
    echo "Status is current."
    echo "Template-source mode skips continuity freshness checks."
  fi
  exit 0
fi

IFS=$'\t' read -r latest_work_ts latest_work_path < <(latest_work_file_info "$target_dir")
latest_work_relpath="${latest_work_path#$target_dir/}"
task_record="$(effective_task_record "$target_dir")"
active_task="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_record" 2>/dev/null || true)"

missing_files=()
stale_files=()
current_files=()
status_files=("${METHODOLOGY_STATE_FILES[@]}")

if [[ -n "$active_task" && "$active_task" != "setup" ]]; then
  status_files+=("$(task_state_relpath "$active_task")")
  status_files+=("$(task_handoff_relpath "$active_task")")
fi

for file_name in "${status_files[@]}"; do
  file_path="$(project_file_path "$target_dir" "$file_name")"
  if [[ ! -f "$file_path" ]]; then
    missing_files+=("$file_name")
    continue
  fi

  file_ts=$(stat -c %Y "$file_path" 2>/dev/null || echo 0)
  if (( latest_work_ts > 0 && file_ts + 300 < latest_work_ts )); then
    stale_files+=("$file_name")
  else
    current_files+=("$file_name")
  fi
done

ok=1
if (( ${#missing_files[@]} > 0 || ${#stale_files[@]} > 0 )); then
  ok=0
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ok == 1 )) && printf true || printf false )"
  printf '"missing":'
  print_json_array missing_files
  printf ','
  printf '"stale":'
  print_json_array stale_files
  printf ','
  printf '"current":'
  print_json_array current_files
  printf ','
  printf '"latest_work_file":"%s",' "$(json_escape "${latest_work_relpath:-}")"
  printf '"latest_work_timestamp":"%s"' "$(json_escape "$(format_epoch "${latest_work_ts:-0}")")"
  printf '}\n'
else
  if (( ok == 1 )); then
    echo "Status is current."
    if [[ -n "$latest_work_relpath" ]]; then
      echo "Latest work file: $latest_work_relpath ($(format_epoch "${latest_work_ts:-0}"))"
    else
      echo "No non-methodology work files detected."
    fi
  else
    echo "Status warnings for $target_dir"
    if [[ -n "$latest_work_relpath" ]]; then
      echo "Latest work file: $latest_work_relpath ($(format_epoch "${latest_work_ts:-0}"))"
    else
      echo "Latest work file: none detected"
    fi
    if (( ${#missing_files[@]} > 0 )); then
      echo
      echo "Missing continuity files:"
      printf '  - %s\n' "${missing_files[@]}"
    fi
    if (( ${#stale_files[@]} > 0 )); then
      echo
      echo "Stale continuity files:"
      printf '  - %s\n' "${stale_files[@]}"
    fi
  fi
fi

if (( ok == 1 )); then
  exit 0
fi

exit 1
