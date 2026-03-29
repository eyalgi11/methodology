#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: methodology-entry.sh [--git] [--profile PROFILE] [target-directory]

Ensures the methodology exists, runs the standard resume flow, and records a
visible start-of-work checkpoint for the current project.

Options:
  --git        Backward-compatible no-op. Git initialization is now mandatory.
  --profile    minimal, normal, or deep startup profile (default: normal)
  -h, --help   Show this help text
EOF
}

target_arg=""
init_git=0
profile="normal"

while (($# > 0)); do
  case "$1" in
    --git) init_git=1; shift ;;
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

target_dir="${target_arg:-$PWD}"
mkdir -p "$target_dir"
target_dir="$(resolve_target_dir "$target_dir")"

bootstrapped=0
required_files=(
  "AGENTS.md"
  "AGENT_TEAM.md"
  "CORE_CONTEXT.md"
  "PROJECT_BRIEF.md"
  "TASKS.md"
  "MULTI_AGENT_PLAN.md"
  "SESSION_STATE.md"
  "HANDOFF.md"
  "MANUAL_CHECKS.md"
  "METHODOLOGY_MODE.md"
  "OBSERVABLE_COMPLIANCE.md"
)

for file_name in "${required_files[@]}"; do
  if [[ ! -f "$(project_file_path "$target_dir" "$file_name")" ]]; then
    bootstrapped=1
    break
  fi
done

ensure_git_repo "$target_dir"

if (( bootstrapped == 1 )); then
  echo "Bootstrapping methodology..."
  "$SCRIPT_DIR/bootstrap-methodology.sh" "$target_dir" >/dev/null
fi

echo "Refreshing methodology state..."
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true

project_name="$(basename "$target_dir")"
project_slug="$(slugify "$project_name")"
context_file="$(mktemp "/tmp/${project_slug:-project}-context-XXXXXX.md")"
echo "Running resume flow..."
"$SCRIPT_DIR/resume-work.sh" --profile "$profile" --output "$context_file" "$target_dir" >/dev/null

state_json_path="$(project_file_path "$target_dir" "methodology-state.json")"
task_name="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task",""))' "$state_json_path" 2>/dev/null || true)"
task_state="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task_state",""))' "$state_json_path" 2>/dev/null || true)"
spec_path="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_spec",""))' "$state_json_path" 2>/dev/null || true)"
if [[ -z "$task_name" ]]; then
  task_info="$(effective_task_record "$target_dir")"
  task_name="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_info" 2>/dev/null || true)"
  task_state="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("state",""))' "$task_info" 2>/dev/null || true)"
  spec_path="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("spec",""))' "$task_info" 2>/dev/null || true)"
fi
if [[ -z "$task_name" ]]; then
  task_name="Define initial project brief and first task"
  task_state="setup"
fi

docs=()
docs+=( "$(display_project_relpath "$target_dir" "methodology-state.json")" )
case "$profile" in
  minimal)
    for file_name in CORE_CONTEXT.md WORK_INDEX.md; do
      [[ -f "$(project_file_path "$target_dir" "$file_name")" ]] && docs+=("$(display_project_relpath "$target_dir" "$file_name")")
    done
    if [[ -n "$task_name" && "$task_name" != "Define initial project brief and first task" ]]; then
      docs+=("$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task_name")")")
      docs+=("$(display_project_relpath "$target_dir" "$(task_state_relpath "$task_name")")")
    fi
    ;;
  normal)
    for file_name in CORE_CONTEXT.md WORK_INDEX.md PROJECT_BRIEF.md TASKS.md SESSION_STATE.md HANDOFF.md; do
      [[ -f "$(project_file_path "$target_dir" "$file_name")" ]] && docs+=("$(display_project_relpath "$target_dir" "$file_name")")
    done
    ;;
  deep)
    for file_name in CORE_CONTEXT.md WORK_INDEX.md PROJECT_BRIEF.md TASKS.md SESSION_STATE.md HANDOFF.md COMMANDS.md LOCAL_ENV.md REPO_MAP.md ARCHITECTURE.md HOTFIX.md; do
      [[ -f "$(project_file_path "$target_dir" "$file_name")" ]] && docs+=("$(display_project_relpath "$target_dir" "$file_name")")
    done
    if [[ -n "$task_name" && "$task_name" != "Define initial project brief and first task" ]]; then
      docs+=("$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task_name")")")
      docs+=("$(display_project_relpath "$target_dir" "$(task_state_relpath "$task_name")")")
    fi
    ;;
esac
if [[ -n "$spec_path" ]]; then
  docs+=("$spec_path")
fi

verification_path="Review the active docs, follow the feature spec verification plan if present, and run verify-project.sh before calling meaningful work done."
if [[ "$task_state" == "setup" ]]; then
  verification_path="Define PROJECT_BRIEF.md, set the first task in TASKS.md, and record the intended verification path before implementation starts."
fi

begin_args=(--task "$task_name" --state "$task_state" --verification-path "$verification_path")
if [[ -n "$spec_path" ]]; then
  begin_args+=(--spec "$spec_path")
fi
for file_name in "${docs[@]}"; do
  begin_args+=(--doc "$file_name")
done
echo "Recording visible start checkpoint..."
"$SCRIPT_DIR/begin-work.sh" "${begin_args[@]}" "$target_dir" >/dev/null

if [[ -f "$SCRIPT_DIR/fix-project-perms.sh" ]]; then
  bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null 2>&1 || true
fi

echo "Methodology entry completed for $target_dir"
if (( bootstrapped == 1 )); then
  echo "Methodology was bootstrapped in this project."
else
  echo "Existing methodology was rehydrated."
fi
echo "Startup profile: $profile"
echo "Active task: $task_name"
echo "Task state: $task_state"
echo "Context pack: $context_file"
