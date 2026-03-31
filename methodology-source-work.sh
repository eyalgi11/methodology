#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: methodology-source-work.sh <start|finish|commit> [options] [target-directory]

Template-source helper for using the methodology on its own source repo.

start:
  - runs work-preflight
  - records a begin-work checkpoint with the control-surface docs

finish:
  - refreshes methodology state
  - renders the audit page
  - runs the registry check
  - prints a short completion summary

commit:
  - runs the finish flow
  - stages the methodology source repo
  - creates a local commit for methodology-source changes only

Options for commit:
  --message TEXT   Custom commit message
EOF
}

resolve_target_dir() {
  local target="${1:-$PWD}"
  if [[ ! -d "$target" ]]; then
    echo "Target directory does not exist: $target" >&2
    exit 1
  fi
  cd "$target" && pwd
}

read_state_field() {
  local state_file="$1"
  local field="$2"
  python3 - "$state_file" "$field" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
field = sys.argv[2]
data = json.loads(path.read_text()) if path.exists() else {}
value = data.get(field, "")
print(value if value is not None else "")
PY
}

if (($# < 1)); then
  usage >&2
  exit 1
fi

command_name="$1"
shift
target_arg="${PWD}"
commit_message="Update methodology source workflow"

while (($# > 0)); do
  case "$1" in
    --message)
      shift
      [[ $# -gt 0 ]] || { echo "--message requires text" >&2; exit 1; }
      commit_message="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="$(resolve_target_dir "$target_arg")"
state_file="$target_dir/methodology-state.json"

if [[ ! -f "$state_file" ]]; then
  echo "This helper expects a methodology source repo with methodology-state.json at: $target_dir" >&2
  exit 1
fi

mode_name="$(read_state_field "$state_file" "maturity_mode")"
if [[ "$mode_name" != "template_source" ]]; then
  echo "This helper is for template_source repos. Current mode: ${mode_name:-unknown}" >&2
  exit 1
fi

case "$command_name" in
  start)
    preflight_status=0
    preflight_json="$("$SCRIPT_DIR/work-preflight.sh" --json "$target_dir" 2>/dev/null)" || preflight_status=$?
    task="$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(data.get("task",""))' "$preflight_json" 2>/dev/null || true)"
    task_state="$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(data.get("task_state",""))' "$preflight_json" 2>/dev/null || true)"
    spec_path="$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(data.get("active_spec",""))' "$preflight_json" 2>/dev/null || true)"
    summary="$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(data.get("summary",""))' "$preflight_json" 2>/dev/null || true)"
    blockers="$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print("; ".join(data.get("blockers", [])))' "$preflight_json" 2>/dev/null || true)"
    verification_path="$(read_state_field "$state_file" "verification_path")"
    if [[ -z "$verification_path" ]]; then
      verification_path="Run the relevant script checks, rerender methodology-audit.html, and confirm registry/doc updates."
    fi
    if [[ -z "$task" ]]; then
      task="Maintain methodology source workflow"
    fi
    if [[ -z "$task_state" ]]; then
      task_state="in_progress"
    fi

    docs=(
      "METHODOLOGY_PRINCIPLES.md"
      "DEFAULT_BEHAVIOR.md"
      "METHODOLOGY_CONTROL_LOOP.md"
    )
    if [[ -f "$target_dir/../AGENTS.md" ]]; then
      docs+=("../AGENTS.md")
    fi
    if [[ -n "$spec_path" && "$spec_path" != "n/a" ]]; then
      docs+=("$spec_path")
    fi

    args=("$SCRIPT_DIR/begin-work.sh" --task "$task" --state "$task_state" --verification-path "$verification_path")
    if [[ -n "$spec_path" && "$spec_path" != "n/a" ]]; then
      args+=(--spec "$spec_path")
    fi
    for doc in "${docs[@]}"; do
      args+=(--doc "$doc")
    done
    args+=("$target_dir")
    "${args[@]}"
    echo "Source workflow started."
    echo "Preflight: ${summary:-n/a}"
    if [[ -n "$blockers" ]]; then
      echo "Preflight blockers: $blockers"
    fi
    if (( preflight_status != 0 )); then
      exit "$preflight_status"
    fi
    ;;
  finish)
    "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null
    "$SCRIPT_DIR/render-methodology-audit.sh" "$target_dir" >/dev/null
    "$SCRIPT_DIR/methodology-registry-check.sh" "$target_dir"
    echo "Source workflow finished."
    echo "Audit: $target_dir/methodology-audit.html"
    ;;
  commit)
    repo_root="$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$repo_root" ]]; then
      echo "Target is not inside a git repo: $target_dir" >&2
      exit 1
    fi
    target_rel="$(python3 - "$repo_root" "$target_dir" <<'PY'
import os, sys
print(os.path.relpath(sys.argv[2], sys.argv[1]))
PY
)"
    "$0" finish "$target_dir"
    if [[ -z "$(git -C "$repo_root" status --short -- "$target_rel")" ]]; then
      echo "No methodology-source changes to commit."
      exit 0
    fi
    git -C "$repo_root" add -- "$target_rel"
    if git -C "$repo_root" diff --cached --quiet -- "$target_rel"; then
      echo "No staged methodology-source changes to commit."
      exit 0
    fi
    git -C "$repo_root" commit -m "$commit_message"
    echo "Source workflow committed."
    echo "Commit message: $commit_message"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown subcommand: $command_name" >&2
    usage >&2
    exit 1
    ;;
esac
