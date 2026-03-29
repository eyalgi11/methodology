#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: agent-merge-check.sh [--claim-id CLAIM_ID] [--json] [target-directory]

Checks whether current claimed work is ready for merge or handoff.

The check combines:
- stale claim detection
- changed-file ownership vs active claims
- claim merge metadata such as ready-for-merge and rebase-required
- latest verification status from methodology-state.json
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
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
verification_status="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("last_verification_result","unknown"))' "$state_file" 2>/dev/null || printf 'unknown')"

issues=()
stale_json='{"stale_claims":[]}'
diff_json='{"issues":[]}'

if ! stale_json="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null)"; then
  issues+=("Stale-claims check failed.")
else
  stale_count="$(printf '%s' "$stale_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("stale_claims", [])))' 2>/dev/null || printf '0')"
  if [[ "$stale_count" != "0" ]]; then
    issues+=("There are stale claims that must be resolved before merge or handoff.")
  fi
fi

diff_args=(--json)
if [[ -n "$claim_id" ]]; then
  diff_args+=(--claim-id "$claim_id")
fi
diff_args+=("$target_dir")
if ! diff_json="$("$SCRIPT_DIR/claim-diff-check.sh" "${diff_args[@]}" 2>/dev/null)"; then
  if [[ -n "$diff_json" ]]; then
    mapfile -t diff_issues < <(printf '%s' "$diff_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); [print(x) for x in data.get("issues", [])]' 2>/dev/null || true)
    if (( ${#diff_issues[@]} > 0 )); then
      issues+=("${diff_issues[@]}")
    else
      issues+=("Claim/diff ownership check failed.")
    fi
  else
    issues+=("Claim/diff ownership check failed.")
  fi
fi

claim_check_json="$(python3 - "$target_dir" "$claim_id" "$verification_status" "$stale_json" "$diff_json" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
claim_filter = sys.argv[2].strip()
verification_status = sys.argv[3].strip()
stale_payload = json.loads(sys.argv[4])
diff_payload = json.loads(sys.argv[5])
claims_dir = target / "methodology" / "claims"
if not claims_dir.exists():
    claims_dir = target / "claims"

claims = []
for path in sorted(claims_dir.glob("*.json")):
    data = json.loads(path.read_text())
    if claim_filter and data.get("claim_id") != claim_filter:
        continue
    if data.get("status") == "released":
        continue
    claims.append(data)

issues = []
if not claims:
    issues.append("No active claim records were found for merge or handoff.")

if stale_payload.get("stale_claims"):
    issues.append("Stale claims are still present.")

if diff_payload.get("issues"):
    issues.extend(diff_payload["issues"])

for claim in claims:
    cid = claim.get("claim_id", "unknown-claim")
    status = claim.get("status", "")
    if status in {"blocked", "waiting"}:
        issues.append(f"Claim {cid} is still {status}.")
    if not claim.get("ready_for_merge", False):
        issues.append(f"Claim {cid} is not marked ready for merge.")
    if claim.get("rebase_required") == "yes":
        issues.append(f"Claim {cid} still requires a rebase.")

if claims and verification_status.lower() != "passed":
    issues.append("Last verification result is not passed.")

print(json.dumps({
    "issues": list(dict.fromkeys(issues)),
    "claims_checked": [claim.get("claim_id", "") for claim in claims],
}))
PY
)"
mapfile -t claim_issues < <(printf '%s' "$claim_check_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); [print(x) for x in data.get("issues", [])]' 2>/dev/null || true)
if (( ${#claim_issues[@]} > 0 )); then
  issues+=("${claim_issues[@]}")
fi
mapfile -t claims_checked < <(printf '%s' "$claim_check_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); [print(x) for x in data.get("claims_checked", []) if x]' 2>/dev/null || true)

deduped_issues=()
if (( ${#issues[@]} > 0 )); then
  mapfile -t deduped_issues < <(printf '%s\n' "${issues[@]}" | awk '!seen[$0]++')
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"claim_id":"%s",' "$(json_escape "$claim_id")"
  printf '"verification_status":"%s",' "$(json_escape "$verification_status")"
  printf '"claims_checked":'
  print_json_array claims_checked
  printf ','
  printf '"ok":%s,' "$( (( ${#deduped_issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array deduped_issues
  printf '}\n'
else
  if (( ${#deduped_issues[@]} == 0 )); then
    echo "Agent merge check passed."
  else
    echo "Agent merge check failed for $target_dir"
    printf '  - %s\n' "${deduped_issues[@]}"
  fi
fi

if (( ${#deduped_issues[@]} == 0 )); then
  exit 0
fi
exit 1
