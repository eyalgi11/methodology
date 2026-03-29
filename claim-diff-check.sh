#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: claim-diff-check.sh [--claim-id CLAIM_ID] [--json] [target-directory]

Checks whether changed files match the claimed files recorded for active claims.
EOF
}

target_arg=""
claim_id=""
json_mode=0

while (($# > 0)); do
  case "$1" in
    --claim-id) claim_id="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
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

python3 - "$target_dir" "$claim_id" "$json_mode" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

target = Path(sys.argv[1])
claim_filter = sys.argv[2].strip()
json_mode = sys.argv[3] == "1"
claims_dir = target / "methodology" / "claims"
if not claims_dir.exists():
    claims_dir = target / "claims"

def parse_markdown_claim(path: Path):
    data = {
        "claim_id": path.stem,
        "status": "",
        "files": [],
    }
    in_files = False
    for line in path.read_text().splitlines():
        if line.startswith("- Claim ID:"):
            data["claim_id"] = line.split(":", 1)[1].strip()
        elif line.startswith("- Status:"):
            data["status"] = line.split(":", 1)[1].strip()
        elif line == "## Files":
            in_files = True
            continue
        elif line.startswith("## ") and in_files:
            in_files = False
        elif in_files and line.startswith("- "):
            value = line[2:].strip()
            if value and value != "none recorded":
                data["files"].append(value)
    return data

claims = []
seen_claim_ids = set()
for path in sorted(claims_dir.glob("*.json")):
    data = json.loads(path.read_text())
    if claim_filter and data.get("claim_id") != claim_filter:
        continue
    if data.get("status") == "released":
        continue
    claims.append(data)
    seen_claim_ids.add(data.get("claim_id", path.stem))

for path in sorted(claims_dir.glob("*.md")):
    data = parse_markdown_claim(path)
    if data["claim_id"] in seen_claim_ids:
        continue
    if claim_filter and data.get("claim_id") != claim_filter:
        continue
    if data.get("status") == "released":
        continue
    claims.append(data)

try:
    status_output = subprocess.check_output(
        ["git", "-C", str(target), "status", "--short"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
except Exception:
    status_output = ""

changed = []
ignored_patterns = [
    re.compile(r"^(?:methodology/)?ACTIVE_CLAIMS\.md$"),
    re.compile(r"^(?:methodology/)?WORK_INDEX\.md$"),
    re.compile(r"^(?:methodology/)?SESSION_STATE\.md$"),
    re.compile(r"^(?:methodology/)?HANDOFF\.md$"),
    re.compile(r"^(?:methodology/)?VERIFICATION_LOG\.md$"),
    re.compile(r"^(?:methodology/)?methodology-state\.json$"),
    re.compile(r"^(?:methodology/)?claims/[^/]+\.(?:md|json)$"),
]
for line in status_output.splitlines():
    if not line.strip():
        continue
    rel = line[3:].strip()
    if rel.endswith("/"):
        continue
    if "->" in rel:
        rel = rel.split("->", 1)[1].strip()
    if any(pattern.match(rel) for pattern in ignored_patterns):
        continue
    changed.append(rel)

claim_map = {}
for claim in claims:
    for rel in claim.get("files", []):
        claim_map.setdefault(rel, []).append(claim.get("claim_id"))

issues = []
for rel in changed:
    owners = claim_map.get(rel, [])
    if not owners:
        issues.append(f"Changed file is not covered by an active claim: {rel}")
    elif len(owners) > 1:
        issues.append(f"Changed file is claimed by multiple active claims: {rel} ({', '.join(owners)})")

for claim in claims:
    if claim.get("files") and not any(rel in changed for rel in claim.get("files", [])):
        issues.append(f"Claim {claim.get('claim_id')} owns files with no current diff; release or refresh the claim if work moved.")

payload = {
    "target": str(target),
    "claim_id": claim_filter or "",
    "ok": not issues,
    "issues": issues,
}

if json_mode:
    print(json.dumps(payload))
else:
    if issues:
        print(f"Claim/diff issues found in {target}")
        for item in issues:
            print(f"  - {item}")
    else:
        print("Claim/diff check passed.")

raise SystemExit(0 if not issues else 1)
PY
