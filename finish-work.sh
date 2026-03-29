#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: finish-work.sh --task "Task name" [options] [target-directory]

Runs the standard end-of-work sequence: verification, closure, sync, and
milestone refresh. Optionally adds a release-candidate summary.

Options:
  --task TEXT
  --summary TEXT
  --remaining TEXT
  --next-step TEXT
  --release-note TEXT
  --health TEXT
  --version TEXT
  --learning-target TEXT
  --learning-note TEXT
  --learning-review-by TEXT
EOF
}

target_arg=""
task=""
summary=""
remaining=""
next_step=""
release_note=""
health="green"
version_label=""
learning_target=""
learning_note=""
learning_review_by=""

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --remaining) remaining="$2"; shift 2 ;;
    --next-step) next_step="$2"; shift 2 ;;
    --release-note) release_note="$2"; shift 2 ;;
    --health) health="$2"; shift 2 ;;
    --version) version_label="$2"; shift 2 ;;
    --learning-target) learning_target="$2"; shift 2 ;;
    --learning-note) learning_note="$2"; shift 2 ;;
    --learning-review-by) learning_review_by="$2"; shift 2 ;;
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

if [[ -z "$task" ]]; then
  echo "--task is required." >&2
  exit 1
fi

target_dir="${target_arg:-$PWD}"
verify_json="$("$SCRIPT_DIR/verify-project.sh" --json "$target_dir")"
verify_result="$(printf '%s' "$verify_json" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)"

close_args=(
  --task "$task"
  --summary "${summary:-$task completed.}"
  --verification "verify-project.sh ${verify_result}"
  --remaining "${remaining:-No remaining work recorded.}"
  --next-step "${next_step:-Pick the next highest-priority task.}"
  --release-note "${release_note:-$task completed.}"
  --health "$health"
)
if [[ -n "$learning_target" ]]; then
  close_args+=(--learning-target "$learning_target")
fi
if [[ -n "$learning_note" ]]; then
  close_args+=(--learning-note "$learning_note")
fi
if [[ -n "$learning_review_by" ]]; then
  close_args+=(--learning-review-by "$learning_review_by")
fi

"$SCRIPT_DIR/close-work.sh" "${close_args[@]}" "$target_dir" >/dev/null

"$SCRIPT_DIR/sync-docs.sh" "$target_dir" >/dev/null
"$SCRIPT_DIR/milestone-update.sh" "$target_dir" >/dev/null
if ! "$SCRIPT_DIR/mode-check.sh" "$target_dir" >/dev/null 2>&1; then
  echo "finish-work warning: mode-check reported issues; review later." >&2
fi

if [[ -n "$version_label" ]]; then
  "$SCRIPT_DIR/release-cut.sh" --version "$version_label" "$target_dir" >/dev/null
fi

echo "Finished work sequence completed for $target_dir"
echo "Verification result: $verify_result"
if [[ -n "$version_label" ]]; then
  echo "Release summary updated: $version_label"
fi
