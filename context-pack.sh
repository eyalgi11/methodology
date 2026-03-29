#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: context-pack.sh [--output FILE] [--max-lines N] [--profile PROFILE] [target-directory]

Builds a compact markdown resume bundle from the key methodology docs and repo state.
EOF
}

target_arg=""
output_file=""
max_lines=40
profile="normal"

while (($# > 0)); do
  case "$1" in
    --output) output_file="$2"; shift 2 ;;
    --max-lines) max_lines="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
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

if [[ "$profile" != "minimal" && "$profile" != "normal" && "$profile" != "deep" ]]; then
  echo "--profile must be one of: minimal, normal, deep" >&2
  exit 1
fi
if [[ "$max_lines" == "40" ]]; then
  max_lines="$(context_pack_max_lines_for_profile "$profile")"
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
branch="$(current_git_branch "$target_dir")"
status_output="$(git_status_short "$target_dir" || true)"
recent_files="$(recent_work_files "$target_dir" 10 || true)"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
if [[ -f "$SCRIPT_DIR/refresh-methodology-state.sh" ]]; then
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
fi
task_record="$(effective_task_record "$target_dir")"
active_task="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_record" 2>/dev/null || true)"
active_task_state="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("state",""))' "$task_record" 2>/dev/null || true)"
active_spec="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("spec",""))' "$task_record" 2>/dev/null || true)"

pack_output() {
  printf '# Context Pack\n\n'
  printf -- '- Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf -- '- Target: %s\n' "$target_dir"
  printf -- '- Branch: %s\n\n' "$branch"
  printf -- '- Profile: %s\n\n' "$profile"

  if [[ -f "$state_file" ]]; then
    printf '## methodology/methodology-state.json\n\n'
    printf '```json\n'
    sed -n "1,${max_lines}p" "$state_file"
    printf '```\n\n'
  fi

  printf '## Repo State\n\n'
  if [[ -n "$status_output" ]]; then
    printf '```text\n%s\n```\n\n' "$status_output"
  else
    printf 'Working tree appears clean or no git repo was detected.\n\n'
  fi

  if has_git_repo "$target_dir"; then
    printf '## Recent Commits\n\n'
    printf '```text\n'
    git -C "$target_dir" log --oneline -n 5 2>/dev/null || true
    printf '```\n\n'
  fi

  printf '## Recent Work Files\n\n'
  if [[ -n "$recent_files" ]]; then
    printf '```text\n%s\n```\n\n' "$recent_files"
  else
    printf 'No recent non-methodology work files detected.\n\n'
  fi

  docs=(CORE_CONTEXT.md WORK_INDEX.md)
  if [[ "$profile" == "normal" || "$profile" == "deep" ]]; then
    docs+=(PROJECT_BRIEF.md TASKS.md SESSION_STATE.md HANDOFF.md MANUAL_CHECKS.md)
  fi
  if [[ "$profile" == "deep" ]]; then
    docs+=(COMMANDS.md LOCAL_ENV.md REPO_MAP.md ARCHITECTURE.md HOTFIX.md DECISIONS.md)
  fi

  local doc
  for doc in "${docs[@]}"; do
    doc_path="$(project_file_path "$target_dir" "$doc")"
    if [[ ! -f "$doc_path" ]]; then
      continue
    fi

    printf '## %s\n\n' "$(display_project_relpath "$target_dir" "$doc")"
    printf '```md\n'
    sed -n "1,${max_lines}p" "$doc_path"
    line_count="$(wc -l < "$doc_path")"
    if (( line_count > max_lines )); then
      printf '\n[truncated after %s lines]\n' "$max_lines"
    fi
    printf '```\n\n'
  done

  if [[ -n "$active_task" && "$active_task" != "setup" ]]; then
    printf '## Active Task Workspace\n\n'
    printf -- '- Task: %s\n' "$active_task"
    printf -- '- State: %s\n' "${active_task_state:-unknown}"
    printf -- '- Spec: %s\n\n' "${active_spec:-n/a}"

    workspace_docs=(
      "$(task_state_relpath "$active_task")"
      "$(task_handoff_relpath "$active_task")"
    )

    local workspace_doc
    for workspace_doc in "${workspace_docs[@]}"; do
      doc_path="$(project_file_path "$target_dir" "$workspace_doc")"
      if [[ ! -f "$doc_path" ]]; then
        continue
      fi

      printf '## %s\n\n' "$(display_project_relpath "$target_dir" "$workspace_doc")"
      printf '```md\n'
      sed -n "1,${max_lines}p" "$doc_path"
      line_count="$(wc -l < "$doc_path")"
      if (( line_count > max_lines )); then
        printf '\n[truncated after %s lines]\n' "$max_lines"
      fi
      printf '```\n\n'
    done

    if [[ -n "$active_spec" ]]; then
      doc_path="$(project_file_path "$target_dir" "$active_spec")"
      if [[ -f "$doc_path" ]]; then
        printf '## %s\n\n' "$(display_project_relpath "$target_dir" "$active_spec")"
        printf '```md\n'
        sed -n "1,${max_lines}p" "$doc_path"
        line_count="$(wc -l < "$doc_path")"
        if (( line_count > max_lines )); then
          printf '\n[truncated after %s lines]\n' "$max_lines"
        fi
        printf '```\n\n'
      fi
    fi
  fi
}

if [[ -n "$output_file" ]]; then
  pack_output > "$output_file"
  echo "Context pack written to $output_file"
else
  pack_output
fi
