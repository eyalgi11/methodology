#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: security-review.sh [--json] [target-directory]

Runs lightweight security hygiene checks and writes an auto summary into
SECURITY_NOTES.md.
EOF
}

target_arg=""
json_mode=0
write_mode=1
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --no-write) write_mode=0; shift ;;
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
security_notes_file="$(project_file_path "$target_dir" "SECURITY_NOTES.md")"
issues=()

search_rg() {
  local pattern="$1"
  rg -n --hidden --glob '!node_modules/**' --glob '!.git/**' --glob '!dist/**' --glob '!build/**' --glob '!coverage/**' "$pattern" "$target_dir" 2>/dev/null || true
}

secret_hits="$(search_rg '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|BEGIN PRIVATE KEY|api[_-]?key[[:space:]]*[:=][[:space:]]*["'"'"'A-Za-z0-9_-]{8,}|secret[[:space:]]*[:=][[:space:]]*["'"'"'A-Za-z0-9_-]{8,}|password[[:space:]]*[:=][[:space:]]*["'"'"'A-Za-z0-9_-]{4,})')"
debug_hits="$(search_rg '(DEBUG[[:space:]]*[:=][[:space:]]*(true|True|1)|debug[[:space:]]*[:=][[:space:]]*(true|True))')"
open_cors_hits="$(search_rg '(allow_origins[[:space:]]*=[[:space:]]*\[[^]]*"\*"|origin:[[:space:]]*"\*")')"
integration_hits="$(search_rg '(twilio|stripe|paypal|sendgrid|auth0|firebase|supabase|s3|ses|oauth|openid|jwt|api[_-]?client)')"
pii_hits="$(search_rg '(ssn|social[_-]?security|passport|tax[_-]?id|date[_-]?of[_-]?birth|credit[_-]?card|card[_-]?number)')"

if [[ -n "$secret_hits" ]]; then
  issues+=("Possible hardcoded secrets detected.")
fi
if [[ -n "$debug_hits" ]]; then
  issues+=("Debug mode defaults detected in repo files.")
fi
if [[ -n "$open_cors_hits" ]]; then
  issues+=("Wildcard CORS configuration detected.")
fi
if [[ -n "$integration_hits" || -n "$pii_hits" ]]; then
  if is_placeholder_file "$target_dir" "SECURITY_NOTES.md"; then
    issues+=("SECURITY_NOTES.md is still placeholder content despite security-relevant integrations or data patterns.")
  fi
  if ! grep -Eq '^## Risk Tier' "$security_notes_file" 2>/dev/null; then
    issues+=("SECURITY_NOTES.md is missing the Risk Tier section.")
  fi
  if ! grep -Eq '^[[:space:]]*- Security owner:' "$security_notes_file" 2>/dev/null; then
    issues+=("SECURITY_NOTES.md does not record a security owner.")
  fi
  if ! grep -Eq 'Rollback path' "$security_notes_file" 2>/dev/null; then
    issues+=("SECURITY_NOTES.md does not record a rollback path for risky security changes.")
  fi
fi

if [[ -f "$target_dir/.env" ]] && has_git_repo "$target_dir"; then
  if git -C "$target_dir" check-ignore -q .env 2>/dev/null; then
    :
  else
    issues+=(".env exists but is not ignored by git.")
  fi
fi

if is_placeholder_file "$target_dir" "SECURITY_NOTES.md"; then
  issues+=("SECURITY_NOTES.md is still untouched template content.")
fi

summary_body=$(cat <<EOF
- Reviewed at: $(timestamp_now)
- Issue count: ${#issues[@]}
- Secret-pattern hits: $(if [[ -n "$secret_hits" ]]; then printf 'yes'; else printf 'no'; fi)
- Debug-default hits: $(if [[ -n "$debug_hits" ]]; then printf 'yes'; else printf 'no'; fi)
- Wildcard CORS hits: $(if [[ -n "$open_cors_hits" ]]; then printf 'yes'; else printf 'no'; fi)
- External-integration hits: $(if [[ -n "$integration_hits" ]]; then printf 'yes'; else printf 'no'; fi)
- Sensitive-data hits: $(if [[ -n "$pii_hits" ]]; then printf 'yes'; else printf 'no'; fi)
EOF
)
if (( write_mode == 1 )); then
  append_or_replace_auto_section "$security_notes_file" "security-review" "## Auto Security Review" "$summary_body"
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "No obvious security hygiene issues detected."
  else
    echo "Security review issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
exit 1
