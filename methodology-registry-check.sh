#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: methodology-registry-check.sh [--json] [source-directory]

Checks that every .sh/.md/.json artifact in the methodology source directory is
listed exactly once in METHODOLOGY_REGISTRY.md and that all registry states are valid.
EOF
}

json_mode=0
target_arg=""

while (($# > 0)); do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$target_arg" ]]; then
        echo "Only one source directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="${target_arg:-$SCRIPT_DIR}"
target_dir="$(cd "$target_dir" && pwd)"
registry_file="$target_dir/METHODOLOGY_REGISTRY.md"

if [[ ! -f "$registry_file" ]]; then
  echo "Registry file not found: $registry_file" >&2
  exit 1
fi

python3 - "$target_dir" "$registry_file" "$json_mode" <<'PY'
import json
import re
import sys
from collections import Counter
from pathlib import Path

target_dir = Path(sys.argv[1])
registry_file = Path(sys.argv[2])
json_mode = sys.argv[3] == "1"

allowed_states = {
    "core",
    "conditional",
    "manual",
    "experimental",
    "deprecated",
    "template-only",
}

table_row = re.compile(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|\s*(.*?)\s*\|$")

registry_entries = {}
duplicate_entries = []
invalid_states = []
state_counts = Counter()

for line in registry_file.read_text().splitlines():
    match = table_row.match(line.strip())
    if not match:
      continue
    artifact = match.group(1).strip()
    kind = match.group(2).strip()
    state = match.group(3).strip()
    trigger = match.group(4).strip()
    if artifact in registry_entries:
        duplicate_entries.append(artifact)
        continue
    registry_entries[artifact] = {
        "kind": kind,
        "state": state,
        "trigger": trigger,
    }
    state_counts[state] += 1
    if state not in allowed_states:
        invalid_states.append({"artifact": artifact, "state": state})

actual_artifacts = []
for path in sorted(target_dir.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(target_dir).as_posix()
    if rel.startswith(".git/"):
        continue
    if path.suffix not in {".sh", ".md", ".json"}:
        continue
    actual_artifacts.append(rel)

actual_set = set(actual_artifacts)
registry_set = set(registry_entries)

missing_from_registry = sorted(actual_set - registry_set)
unknown_in_registry = sorted(registry_set - actual_set)

ok = not missing_from_registry and not unknown_in_registry and not duplicate_entries and not invalid_states

summary = {
    "target": str(target_dir),
    "ok": ok,
    "counts": dict(sorted(state_counts.items())),
    "missing_from_registry": missing_from_registry,
    "unknown_in_registry": unknown_in_registry,
    "duplicate_entries": sorted(set(duplicate_entries)),
    "invalid_states": invalid_states,
}

if json_mode:
    print(json.dumps(summary, indent=2, sort_keys=True))
else:
    if ok:
        print(f"Registry check passed for {target_dir}")
        if state_counts:
            counts = ", ".join(f"{state}={count}" for state, count in sorted(state_counts.items()))
            print(f"State counts: {counts}")
    else:
        print(f"Registry issues found in {target_dir}")
        if missing_from_registry:
            print("\nMissing from registry:")
            for item in missing_from_registry:
                print(f"  - {item}")
        if unknown_in_registry:
            print("\nRegistry entries without matching artifact:")
            for item in unknown_in_registry:
                print(f"  - {item}")
        if duplicate_entries:
            print("\nDuplicate registry entries:")
            for item in sorted(set(duplicate_entries)):
                print(f"  - {item}")
        if invalid_states:
            print("\nInvalid registry states:")
            for item in invalid_states:
                print(f"  - {item['artifact']}: {item['state']}")
        if state_counts:
            counts = ", ".join(f"{state}={count}" for state, count in sorted(state_counts.items()))
            print(f"\nState counts: {counts}")

sys.exit(0 if ok else 1)
PY
