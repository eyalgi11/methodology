#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${1:-$SCRIPT_DIR}"
target_dir="$(cd "$target_dir" && pwd)"

python3 - "$target_dir" <<'PY'
from pathlib import Path
import re
import sys

target = Path(sys.argv[1])
issues = []
pattern = re.compile(r"/home/eyal|/root/")
allowed_comment = re.compile(r"^\s*#\s*shellcheck\s+source=")

for path in sorted(target.rglob("*.sh")):
    if ".git" in path.parts:
        continue
    if path.name == "portability-check.sh":
        continue
    rel = path.relative_to(target).as_posix()
    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        if allowed_comment.match(line):
            continue
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if pattern.search(line):
            issues.append(f"{rel}:{lineno}: machine-specific path: {line.strip()}")

if issues:
    print("Portability issues found:")
    for item in issues:
        print(f"  - {item}")
    raise SystemExit(1)

print(f"Portability check passed for {target}")
PY
