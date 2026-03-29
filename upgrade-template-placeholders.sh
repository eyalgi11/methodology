#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: upgrade-template-placeholders.sh [target-directory]

Refreshes known untouched older methodology placeholder files to the latest
template version without overwriting user-customized project files.
EOF
}

target_arg=""

while (($# > 0)); do
  case "$1" in
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
        echo "Only one target directory may be provided." >&2
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"

upgrade_if_matches_legacy() {
  local relative_path="$1"
  local template_path="$2"
  local legacy_content="$3"
  local project_path
  project_path="$(project_file_path "$target_dir" "$relative_path")"

  [[ -f "$project_path" ]] || return 0

  local current_content
  current_content="$(cat "$project_path")"

  if [[ "$current_content" == "$legacy_content" ]]; then
    cp "$template_path" "$project_path"
    echo "upgrade $project_path"
  fi
}

legacy_manual_checks_content=$(cat <<'EOF'
# Manual Checks

Use this file when a human can verify behavior directly in a web page, app, or other UI.

## Current Ready-To-Check Item
- Scope:
- Why manual review matters:
- Status:

## How To Open It
- URL / app / screen:
- Startup command:
- Login or test account:
- Test data / seed data:

## What To Check
1. 
2. 
3. 

## Expected Result
- 

## What To Report Back
- Bugs:
- UX issues:
- Confusing behavior:
- Pass / fail:
EOF
)

legacy_verification_log_content=$(cat <<'EOF'
# Verification Log

## Entry Template
- Date:
- Scope:
- Commands / checks run:
- Result:
- Known gaps:
EOF
)

legacy_incidents_content=$(cat <<'EOF'
# Incidents

## Incident Template
- Date:
- Summary:
- Impact:
- Root cause:
- Fix:
- Follow-up actions:
EOF
)

upgrade_if_matches_legacy \
  "MANUAL_CHECKS.md" \
  "$SCRIPT_DIR/MANUAL_CHECKS.md" \
  "$legacy_manual_checks_content"

upgrade_if_matches_legacy \
  "VERIFICATION_LOG.md" \
  "$SCRIPT_DIR/VERIFICATION_LOG.md" \
  "$legacy_verification_log_content"

upgrade_if_matches_legacy \
  "INCIDENTS.md" \
  "$SCRIPT_DIR/INCIDENTS.md" \
  "$legacy_incidents_content"

upgrade_feature_spec_template_if_legacy() {
  local project_template_path="$1"
  local source_template_path="$2"

  python3 - "$project_template_path" "$source_template_path" <<'PY'
import shutil
import sys
from pathlib import Path

project_path = Path(sys.argv[1])
template_path = Path(sys.argv[2])
if not project_path.exists():
    raise SystemExit(0)

text = project_path.read_text()
is_legacy = (
    text.startswith("# Feature Spec")
    and "## User Story" in text
    and "## Why Now" not in text
    and "## Release / Rollout" not in text
    and "## Post-Launch Review" not in text
)

if is_legacy:
    shutil.copyfile(template_path, project_path)
    print(f"upgrade {project_path}")
PY
}

upgrade_feature_spec_template_if_legacy \
  "$(project_file_path "$target_dir" "templates/FEATURE_SPEC_TEMPLATE.md")" \
  "$SCRIPT_DIR/templates/FEATURE_SPEC_TEMPLATE.md"

upgrade_feature_spec_template_if_legacy \
  "$(project_file_path "$target_dir" "specs/FEATURE_SPEC_TEMPLATE.md")" \
  "$SCRIPT_DIR/templates/FEATURE_SPEC_TEMPLATE.md"
