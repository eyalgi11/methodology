#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: close-work.sh --task "Task name" [options] [target-directory]

Closes a work item by moving it to Done in TASKS.md and updating closure context
across SESSION_STATE.md, HANDOFF.md, PROJECT_HEALTH.md, and RELEASE_NOTES.md.

Options:
  --task TEXT
  --summary TEXT
  --verification TEXT
  --remaining TEXT
  --next-step TEXT
  --release-note TEXT
  --health TEXT        green, yellow, or red
  --learning-target TEXT
  --learning-note TEXT
  --learning-review-by TEXT
EOF
}

target_arg=""
task=""
summary=""
verification=""
remaining=""
next_step=""
release_note=""
health="green"
learning_target=""
learning_note=""
learning_review_by=""

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --verification) verification="$2"; shift 2 ;;
    --remaining) remaining="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    --release-note) release_note="$2"; shift 2 ;;
    --health) health="$2"; shift 2 ;;
    --learning-target) learning_target="$2"; shift 2 ;;
    --learning-note) learning_note="$2"; shift 2 ;;
    --learning-review-by) learning_review_by="$2"; shift 2 ;;
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

if [[ -z "$task" ]]; then
  echo "--task is required." >&2
  usage >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
summary="${summary:-$task completed.}"
verification="${verification:-Verification summary not supplied. Review VERIFICATION_LOG.md.}"
remaining="${remaining:-No remaining work recorded for this closure.}"
next_step="${next_step:-Pick the next highest-priority ready task.}"
release_note="${release_note:-$summary}"
ensure_task_workspace "$target_dir" "$task" "done"

python3 - "$(project_file_path "$target_dir" "TASKS.md")" "$task" "$summary" "$verification" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task = sys.argv[2]
summary = sys.argv[3]
verification = sys.argv[4]

text = path.read_text() if path.exists() else "## WIP Limits\n\n- In Progress: 1\n- Ready: 3\n\n## Planned\n\n## Ready\n\n## In Progress\n\n## Blocked\n\n## Done\n\n## Cancelled\n"
lines = text.splitlines()

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

def normalize_task(value: str) -> str:
    value = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", value).strip()
    value = value.strip("`").strip()
    return value

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

found_main = task
new_sections = []
found = False
for heading, body_lines in sections:
    kept_blocks = []
    for block in split_blocks(body_lines):
        main = normalize_task(block[0])
        if main == task:
            found = True
            found_main = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", block[0]).strip()
            continue
        kept_blocks.append(block)
    new_sections.append((heading, kept_blocks))

done_block = [
    f"- {found_main}",
    f"  - Outcome: {summary}",
    f"  - Verification: {verification}",
]

target_headings = [h for h, _ in new_sections]
if "## Done" not in target_headings:
    new_sections.append(("## Done", []))

rebuilt = []
if prelude:
    rebuilt.extend(prelude)
    if rebuilt[-1] != "":
        rebuilt.append("")

for heading, blocks in new_sections:
    rebuilt.append(heading)
    rebuilt.append("")
    if heading == "## Done":
        blocks = [done_block] + blocks
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

session_body=$(cat <<EOF
- Closed at: $(timestamp_now)
- Task: ${task}
- Summary: ${summary}
- Verification: ${verification}
- Next step: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "work-closure" "## Work Closure" "$session_body"

handoff_body=$(cat <<EOF
- Closed at: $(timestamp_now)
- Completed: ${task}
- Summary: ${summary}
- Remaining: ${remaining}
- Resume here: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "work-closure" "## Work Closure" "$handoff_body"
append_or_replace_auto_section "$(task_state_file "$target_dir" "$task")" "work-closure" "## Work Closure" "$session_body"
append_or_replace_auto_section "$(task_handoff_file "$target_dir" "$task")" "work-closure" "## Work Closure" "$handoff_body"
update_work_index_entry "$target_dir" "$task" "done"

health_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Status: ${health}
- Recently closed: ${task}
- Summary: ${summary}
- Next step: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "PROJECT_HEALTH.md")" "work-closure" "## Recent Closure" "$health_body"

python3 - "$(project_file_path "$target_dir" "RELEASE_NOTES.md")" "$release_note" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
note = sys.argv[2]
text = path.read_text() if path.exists() else "# Release Notes\n\n## Unreleased\n"
lines = text.splitlines()
out = []
inserted = False
in_unreleased = False
for line in lines:
    out.append(line)
    if line == "## Unreleased":
        in_unreleased = True
        continue
    if in_unreleased and line.startswith("## ") and not inserted:
        out.insert(len(out) - 1, f"- {note}")
        inserted = True
        in_unreleased = False

if not inserted:
    if "## Unreleased" not in lines:
        if out and out[-1] != "":
            out.append("")
        out.extend(["## Unreleased", f"- {note}"])
    else:
        out.append(f"- {note}")

path.write_text("\n".join(out) + "\n")
PY

if [[ -n "$learning_target" && -n "$learning_note" ]]; then
  learning_args=(--target "$learning_target" --summary "$learning_note")
  if [[ -n "$learning_review_by" ]]; then
    learning_args+=(--review-by "$learning_review_by")
  fi
  "$SCRIPT_DIR/record-learning.sh" "${learning_args[@]}" "$target_dir" >/dev/null
fi

echo "Closed work item: $task"
echo "Updated: TASKS.md, SESSION_STATE.md, HANDOFF.md, PROJECT_HEALTH.md, RELEASE_NOTES.md"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/archive-cold-docs.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/refresh-core-context.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/compact-hot-docs.sh" "$target_dir" >/dev/null 2>&1 || true
