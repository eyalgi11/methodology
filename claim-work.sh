#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: claim-work.sh [options] [target-directory]

Creates, heartbeats, or releases a leased work claim.

Options:
  --agent TEXT
  --task TEXT
  --file PATH       May be repeated
  --notes TEXT
  --status TEXT     active, blocked, waiting, handed_off
  --lease-minutes N Default 60
  --claim-id TEXT   Update or release a specific claim
  --blocking-on TEXT
  --handoff-artifact PATH
  --commands-run TEXT
  --result-summary TEXT
  --known-risks TEXT
  --integration-notes TEXT
  --ready-for-merge yes|no
  --rebase-required yes|no|unknown
  --heartbeat       Refresh lease and heartbeat timestamps
  --release         Release the claim instead of creating/updating it
EOF
}

target_arg=""
agent=""
task=""
notes=""
claim_status="active"
lease_minutes=60
claim_id=""
blocking_on=""
handoff_artifact=""
commands_run="none recorded yet"
result_summary="pending"
known_risks="none recorded yet"
integration_notes="none recorded yet"
ready_for_merge="no"
rebase_required="unknown"
heartbeat=0
release=0
files=()

while (($# > 0)); do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    --task) task="$2"; shift 2 ;;
    --file) files+=("$2"); shift 2 ;;
    --notes) notes="$2"; shift 2 ;;
    --status) claim_status="$2"; shift 2 ;;
    --lease-minutes) lease_minutes="$2"; shift 2 ;;
    --claim-id) claim_id="$2"; shift 2 ;;
    --blocking-on) blocking_on="$2"; shift 2 ;;
    --handoff-artifact) handoff_artifact="$2"; shift 2 ;;
    --commands-run) commands_run="$2"; shift 2 ;;
    --result-summary) result_summary="$2"; shift 2 ;;
    --known-risks) known_risks="$2"; shift 2 ;;
    --integration-notes) integration_notes="$2"; shift 2 ;;
    --ready-for-merge) ready_for_merge="$2"; shift 2 ;;
    --rebase-required) rebase_required="$2"; shift 2 ;;
    --heartbeat) heartbeat=1; shift ;;
    --release) release=1; shift ;;
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
claims_index="$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")"
claims_dir="$(project_file_path "$target_dir" "claims")"
mkdir -p "$claims_dir"

if [[ "$claim_status" != "active" && "$claim_status" != "blocked" && "$claim_status" != "waiting" && "$claim_status" != "handed_off" ]]; then
  echo "Invalid --status: $claim_status" >&2
  exit 1
fi

if ! [[ "$lease_minutes" =~ ^[0-9]+$ ]] || (( lease_minutes <= 0 )); then
  echo "--lease-minutes must be a positive integer." >&2
  exit 1
fi
if [[ "$ready_for_merge" != "yes" && "$ready_for_merge" != "no" ]]; then
  echo "--ready-for-merge must be yes or no." >&2
  exit 1
fi
if [[ "$rebase_required" != "yes" && "$rebase_required" != "no" && "$rebase_required" != "unknown" ]]; then
  echo "--rebase-required must be yes, no, or unknown." >&2
  exit 1
fi

branch="$(current_git_branch "$target_dir")"
based_on_commit="$(git -C "$target_dir" rev-parse --short HEAD 2>/dev/null || printf 'n/a')"
claim_id="${claim_id:-claim-$(today_date)-$(slugify "${agent:-agent}-${task:-task}")}"
claim_file="$claims_dir/${claim_id}.md"
claim_json_file="$claims_dir/${claim_id}.json"
lease_expires_at="$(date -d "+${lease_minutes} minutes" '+%Y-%m-%d %H:%M:%S')"
handoff_artifact="${handoff_artifact:-$(if [[ -n "$task" ]]; then display_project_relpath "$target_dir" "$(task_handoff_relpath "$task")"; else printf 'n/a'; fi)}"

if (( release == 1 )); then
  if [[ -z "$claim_id" ]]; then
    echo "--release requires --claim-id." >&2
    exit 1
  fi
  python3 - "$claims_index" "$claim_file" "$claim_json_file" "$claim_id" "$(timestamp_now)" <<'PY'
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
claim_file = Path(sys.argv[2])
claim_json = Path(sys.argv[3])
claim_id = sys.argv[4]
released_at = sys.argv[5]

if claim_file.exists():
    lines = claim_file.read_text().splitlines()
    out = []
    status_seen = False
    released_seen = False
    for line in lines:
        if line.startswith("- Status:"):
            out.append("- Status: released")
            status_seen = True
        elif line.startswith("- Released at:"):
            out.append(f"- Released at: {released_at}")
            released_seen = True
        else:
            out.append(line)
    if not status_seen:
        out.append("- Status: released")
    if not released_seen:
        out.append(f"- Released at: {released_at}")
    claim_file.write_text("\n".join(out).rstrip() + "\n")

if claim_json.exists():
    import json
    data = json.loads(claim_json.read_text())
    data["status"] = "released"
    data["released_at"] = released_at
    claim_json.write_text(json.dumps(data, indent=2) + "\n")

