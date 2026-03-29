#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: plan-task.sh --title "Task title" [options] [target-directory]

Creates a feature spec and seeds OPEN_QUESTIONS.md and RISK_REGISTER.md for the
planned task.

Options:
  --title TEXT
  --story TEXT
  --question TEXT    May be repeated
  --risk TEXT        May be repeated
EOF
}

target_arg=""
title=""
story=""
questions=()
risks=()

while (($# > 0)); do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --story) story="$2"; shift 2 ;;
    --question) questions+=("$2"); shift 2 ;;
    --risk) risks+=("$2"); shift 2 ;;
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

if [[ -z "$title" ]]; then
  echo "--title is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
open_questions_file="$(project_file_path "$target_dir" "OPEN_QUESTIONS.md")"
risk_register_file="$(project_file_path "$target_dir" "RISK_REGISTER.md")"
session_state_file="$(project_file_path "$target_dir" "SESSION_STATE.md")"
new_feature_args=(--json --title "$title")
if [[ -n "$story" ]]; then
  new_feature_args+=(--story "$story")
fi
feature_json="$("$SCRIPT_DIR/new-feature.sh" "${new_feature_args[@]}" "$target_dir")"
spec_relpath="$(printf '%s' "$feature_json" | grep -o '"spec":"[^"]*"' | cut -d'"' -f4)"

if (( ${#questions[@]} == 0 )); then
  questions+=("What is the main product decision still unresolved for ${title}?")
fi
if (( ${#risks[@]} == 0 )); then
  risks+=("Scope or implementation risk for ${title} is not yet recorded.")
fi

{
  printf '\n## Planned Task - %s\n' "$title"
  printf -- '- Spec: %s\n' "$spec_relpath"
  printf -- '- Decision Needed:\n'
  printf '%s\n' "${questions[@]}" | sed 's/^/- /'
} >> "$open_questions_file"

{
  printf '\n## Planned Task - %s\n' "$title"
  for risk_text in "${risks[@]}"; do
    printf -- '- Risk: %s\n' "$risk_text"
    printf '  Severity: medium\n'
    printf '  Mitigation: define mitigation during implementation planning\n'
    printf '  Owner: unassigned\n'
    printf '  Status: open\n'
  done
} >> "$risk_register_file"

plan_body=$(cat <<EOF
- Planned at: $(timestamp_now)
- Title: ${title}
- Spec: ${spec_relpath}
- Open questions added: ${#questions[@]}
- Risks added: ${#risks[@]}
EOF
)
append_or_replace_auto_section "$session_state_file" "planned-task" "## Planned Task" "$plan_body"

echo "Planned task: $title"
echo "Spec: $spec_relpath"
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
