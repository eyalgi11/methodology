#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: next-task.sh [options] [target-directory]

Moves the next ready task into progress, records the start checkpoint, and
creates a local git commit if there are changes.

Options:
  --task TEXT
  --verification-path TEXT
  --commit-message TEXT
  --no-commit
EOF
}

target_arg=""
task=""
verification_path=""
commit_message=""
commit_enabled=1

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --verification-path) verification_path="$2"; shift 2 ;;
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

task_info="$(python3 - "$(project_file_path "$target_dir" "TASKS.md")" "${task:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
wanted = sys.argv[2].strip()
if not path.exists():
    print("{}")
    raise SystemExit(0)

sections = []
current_heading = None
current_lines = []
for line in path.read_text().splitlines():
    if line.startswith("## "):
        if current_heading is not None:
            sections.append((current_heading, current_lines))
        current_heading = line
        current_lines = []
    elif current_heading is not None:
        current_lines.append(line)
if current_heading is not None:
    sections.append((current_heading, current_lines))

def normalize(line: str) -> str:
    value = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", line).strip()
    return value.strip("`").strip()

def split_blocks(lines):
    blocks = []
    current = []
    for line in lines:
        if line.startswith("- "):
            if current:
                blocks.append(current)
            current = [line]
            continue
        if current:
            current.append(line)
    if current:
        blocks.append(current)
    return blocks

def spec_for(block):
    main = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", block[0]).strip()
    match = re.search(r"\(`?((?:specs|features)/[^`)\n]+\.md)`?\)|`?\(((?:specs|features)/[^`)\n]+\.md)\)`?", main)
    if match:
        return match.group(1) or match.group(2) or ""
    for line in block[1:]:
        m = re.search(r"^\s*-\s*Spec:\s*(.+)$", line)
        if not m:
            continue
        spec_match = re.search(r"((?:specs|features)/[^`,;\n)]+\.md)", m.group(1))
        if spec_match:
            return spec_match.group(1)
    return ""

chosen = {}
for heading, lines in sections:
    if heading != "## Ready":
        continue
    for block in split_blocks(lines):
        label = normalize(block[0])
        if wanted and label != wanted:
            continue
        chosen = {"task": label, "spec": spec_for(block), "heading": heading}
        print(json.dumps(chosen))
        raise SystemExit(0)

print("{}")
PY
)"

chosen_task="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("task",""))' "$task_info" 2>/dev/null || true)"
spec_path="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("spec",""))' "$task_info" 2>/dev/null || true)"

if [[ -z "$chosen_task" ]]; then
  if [[ -n "$task" ]]; then
    echo "Task is not in Ready: $task" >&2
  else
    echo "No ready task found." >&2
  fi
  exit 1
fi

chosen_task="$(trim_whitespace "$(printf '%s' "$chosen_task" | tr -d '`')")"
"$SCRIPT_DIR/move-task.sh" --task "$chosen_task" --to in_progress --from ready "$target_dir"

verification_path="${verification_path:-Review the feature spec verification plan, run verify-project.sh before calling meaningful work done, and record the result in VERIFICATION_LOG.md.}"
begin_args=(--task "$chosen_task" --state in_progress --verification-path "$verification_path")
if [[ -n "$spec_path" ]]; then
  begin_args+=(--spec "$spec_path")
fi
"$SCRIPT_DIR/begin-work.sh" "${begin_args[@]}" "$target_dir" >/dev/null

if (( commit_enabled == 1 )); then
  git_commit_all_if_changed "$target_dir" "${commit_message:-start: $chosen_task}"
fi

echo "Started next task: $chosen_task"
if [[ -n "$spec_path" ]]; then
  echo "Spec: $spec_path"
fi