if index_path.exists():
    lines = index_path.read_text().splitlines()
    out = []
    block = []
    in_block = False
    def is_target(buf):
        return any(line.strip() == f"- Claim ID: {claim_id}" for line in buf)
    for line in lines:
        if line.startswith("## Claim "):
            if in_block and not is_target(block):
                out.extend(block)
            block = [line]
            in_block = True
            continue
        if in_block and (line.startswith("- ") or line.startswith("  ") or not line.strip()):
            block.append(line)
            continue
        if in_block:
            if not is_target(block):
                out.extend(block)
            block = []
            in_block = False
        out.append(line)
    if in_block and not is_target(block):
        out.extend(block)
    index_path.write_text("\n".join(out).rstrip() + "\n")
PY
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
  echo "Released claim: $claim_id"
  exit 0
fi

if (( heartbeat == 1 )); then
  if [[ -z "$claim_id" ]]; then
    echo "--heartbeat requires --claim-id." >&2
    exit 1
  fi
  python3 - "$claims_index" "$claim_file" "$claim_json_file" "$claim_id" "$(timestamp_now)" "$lease_expires_at" <<'PY'
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
claim_file = Path(sys.argv[2])
claim_json = Path(sys.argv[3])
claim_id = sys.argv[4]
heartbeat_at = sys.argv[5]
lease_expires_at = sys.argv[6]

for path in (claim_file, index_path):
    if not path.exists():
        continue
    lines = path.read_text().splitlines()
    out = []
    if path == index_path:
        block = []
        in_block = False
        def is_target(buf):
            return any(line.strip() == f"- Claim ID: {claim_id}" for line in buf)
        def rewrite(buf):
            out_block = []
            for line in buf:
                if line.startswith("- Last heartbeat at:"):
                    out_block.append(f"- Last heartbeat at: {heartbeat_at}")
                elif line.startswith("- Lease expires at:"):
                    out_block.append(f"- Lease expires at: {lease_expires_at}")
                else:
                    out_block.append(line)
            return out_block
        for line in lines:
            if line.startswith("## Claim "):
                if in_block:
                    out.extend(rewrite(block) if is_target(block) else block)
                block = [line]
                in_block = True
                continue
            if in_block and (line.startswith("- ") or line.startswith("  ") or not line.strip()):
                block.append(line)
                continue
            if in_block:
                out.extend(rewrite(block) if is_target(block) else block)
                block = []
                in_block = False
            out.append(line)
        if in_block:
            out.extend(rewrite(block) if is_target(block) else block)
        path.write_text("\n".join(out).rstrip() + "\n")
        continue

    for line in lines:
        if line.startswith("- Last heartbeat at:"):
            out.append(f"- Last heartbeat at: {heartbeat_at}")
        elif line.startswith("- Lease expires at:"):
            out.append(f"- Lease expires at: {lease_expires_at}")
        else:
            out.append(line)
    path.write_text("\n".join(out).rstrip() + "\n")

if claim_json.exists():
    import json
    data = json.loads(claim_json.read_text())
    data["last_heartbeat_at"] = heartbeat_at
    data["lease_expires_at"] = lease_expires_at
    claim_json.write_text(json.dumps(data, indent=2) + "\n")
PY
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
  echo "Heartbeat recorded for claim: $claim_id"
  exit 0
fi

if [[ -z "$agent" || -z "$task" ]]; then
  echo "--agent and --task are required when creating a claim." >&2
  exit 1
fi

python3 - "$claims_index" "$claim_file" "$claim_id" "$agent" "$task" "$claim_status" "$(timestamp_now)" "$lease_expires_at" "$branch" "$based_on_commit" "$blocking_on" "$handoff_artifact" "$notes" "$commands_run" "$result_summary" "$known_risks" "$integration_notes" "$ready_for_merge" "$rebase_required" <<'PY'
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
claim_file = Path(sys.argv[2])
claim_id = sys.argv[3]
agent = sys.argv[4]
task = sys.argv[5]
status = sys.argv[6]
claimed_at = sys.argv[7]
lease_expires_at = sys.argv[8]
branch = sys.argv[9]
based_on_commit = sys.argv[10]
blocking_on = sys.argv[11]
handoff_artifact = sys.argv[12]
notes = sys.argv[13]
commands_run = sys.argv[14]
result_summary = sys.argv[15]
known_risks = sys.argv[16]
integration_notes = sys.argv[17]
ready_for_merge = sys.argv[18]
rebase_required = sys.argv[19]

if index_path.exists():
    text = index_path.read_text()
else:
    text = "# Active Claims\n\n## Parallel Work Rules\n- Pair this file with `MULTI_AGENT_PLAN.md` when the repo is actively using multiple agents.\n- Claims are live indexes only; detailed claim records live under `methodology/claims/`.\n- Claims require a lease, heartbeat, and takeover rule.\n\n## Active Claims\n\n"

lines = text.splitlines()
out = []
buffer = []
in_block = False

def match_claim(block):
    return any(line.strip() == f"- Claim ID: {claim_id}" for line in block)

