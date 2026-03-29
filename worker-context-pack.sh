#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: worker-context-pack.sh --claim-id CLAIM_ID [--output FILE] [--max-lines N] [target-directory]

Builds a worker-specific context pack from the claim, task workspace, spec, and commands.
EOF
}

target_arg=""
claim_id=""
output_file=""
max_lines=60

while (($# > 0)); do
  case "$1" in
    --claim-id) claim_id="$2"; shift 2 ;;
    --output) output_file="$2"; shift 2 ;;
    --max-lines) max_lines="$2"; shift 2 ;;
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

if [[ -z "$claim_id" ]]; then
  echo "--claim-id is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
claim_json="$(project_file_path "$target_dir" "claims/${claim_id}.json")"
claim_md="$(project_file_path "$target_dir" "claims/${claim_id}.md")"
if [[ ! -f "$claim_json" && ! -f "$claim_md" ]]; then
  echo "Claim not found: $claim_id" >&2
  exit 1
fi

if [[ -f "$claim_json" ]]; then
  claim_task="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("task",""))' "$claim_json" 2>/dev/null || true)"
  claim_agent="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("agent",""))' "$claim_json" 2>/dev/null || true)"
  claim_status="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("status",""))' "$claim_json" 2>/dev/null || true)"
  claim_branch="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("branch",""))' "$claim_json" 2>/dev/null || true)"
  handoff_artifact="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("handoff_artifact",""))' "$claim_json" 2>/dev/null || true)"
  lease_expires_at="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("lease_expires_at",""))' "$claim_json" 2>/dev/null || true)"
  last_heartbeat_at="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()); print(data.get("last_heartbeat_at",""))' "$claim_json" 2>/dev/null || true)"
else
  claim_task="$(awk -F': ' '/^- Task:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  claim_agent="$(awk -F': ' '/^- Agent:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  claim_status="$(awk -F': ' '/^- Status:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  claim_branch="$(awk -F': ' '/^- Branch:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  handoff_artifact="$(awk -F': ' '/^- Handoff artifact:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  lease_expires_at="$(awk -F': ' '/^- Lease expires at:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
  last_heartbeat_at="$(awk -F': ' '/^- Last heartbeat at:/{print $2; exit}' "$claim_md" 2>/dev/null || true)"
fi

state_file="$(project_file_path "$target_dir" "methodology-state.json")"
work_type="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("work_type","product"))' "$state_file" 2>/dev/null || printf 'product')"
recommended_profile="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("recommended_startup_profile","normal"))' "$state_file" 2>/dev/null || printf 'normal')"
state_risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class","n/a"))' "$state_file" 2>/dev/null || printf 'n/a')"
state_release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk","n/a"))' "$state_file" 2>/dev/null || printf 'n/a')"
state_active_spec="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_spec",""))' "$state_file" 2>/dev/null || true)"
state_risk_class="$(trim_whitespace "$state_risk_class")"
state_release_risk="$(trim_whitespace "$state_release_risk")"
state_risk_class="${state_risk_class//\`/}"
state_release_risk="${state_release_risk//\`/}"
if is_placeholder_value "$state_risk_class" || [[ "$state_risk_class" == "R0 / R1 / R2 / R3" || -z "$state_risk_class" ]]; then
  state_risk_class="n/a"
fi
if is_placeholder_value "$state_release_risk" || [[ "$state_release_risk" == "low / medium / high" || -z "$state_release_risk" ]]; then
  state_release_risk="n/a"
fi
verification_path="$(awk -F': ' '/- Verification path:/{value=$2} END{print value}' "$(project_file_path "$target_dir" "SESSION_STATE.md")" 2>/dev/null || true)"
verification_path="$(trim_whitespace "$verification_path")"
if is_placeholder_value "$verification_path" || [[ -z "$verification_path" ]]; then
  verification_path="n/a"
fi

task_record="$(effective_task_record "$target_dir")"
active_spec="$(python3 - "$target_dir" "$task_record" "$claim_task" "$state_active_spec" <<'PY'
import json
import re
import sys
from pathlib import Path

target_dir = Path(sys.argv[1])
task_record = json.loads(sys.argv[2]) if sys.argv[2].strip() else {}
claim_task = sys.argv[3].strip()
fallback_spec = sys.argv[4].strip()

spec = ""
if claim_task and task_record.get("task") == claim_task and task_record.get("spec"):
    spec = task_record["spec"]
