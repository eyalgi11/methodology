#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: ready-check.sh --task "Task name" [--json] [target-directory]

Checks whether a non-trivial task is ready to move into the Ready state.
EOF
}

target_arg=""
task=""
json_mode=0

while (($# > 0)); do
  case "$1" in
    --task) task="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
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

if [[ -z "$task" ]]; then
  echo "--task is required." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
blockers_file="$(project_file_path "$target_dir" "BLOCKERS.md")"
issues=()

task_info="$(python3 - "$tasks_file" "$task" "$target_dir" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
task = sys.argv[2]
target_dir = Path(sys.argv[3])
task_re = re.compile(r"^- (?:(?:\[[ xX]\]) )?(.+)$")
if not path.exists():
    raise SystemExit(0)

for line in path.read_text().splitlines():
    match = task_re.match(line)
    if not match:
        continue
    body = match.group(1).strip().strip("`")
    display = re.sub(r"\s*\(`?(?:specs|features)/[^`)\n]+\.md`?\)\s*$", "", body).strip()
    display = re.sub(r"\s*`?\((?:specs|features)/[^`)\n]+\.md\)`?\s*$", "", display).strip()
    if display == task or display.startswith(task + " (") or display.startswith(task + " - "):
        spec_match = re.search(r"\(`?((?:specs|features)/[^`)\n]+\.md)`?\)\s*|`?\(((?:specs|features)/[^`)\n]+\.md)\)`?", body)
        spec_path = ""
        if spec_match:
            spec_path = spec_match.group(1) or spec_match.group(2) or ""
        if not spec_path:
            slug = re.sub(r"[^a-z0-9]+", "-", display.lower()).strip("-")
            for rel in (target_dir / "methodology" / "work" / slug / "TASK.json", target_dir / "work" / slug / "TASK.json"):
                if rel.exists():
                    try:
                        data = json.loads(rel.read_text())
                        spec_path = data.get("spec", "") or ""
                        break
                    except Exception:
                        pass
        print(f"{display}\t{spec_path}")
        raise SystemExit(0)
PY
)"

task_body="$(printf '%s' "$task_info" | cut -f1)"
spec_relpath="$(printf '%s' "$task_info" | cut -f2)"

if [[ -z "$task_body" ]]; then
  issues+=("Task was not found in TASKS.md.")
fi

if [[ -z "$spec_relpath" ]]; then
  issues+=("Task does not link to a feature spec.")
fi

spec_file="$(project_file_path "$target_dir" "$spec_relpath")"
if [[ -n "$spec_relpath" && ! -f "$spec_file" ]]; then
  issues+=("Linked spec does not exist: $spec_relpath")
fi

if [[ -f "$spec_file" ]]; then
  success_metric_count="$(awk '
    $0 == "## Success Metric" { flag = 1; next }
    /^## / && flag { exit }
    flag {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line ~ /^- Primary outcome:[[:space:]]*[^[:space:]].+/) count++
      if (line ~ /^- Leading indicator or proxy:[[:space:]]*[^[:space:]].+/) count++
    }
    END { print count + 0 }
  ' "$spec_file")"
  acceptance_count="$(awk '
    $0 == "## Acceptance Criteria" { flag = 1; next }
    /^## / && flag { exit }
    flag && /^- (\[[ xX]\] )?[^[:space:]].+/ { count++ }
    END { print count + 0 }
  ' "$spec_file")"
  verification_count="$(awk '
    $0 == "## Verification Plan" { flag = 1; next }
    /^## / && flag { exit }
    flag {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line ~ /^- Tests:[[:space:]]*[^[:space:]].+/) count++
      if (line ~ /^- Manual checks:[[:space:]]*[^[:space:]].+/) count++
      if (line ~ /^- Observability or logging checks:[[:space:]]*[^[:space:]].+/) count++
    }
    END { print count + 0 }
  ' "$spec_file")"

  if (( success_metric_count == 0 )); then
    issues+=("Spec is missing a real success metric or proxy.")
  fi
  if (( acceptance_count == 0 )); then
    issues+=("Spec is missing acceptance criteria.")
  fi
  if (( verification_count == 0 )); then
    issues+=("Spec is missing a real verification plan.")
  fi
fi

if grep -Fqi -- "$task" "$blockers_file" 2>/dev/null; then
  issues+=("Task appears in BLOCKERS.md and should not move to Ready yet.")
fi

if (( json_mode == 1 )); then
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"task":"%s",' "$(json_escape "$task")"
  printf '"ok":%s,' "$( (( ${#issues[@]} == 0 )) && printf true || printf false )"
  printf '"issues":'
  print_json_array issues
  printf '}\n'
else
  if (( ${#issues[@]} == 0 )); then
    echo "Task is ready: $task"
  else
    echo "Ready check failed for $task"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
exit 1