def emit_block():
    block = [
        f"## Claim {claim_id}",
        f"- Claim ID: {claim_id}",
        f"- Status: {status}",
        f"- Claimed at: {claimed_at}",
        f"- Last heartbeat at: {claimed_at}",
        f"- Lease expires at: {lease_expires_at}",
        f"- Agent: {agent or 'unassigned'}",
        f"- Task: {task or 'unassigned'}",
        f"- Branch: {branch}",
        f"- Based on commit: {based_on_commit}",
        f"- Handoff artifact: {handoff_artifact or 'n/a'}",
        f"- Claim file: {claim_file.name}",
        f"- Ready for merge: {ready_for_merge}",
        f"- Rebase required: {rebase_required}",
        "- Takeover rule: another agent may take over if the lease expires and the claim file has no fresh heartbeat.",
    ]
    if blocking_on:
      block.append(f"- Blocking on: {blocking_on}")
    if notes:
      block.append(f"- Notes: {notes}")
    if result_summary:
      block.append(f"- Result summary: {result_summary}")
    return block

for line in lines:
    if line.startswith("## Claim "):
        if in_block:
            out.extend(emit_block() if match_claim(buffer) else buffer)
        buffer = [line]
        in_block = True
        continue
    if in_block and (line.startswith("- ") or line.startswith("  ") or not line.strip()):
        buffer.append(line)
        continue
    if in_block:
        out.extend(emit_block() if match_claim(buffer) else buffer)
        buffer = []
        in_block = False
    out.append(line)

if in_block:
    out.extend(emit_block() if match_claim(buffer) else buffer)

if not any(line.strip() == f"- Claim ID: {claim_id}" for line in out):
    if out and out[-1] != "":
        out.append("")
    if "## Active Claims" not in out:
        out.extend(["## Active Claims", ""])
    out.extend(emit_block())

index_path.write_text("\n".join(out).rstrip() + "\n")
PY

cat > "$claim_file" <<EOF
# Claim ${claim_id}

- Claim ID: ${claim_id}
- Status: ${claim_status}
- Claimed at: $(timestamp_now)
- Last heartbeat at: $(timestamp_now)
- Lease expires at: ${lease_expires_at}
- Agent: ${agent}
- Task: ${task}
- Branch: ${branch}
- Based on commit: ${based_on_commit}
- Handoff artifact: ${handoff_artifact}
$(if [[ -n "$blocking_on" ]]; then printf '%s\n' "- Blocking on: ${blocking_on}"; fi)$(if [[ -n "$notes" ]]; then printf '%s\n' "- Notes: ${notes}"; fi)
- Ready for merge: ${ready_for_merge}
- Rebase required: ${rebase_required}
- Takeover rule: another agent may take over if the lease expires and no heartbeat has refreshed the claim.

## Worker Delivery Contract
- Exact files changed: $(if (( ${#files[@]} > 0 )); then printf '%s' "$(printf '%s, ' "${files[@]}" | sed 's/, $//')"; else printf 'none recorded yet'; fi)
- Commands run: ${commands_run}
- Result summary: ${result_summary}
- Known risks: ${known_risks}
- Integration notes: ${integration_notes}
- Ready for merge: ${ready_for_merge}
- Rebase required: ${rebase_required}

## Files
$(if (( ${#files[@]} > 0 )); then printf -- '- %s\n' "${files[@]}"; else printf '%s\n' '- none recorded'; fi)
EOF

python3 - "$claim_json_file" "$claim_id" "$claim_status" "$(timestamp_now)" "$lease_expires_at" "$agent" "$task" "$branch" "$based_on_commit" "$blocking_on" "$handoff_artifact" "$notes" "$commands_run" "$result_summary" "$known_risks" "$integration_notes" "$ready_for_merge" "$rebase_required" "${files[@]}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = {
    "schema_version": "2026-03-21.1",
    "generator_version": "methodology-toolkit-2026-03-21.1",
    "claim_id": sys.argv[2],
    "status": sys.argv[3],
    "claimed_at": sys.argv[4],
    "last_heartbeat_at": sys.argv[4],
    "lease_expires_at": sys.argv[5],
    "agent": sys.argv[6],
    "task": sys.argv[7],
    "branch": sys.argv[8],
    "based_on_commit": sys.argv[9],
    "blocking_on": sys.argv[10],
    "handoff_artifact": sys.argv[11],
    "notes": sys.argv[12],
    "commands_run": sys.argv[13],
    "result_summary": sys.argv[14],
    "known_risks": sys.argv[15],
    "integration_notes": sys.argv[16],
    "ready_for_merge": sys.argv[17] == "yes",
    "rebase_required": sys.argv[18],
    "files": [item for item in sys.argv[19:] if item],
}
path.write_text(json.dumps(data, indent=2) + "\n")
PY

if [[ -n "$task" ]]; then
  ensure_task_workspace "$target_dir" "$task" "$claim_status"
  state_hint="$(task_workspace_current_state "$target_dir" "$task")"
  state_hint="${state_hint:-$claim_status}"
  update_work_index_entry "$target_dir" "$task" "$state_hint" "$(display_project_relpath "$target_dir" "claims/${claim_file##*/}")"
fi

"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
echo "Claimed work for $agent: $task ($claim_id)"
