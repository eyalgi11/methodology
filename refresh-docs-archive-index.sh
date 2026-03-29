#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: refresh-docs-archive-index.sh [target-directory]

Rebuilds docs-archive-index.json from archived doc stubs and the archived files
they point to. This keeps archived-doc retrieval machine-readable and compact.
EOF
}

target_arg=""
while (($# > 0)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
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
index_path="$(project_file_path "$target_dir" "docs-archive-index.json")"
[[ -f "$index_path" ]] || cp "$SCRIPT_DIR/docs-archive-index.json" "$index_path"

python3 - "$target_dir" "$index_path" <<'PY'
import json
import re
import sys
from pathlib import Path

target = Path(sys.argv[1])
index_path = Path(sys.argv[2])

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")

def slug_tokens(value: str) -> list[str]:
    return [token for token in re.split(r"[^a-z0-9]+", value.lower()) if len(token) >= 3]

entries = []

for stub_path in sorted((target / "specs").glob("*.md")):
    stub_text = read_text(stub_path)
    match = re.search(r"<!-- COLD_DOC_STUB:\s*([^>]+)\s*-->", stub_text)
    if not match:
        continue

    archive_relpath = match.group(1).strip()
    archive_path = target / archive_relpath
    if not archive_path.exists():
        continue

    archive_text = read_text(archive_path)
    title = stub_path.stem.replace("_", " ")
    for line in archive_text.splitlines():
      if line.startswith("# "):
        title = line[2:].strip()
        break

    lines = archive_text.splitlines()
    headings = []
    for line in lines:
        if line.startswith("## "):
            headings.append(line[3:].strip())
        elif line.startswith("### "):
            headings.append(line[4:].strip())
        if len(headings) >= 12:
            break

    summary_lines = []
    seen_title = False
    for line in lines:
        if line.startswith("# "):
            if not seen_title:
                seen_title = True
                continue
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            continue
        if stripped.startswith("- "):
            continue
        summary_lines.append(stripped)
        if len(summary_lines) >= 4:
            break

    summary = " ".join(summary_lines[:3]).strip()
    if not summary:
        summary = "Archived spec/log document. Use the headings to choose whether to open the full archive."

    topics = []
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("- "):
            continue
        value = stripped[2:].strip().strip("`")
        if not value or len(value) > 80:
            continue
        topics.append(value)
        if len(topics) >= 20:
            break

    keywords = []
    for source in [title, stub_path.name, *headings[:12], *topics[:20], summary]:
        keywords.extend(slug_tokens(source))
    keywords = sorted(dict.fromkeys(keywords))

    entries.append({
        "title": title,
        "original_path": stub_path.relative_to(target).as_posix(),
        "archive_path": archive_relpath,
        "stub_path": stub_path.relative_to(target).as_posix(),
        "summary": summary[:280],
        "headings": headings[:12],
        "topics": topics[:20],
        "keywords": keywords[:40],
        "stub_size_bytes": stub_path.stat().st_size,
        "archive_size_bytes": archive_path.stat().st_size,
        "archive_updated_at": archive_path.stat().st_mtime,
    })

payload = {
    "updated_at": __import__("datetime").datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "entry_count": len(entries),
    "entries": entries,
}

index_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

echo "Refreshed docs archive index for $target_dir"
