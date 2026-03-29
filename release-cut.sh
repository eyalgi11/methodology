#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: release-cut.sh [--version VERSION] [target-directory]

Generates a release-candidate summary from repo state and writes it to
RELEASE_NOTES.md and PROJECT_HEALTH.md.
EOF
}

target_arg=""
version_label=""
while (($# > 0)); do
  case "$1" in
    --version) version_label="$2"; shift 2 ;;
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
release_notes_file="$(project_file_path "$target_dir" "RELEASE_NOTES.md")"
project_health_file="$(project_file_path "$target_dir" "PROJECT_HEALTH.md")"
state_file="$(project_file_path "$target_dir" "methodology-state.json")"
version_label="${version_label:-rc-$(today_date)}"
branch="$(current_git_branch "$target_dir")"
mapfile -t recent_files < <(recent_work_files "$target_dir" 10)

business_owner="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("business_owner",""))' "$state_file" 2>/dev/null || true)"
leading_metric="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("leading_metric",""))' "$state_file" 2>/dev/null || true)"
customer_signal="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("customer_signal",""))' "$state_file" 2>/dev/null || true)"
decision_deadline="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("decision_deadline",""))' "$state_file" 2>/dev/null || true)"
active_risk_class="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_risk_class",""))' "$state_file" 2>/dev/null || true)"
active_release_risk="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_release_risk",""))' "$state_file" 2>/dev/null || true)"
active_task="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_task",""))' "$state_file" 2>/dev/null || true)"
active_spec="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("active_spec",""))' "$state_file" 2>/dev/null || true)"

git_summary=""
if has_git_repo "$target_dir"; then
  git_summary="$(git -C "$target_dir" log --oneline -n 5 2>/dev/null || true)"
fi

changed_files=""
if has_git_repo "$target_dir"; then
  changed_files="$(git -C "$target_dir" status --short 2>/dev/null || true)"
fi

summary_body=$(cat <<EOF
- Generated at: $(timestamp_now)
- Version label: ${version_label}
- Branch: ${branch}
- Active task: ${active_task:-n/a}
- Active spec: ${active_spec:-n/a}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Customer signal: ${customer_signal:-n/a}
- Decision deadline: ${decision_deadline:-n/a}
- Risk class: ${active_risk_class:-n/a}
- Release risk: ${active_release_risk:-n/a}
- Changed files:
$(if [[ -n "$changed_files" ]]; then printf '%s\n' "$changed_files" | sed 's/^/  - /'; elif ((${#recent_files[@]} > 0)); then printf '%s\n' "${recent_files[@]}" | sed 's/^/  - /'; else printf '  - none detected\n'; fi)
- Recent commits:
$(if [[ -n "$git_summary" ]]; then printf '%s\n' "$git_summary" | sed 's/^/  - /'; else printf '  - none available\n'; fi)
EOF
)
append_or_replace_auto_section "$release_notes_file" "release-cut" "## Release Candidate ${version_label}" "$summary_body"

health_body=$(cat <<EOF
- Updated at: $(timestamp_now)
- Release candidate: ${version_label}
- Branch: ${branch}
- Business owner: ${business_owner:-n/a}
- Leading metric: ${leading_metric:-n/a}
- Risk class: ${active_risk_class:-n/a}
- Release risk: ${active_release_risk:-n/a}
- Changed files recorded: $(if [[ -n "$changed_files" || ${#recent_files[@]} -gt 0 ]]; then printf 'yes'; else printf 'no'; fi)
EOF
)
append_or_replace_auto_section "$project_health_file" "release-cut" "## Release Readiness" "$health_body"

echo "Prepared release candidate summary: $version_label"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
