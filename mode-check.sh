#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: mode-check.sh [--json] [target-directory]

Checks whether project rigor matches the declared maturity mode.
EOF
}

target_arg=""
json_mode=0
light_mode=0
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --light) light_mode=1; shift ;;
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
verification_log_file="$(project_file_path "$target_dir" "VERIFICATION_LOG.md")"
mode="$(read_maturity_mode "$target_dir")"
work_type="$(read_work_type "$target_dir")"
issues=()

check_required_docs() {
  local missing_or_placeholder=()
  local relpath
  for relpath in "$@"; do
    if [[ ! -f "$(project_file_path "$target_dir" "$relpath")" ]]; then
      missing_or_placeholder+=("$relpath missing")
    elif is_placeholder_file "$target_dir" "$relpath"; then
      missing_or_placeholder+=("$relpath placeholder")
    fi
  done
  if (( ${#missing_or_placeholder[@]} > 0 )); then
    issues+=("Required docs for mode $mode are incomplete: $(printf '%s, ' "${missing_or_placeholder[@]}" | sed 's/, $//').")
  fi
}

if [[ "$mode" == "template_source" ]]; then
  if ! "$SCRIPT_DIR/methodology-registry-check.sh" "$target_dir" >/dev/null 2>&1; then
    issues+=("Template-source registry coverage is not valid.")
  fi
  if ! bash -n "$SCRIPT_DIR/bootstrap-methodology.sh" "$SCRIPT_DIR/methodology-entry.sh" "$SCRIPT_DIR/methodology-audit.sh" "$SCRIPT_DIR/adopt-methodology.sh" "$SCRIPT_DIR/work-preflight.sh" "$SCRIPT_DIR/worker-context-pack.sh" "$SCRIPT_DIR/claim-diff-check.sh" >/dev/null 2>&1; then
    issues+=("Template-source scripts do not all parse cleanly.")
  fi
  if (( light_mode == 0 )); then
    smoke_root="$(mktemp -d /tmp/methodology-template-source-XXXXXX)"
    smoke_env=(env METHODOLOGY_SKIP_AUDIT_RENDER=1 METHODOLOGY_DASHBOARD_SKIP_DRIFT=1)
    if ! "${smoke_env[@]}" "$SCRIPT_DIR/init-project.sh" --git "$smoke_root/new-repo" >/dev/null 2>&1; then
      issues+=("Template-source smoke test failed: init-project.sh could not bootstrap a disposable repo.")
    elif ! "${smoke_env[@]}" "$SCRIPT_DIR/methodology-entry.sh" --profile minimal "$smoke_root/new-repo" >/dev/null 2>&1; then
      issues+=("Template-source smoke test failed: methodology-entry.sh could not re-enter the disposable repo.")
    elif ! "${smoke_env[@]}" "$SCRIPT_DIR/bootstrap-methodology.sh" "$smoke_root/new-repo" >/dev/null 2>&1; then
      issues+=("Template-source smoke test failed: bootstrap-methodology.sh is not idempotent on a disposable repo.")
    fi
    mkdir -p "$smoke_root/existing-repo/src"
    printf 'console.log(\"hello\\n\")\n' > "$smoke_root/existing-repo/src/index.js"
    git -C "$smoke_root/existing-repo" init -b main >/dev/null 2>&1 || true
    if ! "${smoke_env[@]}" "$SCRIPT_DIR/adopt-methodology.sh" "$smoke_root/existing-repo" >/dev/null 2>&1; then
      issues+=("Template-source smoke test failed: adopt-methodology.sh could not retrofit a disposable existing repo.")
    fi
    rm -rf "$smoke_root"
  fi
  if (( json_mode == 1 )); then
    printf '{'
    printf '"target":"%s",' "$(json_escape "$target_dir")"
    printf '"mode":"%s",' "$(json_escape "$mode")"
    printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
    printf '"issues":'
    print_json_array issues
    printf '}\n'
  else
    if (( ${#issues[@]} == 0 )); then
      echo "Mode check passed for $target_dir ($mode)"
    else
      echo "Mode check failed for $target_dir ($mode)"
      printf '  - %s\n' "${issues[@]}"
    fi
  fi
  (( ${#issues[@]} == 0 )) && exit 0 || exit 1
fi

if is_placeholder_file "$target_dir" "PROJECT_BRIEF.md"; then
  issues+=("PROJECT_BRIEF.md is still placeholder content.")
fi
if is_placeholder_file "$target_dir" "COMMANDS.md"; then
  issues+=("COMMANDS.md is still placeholder content.")
fi

check_required_docs PROJECT_BRIEF.md TASKS.md SESSION_STATE.md HANDOFF.md COMMANDS.md LOCAL_ENV.md

if [[ "$mode" == "product" || "$mode" == "production" ]]; then
  check_required_docs ARCHITECTURE.md DECISIONS.md VERIFICATION_LOG.md MANUAL_CHECKS.md
fi

if [[ "$work_type" == "product" && ( "$mode" == "product" || "$mode" == "production" ) ]]; then
  python3 - "$(project_file_path "$target_dir" "PROJECT_BRIEF.md")" <<'PY' >/tmp/mode-project-brief.$$ 2>/dev/null || true
import sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)
required = [
    "## Business Owner",
    "## Strategic Goal / Why Now",
    "## Customer Evidence",
    "## Expected Business Impact",
    "## Review Date",
]
text = path.read_text().splitlines()
for heading in required:
    try:
        idx = text.index(heading)
    except ValueError:
        print(f"missing::{heading}")
        continue
    value = ""
    for line in text[idx + 1:]:
        if line.startswith("## "):
            break
        stripped = line.strip()
        if stripped and not stripped.startswith("<!--"):
            value = stripped
            break
    if not value:
        print(f"blank::{heading}")
PY
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    issues+=("PROJECT_BRIEF.md is missing required product-mode field content for ${item#*::}.")
  done </tmp/mode-project-brief.$$
  rm -f /tmp/mode-project-brief.$$
fi

if [[ "$mode" == "product" || "$mode" == "production" ]]; then
  if (( light_mode == 1 )); then
    if [[ "$(last_verification_result "$verification_log_file")" != "passed" ]]; then
      issues+=("Last recorded verification is not passed for the declared $mode mode.")
    fi
  elif ! "$SCRIPT_DIR/verify-project.sh" --json --no-log "$target_dir" >/dev/null 2>&1; then
    issues+=("Verification does not pass for the declared $mode mode.")
  fi
  if ! "$SCRIPT_DIR/metrics-check.sh" --json --no-write "$target_dir" >/dev/null 2>&1; then
    issues+=("Metrics are not strong enough for the declared $mode mode.")
  fi
fi

if [[ "$mode" == "production" ]]; then
  check_required_docs METRICS.md INCIDENTS.md RELEASE_NOTES.md SECURITY_NOTES.md MILESTONES.md DEPENDENCIES.md
  if ! grep -Eq '^## Service Ownership' "$(project_file_path "$target_dir" "ARCHITECTURE.md")" 2>/dev/null; then
    issues+=("ARCHITECTURE.md is missing the Service Ownership section required for production mode.")
  fi
  python3 - "$(project_file_path "$target_dir" "SECURITY_NOTES.md")" <<'PY' >/tmp/mode-security.$$ 2>/dev/null || true
import sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)
required = [
    "## Risk Tier",
    "## Data Sensitivity",
    "## Security Approval / Waivers",
    "## Tool Access Policy",
    "## AI / Data Exposure Policy",
]
text = path.read_text().splitlines()
for heading in required:
    if heading not in text:
        print(f"missing::{heading}")
PY
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    issues+=("SECURITY_NOTES.md is missing required production field ${item#*::}.")
  done </tmp/mode-security.$$
  rm -f /tmp/mode-security.$$
  if (( light_mode == 1 )); then
    if is_placeholder_file "$target_dir" "SECURITY_NOTES.md"; then
      issues+=("SECURITY_NOTES.md is still placeholder content for production mode.")
    fi
    if is_placeholder_file "$target_dir" "DEPENDENCIES.md"; then
      issues+=("DEPENDENCIES.md is still placeholder content for production mode.")
    fi
  else
    if ! "$SCRIPT_DIR/security-review.sh" --json --no-write "$target_dir" >/dev/null 2>&1; then
      issues+=("Security review does not pass for production mode.")
    fi
    if ! "$SCRIPT_DIR/dependency-delta.sh" --json --no-write "$target_dir" >/dev/null 2>&1; then
      issues+=("Dependency documentation is not production-ready.")
    fi
  fi
  if ! "$SCRIPT_DIR/decision-review.sh" --json "$target_dir" >/dev/null 2>&1; then
    issues+=("Decision review dates are not production-ready.")
  fi
fi

if [[ "$(trim_whitespace "$(awk '/^- Status:/{sub(/^- Status:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "HOTFIX.md")" 2>/dev/null || true)")" == "active" ]]; then
  check_required_docs HOTFIX.md LOCAL_ENV.md VERIFICATION_LOG.md ACTIVE_CLAIMS.md HANDOFF.md
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"mode":"%s",' "$(json_escape "$mode")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "Mode check passed for $target_dir ($mode)"
  else
    echo "Mode check failed for $target_dir ($mode)"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
exit 1
