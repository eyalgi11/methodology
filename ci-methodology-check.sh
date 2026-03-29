#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: ci-methodology-check.sh [--json] [target-directory]

Runs the read-only methodology checks that are appropriate for CI.
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
mode="$(read_maturity_mode "$target_dir")"
checks=("audit" "status" "drift" "dependency_delta" "security" "mode" "decision_review" "observable_compliance")
failures=()

run_check() {
  local name="$1"
  case "$name" in
    audit) "$SCRIPT_DIR/methodology-audit.sh" "$target_dir" >/dev/null 2>&1 ;;
    status) "$SCRIPT_DIR/methodology-status.sh" "$target_dir" >/dev/null 2>&1 ;;
    drift) "$SCRIPT_DIR/drift-check.sh" "$target_dir" >/dev/null 2>&1 ;;
    dependency_delta) "$SCRIPT_DIR/dependency-delta.sh" --no-write "$target_dir" >/dev/null 2>&1 ;;
    security) "$SCRIPT_DIR/security-review.sh" --no-write "$target_dir" >/dev/null 2>&1 ;;
    mode) "$SCRIPT_DIR/mode-check.sh" "$target_dir" >/dev/null 2>&1 ;;
    decision_review) "$SCRIPT_DIR/decision-review.sh" "$target_dir" >/dev/null 2>&1 ;;
    observable_compliance) "$SCRIPT_DIR/observable-compliance-check.sh" "$target_dir" >/dev/null 2>&1 ;;
    registry)
      [[ -f "$target_dir/METHODOLOGY_REGISTRY.md" ]] || return 0
      "$SCRIPT_DIR/methodology-registry-check.sh" "$target_dir" >/dev/null 2>&1
      ;;
  esac
}

if [[ -f "$target_dir/METHODOLOGY_REGISTRY.md" ]]; then
  checks=("registry" "${checks[@]}")
fi

if [[ "$mode" == "template_source" ]]; then
  checks=("registry" "mode")
fi

for check_name in "${checks[@]}"; do
  if ! run_check "$check_name"; then
    failures+=("$check_name")
  fi
done

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"ok":%s,' "$( (( ${#failures[@]} == 0 )) && printf true || printf false )"
  printf '"failed_checks":'
  print_json_array failures
  printf '}\n'
else
  if (( ${#failures[@]} == 0 )); then
    echo "CI methodology checks passed."
  else
    echo "CI methodology checks failed for $target_dir"
    printf '  - %s\n' "${failures[@]}"
  fi
fi

if (( ${#failures[@]} == 0 )); then
  exit 0
fi
exit 1
