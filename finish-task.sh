#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: finish-task.sh [options] [target-directory]

Finishes a task that is truly done: runs the standard finish-work sequence and
creates a local git commit if there are changes.

Options:
  --task TEXT
  --summary TEXT
  --remaining TEXT
  --next-step TEXT
  --release-note TEXT
  --health TEXT
  --version TEXT
  --learning-target TEXT
  --learning-note TEXT
  --learning-review-by TEXT
  --commit-message TEXT
  --no-commit
EOF
}

target_arg=""
task=""
summary=""
remaining=""
next_step=""
release_note=""
health="green"
version_label=""
learning_target=""
learning_note=""
learning_review_by=""
commit_message=""
commit_enabled=1

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --remaining) remaining="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    --release-note) release_note="$2"; shift 2 ;;
    --health) health="$2"; shift 2 ;;
    --version) version_label="$2"; shift 2 ;;
    --learning-target) learning_target="$2"; shift 2 ;;
    --learning-note) learning_note="$2"; shift 2 ;;
    --learning-review-by) learning_review_by="$2"; shift 2 ;;
    --commit-message) commit_message="$2"; shift 2 ;;
    --no-commit) commit_enabled=0; shift ;;
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

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
ensure_git_repo "$target_dir"

if [[ -z "$task" ]]; then
  task="$(python3 - "$target_dir" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
state_path = target / "methodology" / "methodology-state.json"
task = ""
state = ""
if state_path.exists():
    try:
        data = json.loads(state_path.read_text())
        task = (data.get("active_task") or "").replace("`", "").strip()
        state = (data.get("active_task_state") or "").strip()
    except Exception:
        pass
if task and state == "in_progress":
    print(task)
PY
)"
fi

if [[ -z "$task" ]]; then
  echo "No in-progress task detected. Pass --task explicitly." >&2
  exit 1
fi

task="$(trim_whitespace "$(printf '%s' "$task" | tr -d '`')")"
if [[ -z "$summary" ]]; then
  summary="$task completed and accepted."
fi
if [[ -z "$next_step" ]]; then
  next_step="Start the next ready task with /home/eyal/system-docs/methodology/next-task.sh."
fi

finish_args=(--task "$task" --summary "$summary" --next-step "$next_step" --health "$health")
if [[ -n "$remaining" ]]; then
  finish_args+=(--remaining "$remaining")
fi
if [[ -n "$release_note" ]]; then
  finish_args+=(--release-note "$release_note")
fi
if [[ -n "$version_label" ]]; then
  finish_args+=(--version "$version_label")
fi
if [[ -n "$learning_target" ]]; then
  finish_args+=(--learning-target "$learning_target")
fi
if [[ -n "$learning_note" ]]; then
  finish_args+=(--learning-note "$learning_note")
fi
if [[ -n "$learning_review_by" ]]; then
  finish_args+=(--learning-review-by "$learning_review_by")
fi

"$SCRIPT_DIR/finish-work.sh" "${finish_args[@]}" "$target_dir"

if (( commit_enabled == 1 )); then
  git_commit_all_if_changed "$target_dir" "${commit_message:-finish: $task}"
fi

echo "Finished task: $task"
