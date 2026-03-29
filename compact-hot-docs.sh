#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: compact-hot-docs.sh [target-directory]

Keeps the hot-path methodology files compact by trimming long rolling sections
and archiving older completed tasks out of TASKS.md.
EOF
}

target_arg=""
while (($# > 0)); do
  case "$1" in
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
archive_path="$(project_file_path "$target_dir" "TASKS_ARCHIVE.md")"

[[ -f "$archive_path" ]] || cp "$SCRIPT_DIR/TASKS_ARCHIVE.md" "$archive_path"

python3 - "$target_dir" "$archive_path" <<'PY'
import re
import sys
from pathlib import Path

target = Path(sys.argv[1])
archive_path = Path(sys.argv[2])
MAX_CORE_LINES = 150
MAX_SESSION_LINES = 80
MAX_HANDOFF_LINES = 80
MAX_TASK_STATE_LINES = 200
MAX_TASK_HANDOFF_LINES = 100
MAX_WORK_INDEX_ENTRIES = 50

def split_sections(text: str):
    sections = {}
    order = []
    current = None
    buf = []
    for line in text.splitlines():
        if line.startswith("## "):
            if current is not None:
                sections[current] = buf[:]
            current = line
            order.append(line)
            buf = []
        else:
            buf.append(line)
    if current is not None:
        sections[current] = buf[:]
    return order, sections

def compact_markdown_file(path: Path, keep_rules: dict, max_lines: int | None = None):
    if not path.exists():
        return
    text = path.read_text()
    order, sections = split_sections(text)
    if not order:
        return
    for heading, keep_count in keep_rules.items():
        if heading not in sections:
            continue
        lines = sections[heading]
        bullets = [line for line in lines if line.startswith("- ")]
        if len(bullets) <= keep_count:
            continue
        kept = bullets[:keep_count]
        omitted = len(bullets) - keep_count
        sections[heading] = ["", *kept, f"- [auto] Older items omitted from this hot file: {omitted}. See archive/history files if needed."]
    out = []
    first = True
    for heading in order:
        if not first:
            out.append("")
        first = False
        out.append(heading)
        out.extend(sections[heading])
    if max_lines and len(out) > max_lines:
        out = out[: max_lines - 1] + [f"- [auto] Truncated to fit hot-doc budget ({max_lines} lines)."]
    path.write_text("\n".join(out).rstrip() + "\n")

def compact_work_index(path: Path):
    if not path.exists():
        return
    lines = path.read_text().splitlines()
    out = []
    blocks = []
    current = []
    for line in lines:
        if line.startswith("- Task: "):
            if current:
                blocks.append(current)
            current = [line]
        elif current and (line.startswith("  ") or not line.strip()):
            current.append(line)
        else:
            if current:
                blocks.append(current)
                current = []
            out.append(line)
    if current:
        blocks.append(current)
    if len(blocks) <= MAX_WORK_INDEX_ENTRIES:
        return
    kept = blocks[:MAX_WORK_INDEX_ENTRIES]
    omitted = len(blocks) - len(kept)
    rebuilt = []
    for block in kept:
        rebuilt.extend(block)
    rebuilt.append(f"- [auto] Omitted older active workspace entries: {omitted}.")
    header = [line for line in out if not line.startswith("- [auto] Omitted older active workspace entries:")]
    path.write_text("\n".join(header + [""] + rebuilt).rstrip() + "\n")

tasks_path = Path(sys.argv[1]) / "methodology" / "TASKS.md"
if not tasks_path.exists():
    tasks_path = target / "TASKS.md"
if tasks_path.exists():
    text = tasks_path.read_text()
    order, sections = split_sections(text)
    done_lines = sections.get("## Done", [])
    done_entries = []
    current = []
    for line in done_lines:
        if line.startswith("- "):
            if current:
                done_entries.append(current)
            current = [line]
        elif current:
            current.append(line)
    if current:
        done_entries.append(current)

    keep_done = 4
    if len(done_entries) > keep_done:
        archive_entries = done_entries[:-keep_done]
        kept_entries = done_entries[-keep_done:]

        archive_text = archive_path.read_text() if archive_path.exists() else "# Tasks Archive\n\n## Archived Done Tasks\n"
        if "## Archived Done Tasks" not in archive_text:
            archive_text = archive_text.rstrip() + "\n\n## Archived Done Tasks\n"
        archive_append = []
        for entry in archive_entries:
            archive_append.extend(entry)
            archive_append.append("")
        archive_path.write_text(archive_text.rstrip() + "\n\n" + "\n".join(archive_append).rstrip() + "\n")

        rebuilt_done = []
        for idx, entry in enumerate(kept_entries):
            rebuilt_done.extend(entry)
            if idx != len(kept_entries) - 1:
                rebuilt_done.append("")
        sections["## Done"] = rebuilt_done

        out = []
        first = True
        for heading in order:
            if not first:
                out.append("")
            first = False
            out.append(heading)
            out.extend(sections[heading])
        tasks_path.write_text("\n".join(out).rstrip() + "\n")

session_state_path = Path(sys.argv[1]) / "methodology" / "SESSION_STATE.md"
if not session_state_path.exists():
    session_state_path = target / "SESSION_STATE.md"
compact_markdown_file(session_state_path, {
    "## Touched Files": 8,
    "## Current Status": 5,
    "## Verification Status": 5,
    "## Blockers / Assumptions": 5,
}, MAX_SESSION_LINES)

handoff_path = Path(sys.argv[1]) / "methodology" / "HANDOFF.md"
if not handoff_path.exists():
    handoff_path = target / "HANDOFF.md"
compact_markdown_file(handoff_path, {
    "## Completed": 5,
    "## Verification Run": 8,
    "## Risks / Blockers": 5,
}, MAX_HANDOFF_LINES)

core_context_path = Path(sys.argv[1]) / "methodology" / "CORE_CONTEXT.md"
if not core_context_path.exists():
    core_context_path = target / "CORE_CONTEXT.md"
compact_markdown_file(core_context_path, {}, MAX_CORE_LINES)

work_index_path = Path(sys.argv[1]) / "methodology" / "WORK_INDEX.md"
if not work_index_path.exists():
    work_index_path = target / "WORK_INDEX.md"
compact_work_index(work_index_path)

work_dir = Path(sys.argv[1]) / "methodology" / "work"
if not work_dir.exists():
    work_dir = target / "work"
if work_dir.exists():
    for state_path in work_dir.glob("*/STATE.md"):
        compact_markdown_file(state_path, {
            "## Current Status": 5,
            "## Verification": 5,
            "## Blockers / Assumptions": 5,
            "## Progress Checkpoint": 12,
        }, MAX_TASK_STATE_LINES)
    for handoff_path in work_dir.glob("*/HANDOFF.md"):
        compact_markdown_file(handoff_path, {
            "## Completed": 5,
            "## Verification Run": 8,
            "## Risks / Blockers": 5,
            "## Progress Checkpoint": 10,
        }, MAX_TASK_HANDOFF_LINES)
PY

echo "Compacted hot-path methodology files for $target_dir"
