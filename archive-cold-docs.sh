#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: archive-cold-docs.sh [options] [target-directory]

Archives oversized, inactive spec/log markdown files out of the active working
path. The full content is moved under archive/docs/, and the original path is
replaced with a short stub so existing references still resolve.

Options:
  --min-bytes N       Minimum file size to archive. Default: 12000
  --min-age-hours N   Minimum age in hours before a cold doc may be archived.
                      Default: 24
  --dry-run           Report what would be archived without modifying files
  -h, --help          Show this help text
EOF
}

target_arg=""
min_bytes=12000
min_age_hours=24
dry_run=0

while (($# > 0)); do
  case "$1" in
    --min-bytes) min_bytes="$2"; shift 2 ;;
    --min-age-hours) min_age_hours="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
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

if [[ ! "$min_bytes" =~ ^[0-9]+$ ]]; then
  echo "--min-bytes must be a non-negative integer." >&2
  exit 1
fi

if [[ ! "$min_age_hours" =~ ^[0-9]+$ ]]; then
  echo "--min-age-hours must be a non-negative integer." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
docs_archive_path="$(project_file_path "$target_dir" "DOCS_ARCHIVE.md")"
[[ -f "$docs_archive_path" ]] || cp "$SCRIPT_DIR/DOCS_ARCHIVE.md" "$docs_archive_path"

python3 - "$target_dir" "$docs_archive_path" "$min_bytes" "$min_age_hours" "$dry_run" <<'PY'
import re
import sys
import time
from pathlib import Path

target = Path(sys.argv[1])
docs_archive_path = Path(sys.argv[2])
min_bytes = int(sys.argv[3])
min_age_hours = int(sys.argv[4])
dry_run = int(sys.argv[5]) == 1
now = time.time()

archive_root = target / "archive" / "docs"
if not dry_run:
    archive_root.mkdir(parents=True, exist_ok=True)

def file_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")

def extract_active_specs() -> set[str]:
    specs: set[str] = set()
    patterns = [
        Path(sys.argv[1]) / "methodology" / "CORE_CONTEXT.md",
        Path(sys.argv[1]) / "methodology" / "SESSION_STATE.md",
        Path(sys.argv[1]) / "methodology" / "HANDOFF.md",
        Path(sys.argv[1]) / "methodology" / "TASKS.md",
        Path(sys.argv[1]) / "CORE_CONTEXT.md",
        Path(sys.argv[1]) / "SESSION_STATE.md",
        Path(sys.argv[1]) / "HANDOFF.md",
        Path(sys.argv[1]) / "TASKS.md",
    ]
    for path in patterns:
        if not path.exists():
            continue
        text = file_text(path)
        for match in re.findall(r"((?:specs|features)/[A-Za-z0-9._/\-]+\.md)", text):
            specs.add(match)
    return specs

def is_candidate(path: Path, relpath: str, active_specs: set[str]) -> bool:
    normalized_relpath = relpath
    if normalized_relpath.startswith("methodology/"):
        normalized_relpath = normalized_relpath[len("methodology/"):]
    if normalized_relpath in {"specs/FEATURE_SPEC_TEMPLATE.md", "templates/FEATURE_SPEC_TEMPLATE.md"}:
        return False
    if normalized_relpath in active_specs or relpath in active_specs:
        return False
    if not (relpath.startswith("specs/") or relpath.startswith("methodology/features/")):
        return False
    name = path.name.lower()
    if not any(token in name for token in ("spec", "plan", "log", "research", "qa")):
        return False
    text = file_text(path)
    if "<!-- COLD_DOC_STUB:" in text:
        return False
    stat = path.stat()
    if stat.st_size < min_bytes:
        return False
    age_hours = (now - stat.st_mtime) / 3600
    if age_hours < min_age_hours:
        return False
    return True

def extract_title(text: str, relpath: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return Path(relpath).stem.replace("_", " ")

def extract_headings(text: str) -> list[str]:
    headings: list[str] = []
    for line in text.splitlines():
        if line.startswith("## "):
            headings.append(line[3:].strip())
        elif line.startswith("### "):
            headings.append(line[4:].strip())
        if len(headings) >= 6:
            break
    return headings

def archive_destination(relpath: str) -> Path:
    dest = archive_root / relpath
    if not dest.exists():
        return dest
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(now))
    return dest.with_name(f"{dest.stem}.{stamp}{dest.suffix}")

active_specs = extract_active_specs()
candidates: list[tuple[str, Path]] = []

search_roots = [target / "specs", target / "methodology" / "features"]
for root in search_roots:
    if not root.exists():
        continue
    for path in sorted(root.glob("*.md")):
        relpath = path.relative_to(target).as_posix()
        if is_candidate(path, relpath, active_specs):
            candidates.append((relpath, path))

entries = []
for relpath, path in candidates:
    original = file_text(path)
    title = extract_title(original, relpath)
    headings = extract_headings(original)
    size_bytes = path.stat().st_size
    age_hours = int((now - path.stat().st_mtime) / 3600)
    archive_path = archive_destination(relpath)
    archive_relpath = archive_path.relative_to(target).as_posix()
    summary_lines = headings if headings else ["No section headings detected; open the full archive if needed."]

    stub_lines = [
        f"<!-- COLD_DOC_STUB: {archive_relpath} -->",
        f"# {title}",
        "",
        "> This cold spec/log doc was archived to keep the active working path lean.",
        "",
        "## Archive Metadata",
        f"- Original path: `{relpath}`",
        f"- Full archive: `{archive_relpath}`",
        f"- Archived at: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(now))}",
        f"- Archived because: inactive spec/log larger than {min_bytes} bytes and older than {min_age_hours} hours",
        f"- Size before archive: {size_bytes} bytes",
        f"- Age at archive time: about {age_hours} hours",
        "",
        "## Summary",
    ]
    for heading in summary_lines:
        stub_lines.append(f"- {heading}")
    stub_lines.extend([
        "",
        "## Restore Hint",
        f"- Open `{archive_relpath}` for the full original content.",
    ])
    stub_text = "\n".join(stub_lines).rstrip() + "\n"

    entry_lines = [
        f"## {time.strftime('%Y-%m-%d', time.localtime(now))} - `{relpath}`",
        f"- Full archive: `{archive_relpath}`",
        f"- Title: {title}",
        f"- Reason: inactive spec/log larger than {min_bytes} bytes and older than {min_age_hours} hours",
        f"- Size before archive: {size_bytes} bytes",
    ]

    if not dry_run:
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        archive_path.write_text(original, encoding="utf-8")
        path.write_text(stub_text, encoding="utf-8")

    entries.append("\n".join(entry_lines))

if entries and not dry_run:
    docs_text = file_text(docs_archive_path) if docs_archive_path.exists() else "# Docs Archive\n\n## Archived Documents\n"
    if "## Archived Documents" not in docs_text:
        docs_text = docs_text.rstrip() + "\n\n## Archived Documents\n"
    docs_archive_path.write_text(docs_text.rstrip() + "\n\n" + "\n\n".join(entries) + "\n", encoding="utf-8")

print(f"archived_count={len(entries)}")
for relpath, _ in candidates:
    print(f"archived={relpath}")
PY

if [[ -f "$SCRIPT_DIR/fix-project-perms.sh" ]]; then
  bash "$SCRIPT_DIR/fix-project-perms.sh" "$target_dir" >/dev/null 2>&1 || true
fi

"$SCRIPT_DIR/refresh-docs-archive-index.sh" "$target_dir" >/dev/null 2>&1 || true
