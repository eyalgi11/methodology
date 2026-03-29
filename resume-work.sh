#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: resume-work.sh [--output FILE] [--json] [--profile PROFILE] [target-directory]

Runs the standard resume checks, writes a context pack, and refreshes an auto
resume section in SESSION_STATE.md.
EOF
}

target_arg=""
output_file=""
json_mode=0
profile="normal"

while (($# > 0)); do
  case "$1" in
    --output) output_file="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
    --profile) profile="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1" >&2
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

if [[ "$profile" != "minimal" && "$profile" != "normal" && "$profile" != "deep" ]]; then
  echo "--profile must be one of: minimal, normal, deep" >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
project_name="$(basename "$target_dir")"
context_file="${output_file:-/tmp/${project_name}-context.md}"

status_ok=true
if [[ -f "$SCRIPT_DIR/refresh-methodology-state.sh" ]]; then
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
fi
state_json="$(project_file_path "$target_dir" "methodology-state.json")"
dashboard_json="$("$SCRIPT_DIR/project-dashboard.sh" --json "$target_dir")"
if ! "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1; then
  status_ok=false
fi

branch="$(current_git_branch "$target_dir")"
next_step="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("next_step",""))' "$state_json" 2>/dev/null || true)"
next_step="${next_step:-$(best_next_step "$target_dir")}"
next_step="${next_step:-Review TASKS.md and pick the next concrete step.}"
active_task="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task",""))' "$state_json" 2>/dev/null || true)"
active_workspace="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_workspace_path",""))' "$state_json" 2>/dev/null || true)"
hotfix_status="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("hotfix_status","inactive"))' "$state_json" 2>/dev/null || true)"
stale_claim_count="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("stale_claims", [])))' 2>/dev/null || printf '0')"
handoff_regenerated="no"
if ! $status_ok; then
  "$SCRIPT_DIR/session-snapshot.sh" --next-step "$next_step" "$target_dir" >/dev/null 2>&1 || true
  handoff_regenerated="yes"
fi
if [[ "$hotfix_status" == "active" ]]; then
  next_step="Hotfix mode is active. Follow methodology/HOTFIX.md and stabilize runtime before roadmap work."
fi
resume_body=$(cat <<EOF
- Resumed at: $(timestamp_now)
- Branch: ${branch}
- Startup profile: ${profile}
- Continuity status: $(if $status_ok; then printf 'current'; else printf 'stale'; fi)
- Active task: ${active_task:-n/a}
- Active workspace: ${active_workspace:-n/a}
- Stale claims: ${stale_claim_count}
- Handoff regenerated: ${handoff_regenerated}
- Hotfix override: ${hotfix_status}
- Context pack: ${context_file}
- Suggested next step: ${next_step}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "resume-work" "## Resume Snapshot" "$resume_body"
append_or_replace_auto_section "$(project_file_path "$target_dir" "HANDOFF.md")" "recovery-checklist" "## Recovery Checklist" "$resume_body"
"$SCRIPT_DIR/refresh-core-context.sh" "$target_dir" >/dev/null
"$SCRIPT_DIR/compact-hot-docs.sh" "$target_dir" >/dev/null 2>&1 || true
"$SCRIPT_DIR/context-pack.sh" --profile "$profile" --output "$context_file" "$target_dir" >/dev/null
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"status_ok":%s,' "$( $status_ok && printf true || printf false )"
  printf '"profile":"%s",' "$(json_escape "$profile")"
  printf '"context_pack":"%s",' "$(json_escape "$context_file")"
  printf '"dashboard":%s' "$dashboard_json"
  printf '}\n'
else
  echo "Resume checks completed for $target_dir"
  echo "Startup profile: $profile"
  echo "Context pack: $context_file"
  echo "Suggested next step: $next_step"
  if ! $status_ok; then
    echo "Continuity status is stale; refresh the working docs before major changes."
  fi
fi
