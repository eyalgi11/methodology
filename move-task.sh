#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: move-task.sh --task "Task name" --to STATE [options] [target-directory]

Moves a task between lifecycle states while enforcing readiness and WIP rules.

Options:
  --task TEXT
  --to STATE        planned, ready, in_progress, blocked, cancelled
  --from STATE      Optional source state hint
  --force           Skip readiness and WIP enforcement
EOF
}

normalize_state() {
  case "$1" in
    planned|ready|in_progress|blocked|cancelled) printf '%s' "$1" ;;
    "in-progress") printf 'in_progress' ;;
    *)
      echo "Invalid state: $1" >&2
      exit 1
      ;;
  esac
}

state_heading() {
  case "$1" in
    planned) printf '## Planned' ;;
    ready) printf '## Ready' ;;
    in_progress) printf '## In Progress' ;;
    blocked) printf '## Blocked' ;;
    cancelled) printf '## Cancelled' ;;
  esac
}

target_arg=""
task=""
to_state=""
from_state=""
force=0

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --to) to_state="$(normalize_state "$2")"; shift 2 ;;
    --from) from_state="$(normalize_state "$2")"; shift 2 ;;
    --force) force=1; shift ;;
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

if [[ -z "$task" || -z "$to_state" ]]; then
  echo "--task and --to are required." >&2
  exit 1
fi

if [[ "$to_state" == "done" ]]; then
  echo "Use close-work.sh to move a task to Done." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
to_heading="$(state_heading "$to_state")"

if (( force == 0 )) && [[ "$to_state" == "ready" ]]; then
  "$SCRIPT_DIR/ready-check.sh" --task "$task" "$target_dir" >/dev/null
fi

if (( force == 0 )) && [[ "$to_state" == "ready" || "$to_state" == "in_progress" ]]; then
  current_count="$(count_tasks_in_section "$tasks_file" "$to_heading")"
  limit="$(task_limit_for_section "$tasks_file" "$to_heading")"
  if [[ "$limit" =~ ^[0-9]+$ ]] && (( limit > 0 )); then
    current_heading=""
    if [[ -n "$from_state" ]]; then
      current_heading="$(state_heading "$from_state")"
    else
      current_heading="$(python3 - "$tasks_file" "$task" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task = sys.argv[2]
section = ""
block = []

def normalize(value: str) -> str:
    value = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", value).strip()
    return value.strip("`").strip()

def emit(sec, lines):
    if not sec or not lines:
        return False
    if normalize(lines[0]) == task:
        print(sec)
        return True
    return False

for line in path.read_text().splitlines():
    if line.startswith("## "):
        if emit(section, block):
            raise SystemExit(0)
        block = []
        section = line
        continue
    if line.startswith("- "):
        if emit(section, block):
            raise SystemExit(0)
        block = [line]
        continue
    if block and (line.startswith("  ") or not line.strip()):
        block.append(line)
if emit(section, block):
    raise SystemExit(0)
PY
)"
    fi
    if [[ "$current_heading" != "$to_heading" ]] && (( current_count >= limit )); then
      echo "WIP limit reached for $to_heading ($current_count/$limit). Use --force or reduce WIP first." >&2
      exit 1
    fi
  fi
fi

python3 - "$tasks_file" "$task" "$to_heading" "${from_state:-}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task = sys.argv[2]
to_heading = sys.argv[3]
from_state = sys.argv[4]
from_heading = {
    "planned": "## Planned",
    "ready": "## Ready",
    "in_progress": "## In Progress",
    "blocked": "## Blocked",
    "cancelled": "## Cancelled",
}.get(from_state, "")

text = path.read_text() if path.exists() else "## WIP Limits\n\n- In Progress: 1\n- Ready: 3\n\n## Planned\n\n## Ready\n\n## In Progress\n\n## Blocked\n\n## Done\n\n## Cancelled\n"
lines = text.splitlines()

def normalize(value: str) -> str:
    value = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", value).strip()
    return value.strip("`").strip()

sections = []
current_heading = None
current_lines = []
prelude = []
for line in lines:
    if line.startswith("## "):
        if current_heading is None:
            pass
        else:
            sections.append((current_heading, current_lines))
        current_heading = line
        current_lines = []
    else:
        if current_heading is None:
            prelude.append(line)
        else:
            current_lines.append(line)
if current_heading is not None:
    sections.append((current_heading, current_lines))

def split_blocks(section_lines):
    blocks = []
    current = []
    for line in section_lines:
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

removed_block = None
new_sections = []
for heading, body_lines in sections:
    kept_blocks = []
    for block in split_blocks(body_lines):
        if normalize(block[0]) == task and (not from_heading or heading == from_heading) and removed_block is None:
            removed_block = block
            continue
        kept_blocks.append(block)
    new_sections.append((heading, kept_blocks))

if removed_block is None:
    raise SystemExit(f"Task not found: {task}")

target_headings = [h for h, _ in new_sections]
if to_heading not in target_headings:
    new_sections.append((to_heading, []))

rebuilt = []
if prelude:
    rebuilt.extend(prelude)
    if rebuilt[-1] != "":
        rebuilt.append("")

for heading, blocks in new_sections:
    rebuilt.append(heading)
    rebuilt.append("")
    if heading == to_heading:
        blocks = [removed_block] + blocks
    for idx, block in enumerate(blocks):
        rebuilt.extend(block)
        if idx != len(blocks) - 1:
            rebuilt.append("")
    if blocks:
        rebuilt.append("")

while rebuilt and rebuilt[-1] == "":
    rebuilt.pop()
path.write_text("\n".join(rebuilt) + "\n")
PY

"$SCRIPT_DIR/sync-docs.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Moved task to $to_state: $task"
