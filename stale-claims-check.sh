#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: stale-claims-check.sh [--json] [target-directory]

Reports active claims with expired leases.
EOF
}

target_arg=""
json_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
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
claims_dir="$(project_file_path "$target_dir" "claims")"

stale_json="$(python3 - "$claims_dir" "$(timestamp_now)" <<'PY'
import datetime as dt
import json
import sys
from pathlib import Path

claims_dir = Path(sys.argv[1])
now = dt.datetime.strptime(sys.argv[2], "%Y-%m-%d %H:%M:%S")
stale = []
if claims_dir.exists():
    for claim_file in sorted(claims_dir.glob("*.md")):
        status = ""
        lease_expires = ""
        claim_id = claim_file.stem
        for line in claim_file.read_text().splitlines():
            if line.startswith("- Claim ID:"):
                claim_id = line.split(":", 1)[1].strip()
            elif line.startswith("- Status:"):
                status = line.split(":", 1)[1].strip()
            elif line.startswith("- Lease expires at:"):
                lease_expires = line.split(":", 1)[1].strip()
        if status != "active":
            continue
        try:
            lease_dt = dt.datetime.strptime(lease_expires, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            stale.append({"claim_id": claim_id, "reason": "invalid lease timestamp"})
            continue
        if lease_dt < now:
            stale.append({"claim_id": claim_id, "reason": f"expired at {lease_expires}"})
print(json.dumps(stale))
PY
)"

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$(python3 -c 'import json,sys; print("true" if len(json.loads(sys.stdin.read()))==0 else "false")' <<<"$stale_json")"
  printf '"stale_claims":%s' "$stale_json"
  printf '}\n'
else
  if python3 -c 'import json,sys; raise SystemExit(0 if len(json.loads(sys.stdin.read())) == 0 else 1)' <<<"$stale_json"; then
    echo "No stale claims detected."
  else
    echo "Stale claims detected in $target_dir"
    python3 -c 'import json,sys; data=json.loads(sys.stdin.read()); [print(f"  - {item['"'"'claim_id'"'"']}: {item['"'"'reason'"'"']}") for item in data]' <<<"$stale_json"
  fi
fi

python3 -c 'import json,sys; raise SystemExit(0 if len(json.loads(sys.stdin.read())) == 0 else 1)' <<<"$stale_json"