else:
    tasks_file = target_dir / "methodology" / "TASKS.md"
    if not tasks_file.exists():
        tasks_file = target_dir / "TASKS.md"
    if tasks_file.exists() and claim_task:
        pattern = re.compile(r"^- (?:(?:\[[ xX]\]) )?(.+)$")
        for line in tasks_file.read_text().splitlines():
            match = pattern.match(line)
            if not match:
                continue
            body = match.group(1).strip()
            display = re.sub(r"\s+\(`?(?:specs|features)/[^`)\n]+\.md`?\)$", "", body).strip()
            if display != claim_task:
                continue
            spec_match = re.search(r"\(`?((?:specs|features)/[^`)\n]+\.md)`?\)", body)
            spec = spec_match.group(1) if spec_match else ""
            break

if not spec:
    spec = fallback_spec
print(spec)
PY
)"
if [[ -n "$claim_task" ]]; then
  ensure_task_workspace "$target_dir" "$claim_task" "$(task_workspace_current_state "$target_dir" "$claim_task")" "$active_spec"
fi

emit_pack() {
  printf '# Worker Context Pack\n\n'
  printf -- '- Generated: %s\n' "$(timestamp_now)"
  printf -- '- Target: %s\n' "$target_dir"
  printf -- '- Claim ID: %s\n' "$claim_id"
  printf -- '- Agent: %s\n' "${claim_agent:-n/a}"
  printf -- '- Task: %s\n' "${claim_task:-n/a}"
  printf -- '- Work type: %s\n' "${work_type:-product}"
  printf -- '- Recommended startup profile: %s\n' "${recommended_profile:-normal}"
  printf -- '- Status: %s\n' "${claim_status:-n/a}"
  printf -- '- Branch: %s\n\n' "${claim_branch:-n/a}"

  printf '## Safety-Critical Summary\n\n'
  printf -- '- Verification path: %s\n' "${verification_path:-n/a}"
  printf -- '- Risk class: %s\n' "${state_risk_class:-n/a}"
  printf -- '- Release risk: %s\n' "${state_release_risk:-n/a}"
  printf -- '- Lease expires at: %s\n' "${lease_expires_at:-n/a}"
  printf -- '- Last heartbeat at: %s\n\n' "${last_heartbeat_at:-n/a}"

  if [[ -f "$claim_json" ]]; then
    printf '## %s\n\n```json\n' "$(display_project_relpath "$target_dir" "claims/${claim_id}.json")"
    sed -n "1,${max_lines}p" "$claim_json"
    printf '\n```\n\n'
  fi

  if [[ -f "$claim_md" ]]; then
    printf '## %s\n\n```md\n' "$(display_project_relpath "$target_dir" "claims/${claim_id}.md")"
    sed -n "1,${max_lines}p" "$claim_md"
    printf '\n```\n\n'
  fi

  if [[ -n "$claim_task" ]]; then
    for relpath in "$(task_state_relpath "$claim_task")" "$(task_handoff_relpath "$claim_task")" "COMMANDS.md"; do
      doc_path="$(project_file_path "$target_dir" "$relpath")"
      [[ -f "$doc_path" ]] || continue
      printf '## %s\n\n```md\n' "$(display_project_relpath "$target_dir" "$relpath")"
      sed -n "1,${max_lines}p" "$doc_path"
      printf '\n```\n\n'
    done
  fi

  if [[ -n "$active_spec" && "$active_spec" != "n/a" ]]; then
    spec_path="$(project_file_path "$target_dir" "$active_spec")"
    if [[ -f "$spec_path" ]]; then
      printf '## %s\n\n```md\n' "$(display_project_relpath "$target_dir" "$active_spec")"
      sed -n "1,${max_lines}p" "$spec_path"
      printf '\n```\n\n'
    fi
  fi

  if [[ -n "$handoff_artifact" && "$handoff_artifact" != "n/a" ]]; then
    artifact_path="$(project_file_path "$target_dir" "$handoff_artifact")"
    if [[ -f "$artifact_path" ]]; then
      printf '## %s\n\n```md\n' "$(display_project_relpath "$target_dir" "$handoff_artifact")"
      sed -n "1,${max_lines}p" "$artifact_path"
      printf '\n```\n\n'
    fi
  fi
}

if [[ -n "$output_file" ]]; then
  emit_pack > "$output_file"
  echo "Worker context pack written to $output_file"
else
  emit_pack
fi
