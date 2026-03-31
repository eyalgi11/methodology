#!/usr/bin/env bash
set -euo pipefail

METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_METHODOLOGY_DIR_NAME="methodology"
readonly PROJECT_METHODOLOGY_TOOLKIT_HINT_FILE="toolkit-path.txt"
readonly METHODOLOGY_SCHEMA_VERSION="2026-03-26.1"
readonly METHODOLOGY_GENERATOR_VERSION="methodology-toolkit-2026-03-26.1"
readonly CONTEXT_BUDGET_CORE_CONTEXT_LINES=150
readonly CONTEXT_BUDGET_SESSION_LINES=80
readonly CONTEXT_BUDGET_HANDOFF_LINES=80
readonly CONTEXT_BUDGET_WORK_INDEX_ENTRIES=50
readonly CONTEXT_BUDGET_TASK_STATE_LINES=200
readonly CONTEXT_BUDGET_TASK_HANDOFF_LINES=100

readonly METHODOLOGY_ROOT_FILES=(
  "AGENTS.md"
  "AGENT_TEAM.md"
  "CORE_CONTEXT.md"
  "WORK_INDEX.md"
  "DOCS_ARCHIVE.md"
  "docs-archive-index.json"
  "LOCAL_ENV.md"
  "HOTFIX.md"
  "PROJECT_BRIEF.md"
  "ROADMAP.md"
  "TASKS.md"
  "TASKS_ARCHIVE.md"
  "MULTI_AGENT_PLAN.md"
  "DECISIONS.md"
  "DEFINITION_OF_READY.md"
  "DEFINITION_OF_DONE.md"
  "WORKING_AGREEMENTS.md"
  "REPO_MAP.md"
  "COMMANDS.md"
  "ARCHITECTURE.md"
  "ANTI_PATTERNS.md"
  "METHODOLOGY_MODE.md"
  "METHODOLOGY_EVOLUTION.md"
  "OBSERVABLE_COMPLIANCE.md"
  "ACTIVE_CLAIMS.md"
  "BLOCKERS.md"
  "PROCESS_EXCEPTIONS.md"
  "SESSION_STATE.md"
  "HANDOFF.md"
  "VERIFICATION_LOG.md"
  "MANUAL_CHECKS.md"
  "EXPERIMENTS.md"
  "EXPERIMENT_LOG.md"
  "OPEN_QUESTIONS.md"
  "RISK_REGISTER.md"
  "RELEASE_NOTES.md"
  "MILESTONES.md"
  "METRICS.md"
  "SECURITY_NOTES.md"
  "PROJECT_HEALTH.md"
  "INCIDENTS.md"
  "DEPENDENCIES.md"
  "WEEKLY_REVIEW.md"
  "METHODOLOGY_SCORE.md"
  "methodology-state.json"
  "work/README.md"
  "work/SPRINT_CONTRACT_TEMPLATE.md"
  "claims/README.md"
)

readonly METHODOLOGY_SPEC_TEMPLATE_FILES=(
  "templates/FEATURE_SPEC_TEMPLATE.md"
)

readonly METHODOLOGY_TEMPLATE_STRUCTURE_FILES=(
  "work/README.md"
  "work/SPRINT_CONTRACT_TEMPLATE.md"
  "claims/README.md"
)

readonly METHODOLOGY_PLACEHOLDER_EXEMPT_FILES=(
  "work/README.md"
  "claims/README.md"
)

readonly METHODOLOGY_CORE_FILES=(
  "AGENTS.md"
  "AGENT_TEAM.md"
  "CORE_CONTEXT.md"
  "WORK_INDEX.md"
  "LOCAL_ENV.md"
  "PROJECT_BRIEF.md"
  "ROADMAP.md"
  "TASKS.md"
  "MULTI_AGENT_PLAN.md"
  "DEFINITION_OF_READY.md"
  "DEFINITION_OF_DONE.md"
  "COMMANDS.md"
  "METHODOLOGY_MODE.md"
  "OBSERVABLE_COMPLIANCE.md"
  "ACTIVE_CLAIMS.md"
  "PROCESS_EXCEPTIONS.md"
  "SESSION_STATE.md"
  "HANDOFF.md"
  "VERIFICATION_LOG.md"
  "MANUAL_CHECKS.md"
  "METRICS.md"
  "SECURITY_NOTES.md"
  "methodology-state.json"
  "work/README.md"
  "work/SPRINT_CONTRACT_TEMPLATE.md"
  "claims/README.md"
)

is_manifest_list_member() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

readonly METHODOLOGY_STATE_FILES=(
  "SESSION_STATE.md"
  "HANDOFF.md"
  "TASKS.md"
  "PROJECT_HEALTH.md"
)

resolve_target_dir() {
  local target="${1:-$PWD}"
  if [[ ! -d "$target" ]]; then
    echo "Target directory does not exist: $target" >&2
    exit 1
  fi

  target="$(cd "$target" && pwd)"
  if [[ "$(basename "$target")" == "$PROJECT_METHODOLOGY_DIR_NAME" ]]; then
    local parent_dir
    parent_dir="$(dirname "$target")"
    if [[ -f "$parent_dir/AGENTS.md" ]]; then
      target="$parent_dir"
    fi
  fi

  printf '%s\n' "$target"
}

template_path() {
  local relative_path="$1"
  echo "$METHODOLOGY_DIR/$relative_path"
}

project_brief_heading_value() {
  local target_dir="$1"
  local heading="$2"
  local project_brief_file
  project_brief_file="$(project_file_path "$target_dir" "PROJECT_BRIEF.md")"
  python3 - "$project_brief_file" "$heading" <<'PY' 2>/dev/null || true
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
heading = sys.argv[2].strip()
if not path.exists():
    raise SystemExit(0)

lines = path.read_text().splitlines()
in_section = False
in_comment = False

for raw in lines:
    line = raw.rstrip()
    stripped = line.strip()
    if stripped == heading:
        in_section = True
        continue
    if in_section and stripped.startswith("## "):
        break
    if not in_section:
        continue
    if "<!--" in stripped:
        in_comment = True
    if in_comment:
        if "-->" in stripped:
            in_comment = False
        continue
    if not stripped:
        continue
    stripped = re.sub(r"^[-*]\s+", "", stripped)
    stripped = stripped.strip("`").strip()
    if stripped:
        print(stripped)
        break
PY
}

is_task_line() {
  local line="$1"
  [[ "$line" =~ ^-\ (\[[[:space:]xX]\]\ )?[^[:space:]].+ ]]
}

strip_task_prefix() {
  local line="$1"
  printf '%s\n' "$line" | sed -E 's/^- (\[[ xX]\] )?//'
}

task_slug() {
  local task_label="$1"
  local normalized
  normalized="$(printf '%s' "$task_label" | sed -E 's/[[:space:]]+\(`?(specs|features)\/[^`)]*\.md`?\)$//' | sed -E 's/[[:space:]]+\(?`?(specs|features)\/[^`)]*\.md`?\)?$//' | sed -E 's/[[:space:]]+-[[:space:]].*$//' )"
  normalized="$(trim_whitespace "$normalized")"
  slugify "$normalized"
}

task_workspace_relpath() {
  local task_label="$1"
  printf 'work/%s' "$(task_slug "$task_label")"
}

task_workspace_dir() {
  local target_dir="$1"
  local task_label="$2"
  project_file_path "$target_dir" "$(task_workspace_relpath "$task_label")"
}

task_state_relpath() {
  local task_label="$1"
  printf '%s/STATE.md' "$(task_workspace_relpath "$task_label")"
}

task_handoff_relpath() {
  local task_label="$1"
  printf '%s/HANDOFF.md' "$(task_workspace_relpath "$task_label")"
}

task_manifest_relpath() {
  local task_label="$1"
  printf '%s/TASK.json' "$(task_workspace_relpath "$task_label")"
}

task_state_file() {
  local target_dir="$1"
  local task_label="$2"
  project_file_path "$target_dir" "$(task_state_relpath "$task_label")"
}

task_handoff_file() {
  local target_dir="$1"
  local task_label="$2"
  project_file_path "$target_dir" "$(task_handoff_relpath "$task_label")"
}

task_manifest_file() {
  local target_dir="$1"
  local task_label="$2"
  project_file_path "$target_dir" "$(task_manifest_relpath "$task_label")"
}

spec_metadata_json() {
  local spec_file="$1"
  python3 - "$spec_file" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
result = {
    "risk_class": "",
    "release_risk": "",
    "launch_owner": "",
}
if not path.exists():
    print(json.dumps(result))
    raise SystemExit(0)

for raw in path.read_text().splitlines():
    line = raw.strip()
    if not line:
        continue
    line = line.strip("`").strip()
    m = re.match(r"^[-*]\s*(Risk class|Release risk|Launch owner):\s*(.+?)\s*$", line, re.I)
    if not m:
        continue
    key = m.group(1).lower().replace(" ", "_")
    value = m.group(2).strip().strip("`").strip()
    if key == "risk_class":
        result["risk_class"] = value
    elif key == "release_risk":
        result["release_risk"] = value
    elif key == "launch_owner":
        result["launch_owner"] = value

print(json.dumps(result))
PY
}

update_task_manifest() {
  local target_dir="$1"
  local task_label="$2"
  local state="${3:-}"
  local spec_path="${4:-}"
  local verification_path="${5:-}"
  local summary="${6:-}"
  local next_step="${7:-}"
  local handoff_step="${8:-}"
  local task_manifest
  local task_state_path
  local task_handoff_path
  local work_type
  local spec_json
  local risk_class=""
  local release_risk=""
  local launch_owner=""

  task_manifest="$(task_manifest_file "$target_dir" "$task_label")"
  task_state_path="$(display_project_relpath "$target_dir" "$(task_state_relpath "$task_label")")"
  task_handoff_path="$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task_label")")"
  work_type="$(read_work_type "$target_dir")"
  if [[ -n "$spec_path" && "$spec_path" != "n/a" ]]; then
    spec_json="$(spec_metadata_json "$(project_file_path "$target_dir" "$spec_path")")"
    risk_class="$(printf '%s' "$spec_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("risk_class",""))' 2>/dev/null || true)"
    release_risk="$(printf '%s' "$spec_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("release_risk",""))' 2>/dev/null || true)"
    launch_owner="$(printf '%s' "$spec_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("launch_owner",""))' 2>/dev/null || true)"
  fi

  python3 - "$task_manifest" "$task_label" "$(task_slug "$task_label")" "${state:-}" "${spec_path:-}" "$task_state_path" "$task_handoff_path" "$work_type" "${verification_path:-}" "${summary:-}" "${next_step:-}" "${handoff_step:-}" "${risk_class:-}" "${release_risk:-}" "${launch_owner:-}" "$(timestamp_now)" "$METHODOLOGY_SCHEMA_VERSION" "$METHODOLOGY_GENERATOR_VERSION" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
incoming = {
    "task": sys.argv[2],
    "task_slug": sys.argv[3],
    "state": sys.argv[4],
    "spec": sys.argv[5] or "n/a",
    "state_path": sys.argv[6],
    "handoff_path": sys.argv[7],
    "work_type": sys.argv[8] or "product",
    "verification_path": sys.argv[9] or "",
    "summary": sys.argv[10] or "",
    "next_step": sys.argv[11] or "",
    "resume_here": sys.argv[12] or "",
    "risk_class": sys.argv[13] or "n/a",
    "release_risk": sys.argv[14] or "n/a",
    "launch_owner": sys.argv[15] or "",
    "updated_at": sys.argv[16],
    "schema_version": sys.argv[17],
    "generator_version": sys.argv[18],
}

data = {}
if path.exists():
    try:
        data = json.loads(path.read_text())
    except Exception:
        data = {}

for key, value in incoming.items():
    if value == "":
        continue
    if key in {"spec", "risk_class", "release_risk", "launch_owner"} and value == "n/a" and data.get(key):
        continue
    data[key] = value

path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
}

task_manifest_json() {
  local target_dir="$1"
  local task_label="$2"
  local manifest_path
  manifest_path="$(task_manifest_file "$target_dir" "$task_label")"
  if [[ -f "$manifest_path" ]]; then
    cat "$manifest_path"
  else
    printf '{}\n'
  fi
}

ensure_task_workspace() {
  local target_dir="$1"
  local task_label="$2"
  local state="$3"
  local spec_path="${4:-}"
  local work_dir
  local state_file
  local handoff_file

  work_dir="$(task_workspace_dir "$target_dir" "$task_label")"
  state_file="$(task_state_file "$target_dir" "$task_label")"
  handoff_file="$(task_handoff_file "$target_dir" "$task_label")"
  mkdir -p "$work_dir"

  if [[ ! -f "$state_file" ]]; then
    cat > "$state_file" <<EOF
# Task State

- Task: ${task_label}
- Task slug: $(task_slug "$task_label")
- Schema version: ${METHODOLOGY_SCHEMA_VERSION}
- Generator version: ${METHODOLOGY_GENERATOR_VERSION}
- Task state: ${state}
- Spec: ${spec_path:-n/a}
- Updated at: $(timestamp_now)

## Objective
- Current objective for this task

## Current Status
- What was finished for this task so far

## Verification
- Verification run or still needed

## Blockers / Assumptions
- Current blockers, assumptions, or dependencies

## Next Step
- Exact next step for this task
EOF
  fi

  if [[ ! -f "$handoff_file" ]]; then
    cat > "$handoff_file" <<EOF
# Task Handoff

- Task: ${task_label}
- Task slug: $(task_slug "$task_label")
- Schema version: ${METHODOLOGY_SCHEMA_VERSION}
- Generator version: ${METHODOLOGY_GENERATOR_VERSION}
- Task state: ${state}
- Spec: ${spec_path:-n/a}
- Updated at: $(timestamp_now)

## Completed
- What was completed for this task

## Remaining
- What still remains for this task

## Verification Run
- Commands, tests, or manual checks already performed

## Risks / Blockers
- Risks or blockers specific to this task

## Resume Here
- Exact next step to continue this task
EOF
  fi

  if [[ ! -f "$(task_manifest_file "$target_dir" "$task_label")" ]]; then
    update_task_manifest "$target_dir" "$task_label" "$state" "${spec_path:-n/a}"
  fi
}

update_work_index_entry() {
  local target_dir="$1"
  local task_label="$2"
  local state="$3"
  local claim_ref="${4:-}"
  local index_file
  local workspace_state
  local workspace_handoff

  index_file="$(project_file_path "$target_dir" "WORK_INDEX.md")"
  workspace_state="$(display_project_relpath "$target_dir" "$(task_state_relpath "$task_label")")"
  workspace_handoff="$(display_project_relpath "$target_dir" "$(task_handoff_relpath "$task_label")")"

  python3 - "$index_file" "$task_label" "$state" "$workspace_state" "$workspace_handoff" "$claim_ref" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
task = sys.argv[2]
state = sys.argv[3]
workspace = sys.argv[4]
handoff = sys.argv[5]
claim_ref = sys.argv[6].strip()
HEADER = [
    "# Work Index",
    "",
    "Use this file as the compact index of active task workspaces.",
    "",
    "## Active Workspaces",
    "",
]
PLACEHOLDER_TASK = "Define initial project brief and first task"

if path.exists():
    lines = path.read_text().splitlines()
else:
    lines = HEADER[:]

blocks = []
current = []
in_comment = False
for line in lines:
    if "<!--" in line:
        in_comment = True
    if in_comment:
        if "-->" in line:
            in_comment = False
        continue
    if line.startswith("- Task: "):
        if current:
            blocks.append(current)
        current = [line]
    elif current and (line.startswith("  ") or not line.strip()):
        current.append(line)
    else:
        if current:
            blocks.append(current)
            current = []
if current:
    blocks.append(current)

def task_name(block):
    for line in block:
        if line.startswith("- Task: "):
            return line.split(":", 1)[1].strip()
    return ""

def emit_block():
    block = [
        f"- Task: {task}",
        f"  State: {state}",
        f"  Workspace: {workspace}",
        f"  Handoff: {handoff}",
    ]
    if claim_ref:
        block.append(f"  Claims: {claim_ref}")
    return block

filtered = []
for block in blocks:
    name = task_name(block)
    if name == task:
        continue
    if task != PLACEHOLDER_TASK and name == PLACEHOLDER_TASK:
        continue
    filtered.append(block)

rebuilt = HEADER + emit_block()
if filtered:
    rebuilt.append("")
for idx, block in enumerate(filtered):
    rebuilt.extend(block)
    if idx != len(filtered) - 1:
      rebuilt.append("")

path.write_text("\n".join(rebuilt).rstrip() + "\n")
PY
}

task_lookup_record() {
  local tasks_file="$1"
  python3 - "$tasks_file" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print("{}")
    raise SystemExit(0)

priorities = ["## In Progress", "## Ready", "## Planned", "## Blocked"]
state_map = {
    "## In Progress": "in_progress",
    "## Ready": "ready",
    "## Planned": "planned",
    "## Blocked": "blocked",
}
current = ""
found = []
block = []

def emit_block(section, lines):
    if not section or not lines:
        return
    body = re.sub(r"^- (?:(?:\[[ xX]\]) )?", "", lines[0]).strip()
    body = body.strip("`")
    spec = ""
    spec_match = re.search(r"\(`?((?:specs|features)/[^`)\n]+\.md)`?\)|`?\(((?:specs|features)/[^`)\n]+\.md)\)`?", body)
    if spec_match:
        spec = spec_match.group(1) or spec_match.group(2) or ""
    if not spec:
        for extra in lines[1:]:
            spec_line = re.search(r"^\s*-\s*Spec:\s*(.+)$", extra)
            if not spec_line:
                continue
            spec_match = re.search(r"((?:specs|features)/[^`,;\n)]+\.md)", spec_line.group(1))
            if spec_match:
                spec = spec_match.group(1)
                break
    display = re.sub(r"\s*\(`?(?:specs|features)/[^`)\n]+\.md`?\)\s*$", "", body).strip()
    display = re.sub(r"\s*`?\((?:specs|features)/[^`)\n]+\.md\)`?\s*$", "", display).strip()
    if display:
        found.append({"heading": section, "task": display, "spec": spec})

for line in path.read_text().splitlines():
    if line.startswith("## "):
        emit_block(current, block)
        block = []
        current = line
        continue
    if line.startswith("- "):
        emit_block(current, block)
        block = [line]
        continue
    if block and (line.startswith("  ") or not line.strip()):
        block.append(line)

emit_block(current, block)

for wanted in priorities:
    for item in found:
        if item["heading"] == wanted:
            item["state"] = state_map[wanted]
            print(json.dumps(item))
            raise SystemExit(0)

print("{}")
PY
}

work_index_record() {
  local target_dir="$1"
  local index_file
  index_file="$(project_file_path "$target_dir" "WORK_INDEX.md")"
  python3 - "$index_file" "$target_dir" <<'PY'
import json
import re
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
target_dir = Path(sys.argv[2])
if not index_path.exists():
    print("{}")
    raise SystemExit(0)

task = state = workspace = handoff = claims = spec = ""
in_comment = False
for line in index_path.read_text().splitlines():
    if "<!--" in line:
        in_comment = True
    if in_comment:
        if "-->" in line:
            in_comment = False
        continue
    if line.startswith("- Task: ") and not task:
        task = line.split(":", 1)[1].strip()
    elif task and line.startswith("  State: ") and not state:
        state = line.split(":", 1)[1].strip()
    elif task and line.startswith("  Workspace: ") and not workspace:
        workspace = line.split(":", 1)[1].strip()
    elif task and line.startswith("  Handoff: ") and not handoff:
        handoff = line.split(":", 1)[1].strip()
    elif task and line.startswith("  Claims: ") and not claims:
        claims = line.split(":", 1)[1].strip()
    elif task and line.startswith("- Task: "):
        break

if not task:
    print("{}")
    raise SystemExit(0)

if workspace:
    workspace_path = target_dir / workspace
    if workspace.startswith("methodology/"):
        workspace_path = target_dir / workspace
    elif not workspace_path.exists():
        workspace_path = target_dir / "methodology" / workspace
    manifest_path = workspace_path.parent / "TASK.json" if workspace_path.name in {"STATE.md", "HANDOFF.md"} else workspace_path / "TASK.json"
    if manifest_path.exists():
        try:
            data = json.loads(manifest_path.read_text())
            state = data.get("state", state)
            spec = data.get("spec", spec)
        except Exception:
            pass
    if workspace_path.exists():
        for line in workspace_path.read_text().splitlines():
            if line.startswith("- Task state:"):
                state = line.split(":", 1)[1].strip()
            elif line.startswith("- Spec:"):
                spec = line.split(":", 1)[1].strip()

print(json.dumps({
    "task": task,
    "state": state,
    "spec": spec,
    "workspace": workspace,
    "handoff": handoff,
    "claims": claims,
}))
PY
}

effective_task_record() {
  local target_dir="$1"
  local tasks_file
  local record
  tasks_file="$(project_file_path "$target_dir" "TASKS.md")"
  record="$(task_lookup_record "$tasks_file")"
  if python3 -c 'import json,sys; raise SystemExit(0 if json.loads(sys.argv[1]).get("task") else 1)' "$record" 2>/dev/null; then
    python3 - "$record" "$target_dir" <<'PY'
import json
import sys
from pathlib import Path

record = json.loads(sys.argv[1])
target_dir = Path(sys.argv[2])
task = record.get("task", "")
if task:
    slug = task.lower()
    slug = __import__("re").sub(r'[^a-z0-9]+', '-', slug).strip('-')
    manifest_path = target_dir / "methodology" / "work" / slug / "TASK.json"
    if not manifest_path.exists():
        manifest_path = target_dir / "work" / slug / "TASK.json"
    if manifest_path.exists():
        try:
            data = json.loads(manifest_path.read_text())
            for key in ("state", "spec"):
                value = data.get(key, "")
                if value:
                    record[key] = value
            if data.get("state_path"):
                record["workspace"] = data["state_path"]
            if data.get("handoff_path"):
                record["handoff"] = data["handoff_path"]
        except Exception:
            pass
print(json.dumps(record))
PY
    return 0
  fi
  work_index_record "$target_dir"
}

task_workspace_current_state() {
  local target_dir="$1"
  local task_label="$2"
  local manifest_file
  local state_file
  local value
  manifest_file="$(task_manifest_file "$target_dir" "$task_label")"
  if [[ -f "$manifest_file" ]]; then
    value="$(python3 -c 'import json,sys,pathlib; p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text()) if p.exists() else {}; print(data.get("state",""))' "$manifest_file" 2>/dev/null || true)"
    value="$(trim_whitespace "$value")"
    if ! is_placeholder_value "$value" && [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  state_file="$(task_state_file "$target_dir" "$task_label")"
  if [[ ! -f "$state_file" ]]; then
    return 0
  fi
  value="$(awk '
    /^- Task state:/ {
      sub(/^- Task state:[[:space:]]*/, "", $0)
      print
      exit
    }
  ' "$state_file" 2>/dev/null || true)"
  value="$(trim_whitespace "$value")"
  if ! is_placeholder_value "$value" && [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  fi
}

project_file_path() {
  local target_dir="$1"
  local relative_path="$2"
  if [[ "$relative_path" == "AGENTS.md" ]]; then
    printf '%s\n' "$target_dir/$relative_path"
    return 0
  fi
  if [[ "$relative_path" == specs/* ]]; then
    if [[ -e "$target_dir/$relative_path" || "$relative_path" == "specs/FEATURE_SPEC_TEMPLATE.md" ]]; then
      printf '%s\n' "$target_dir/$relative_path"
      return 0
    fi
  fi

  local methodology_dir="$target_dir/$PROJECT_METHODOLOGY_DIR_NAME"
  if [[ -d "$methodology_dir" ]]; then
    printf '%s\n' "$methodology_dir/$relative_path"
    return 0
  fi

  printf '%s\n' "$target_dir/$relative_path"
}

display_project_relpath() {
  local target_dir="$1"
  local relative_path="$2"
  if [[ "$relative_path" == "AGENTS.md" ]]; then
    printf '%s\n' "$relative_path"
    return 0
  fi
  if [[ "$relative_path" == specs/* ]]; then
    if [[ -e "$target_dir/$relative_path" || "$relative_path" == "specs/FEATURE_SPEC_TEMPLATE.md" ]]; then
      printf '%s\n' "$relative_path"
      return 0
    fi
  fi

  if [[ -d "$target_dir/$PROJECT_METHODOLOGY_DIR_NAME" ]]; then
    printf '%s/%s\n' "$PROJECT_METHODOLOGY_DIR_NAME" "$relative_path"
  else
    printf '%s\n' "$relative_path"
  fi
}

project_toolkit_hint_file() {
  local target_dir="$1"
  project_file_path "$target_dir" "$PROJECT_METHODOLOGY_TOOLKIT_HINT_FILE"
}

valid_toolkit_home() {
  local candidate="${1:-}"
  [[ -n "$candidate" && -d "$candidate" && -f "$candidate/methodology-common.sh" && -x "$candidate/methodology-entry.sh" ]]
}

resolve_toolkit_home() {
  local target_dir="${1:-$PWD}"
  local candidate=""
  local hint_file=""
  target_dir="$(resolve_target_dir "$target_dir")"

  candidate="${METHODOLOGY_HOME:-}"
  if valid_toolkit_home "$candidate"; then
    cd "$candidate" && pwd
    return 0
  fi

  hint_file="$(project_toolkit_hint_file "$target_dir")"
  if [[ -f "$hint_file" ]]; then
    candidate="$(head -n 1 "$hint_file" 2>/dev/null || true)"
    candidate="$(trim_whitespace "$candidate")"
    if valid_toolkit_home "$candidate"; then
      cd "$candidate" && pwd
      return 0
    fi
  fi

  printf '%s\n' "$METHODOLOGY_DIR"
}

toolkit_script_path() {
  local target_dir="$1"
  local script_name="$2"
  printf '%s/%s\n' "$(resolve_toolkit_home "$target_dir")" "$script_name"
}

write_toolkit_path_hint() {
  local target_dir="$1"
  local hint_file
  hint_file="$(project_toolkit_hint_file "$target_dir")"
  mkdir -p "$(dirname "$hint_file")"
  printf '%s\n' "$METHODOLOGY_DIR" > "$hint_file"
}

normalize_startup_profile() {
  local profile="${1:-normal}"
  case "$profile" in
    minimal|normal|deep) printf '%s\n' "$profile" ;;
    *) printf '%s\n' "normal" ;;
  esac
}

context_pack_max_lines_for_profile() {
  local profile
  profile="$(normalize_startup_profile "${1:-normal}")"
  case "$profile" in
    minimal) printf '20\n' ;;
    deep) printf '80\n' ;;
    *) printf '40\n' ;;
  esac
}

context_budget_for() {
  local relative_path="$1"
  case "$relative_path" in
    CORE_CONTEXT.md) printf '%s\n' "$CONTEXT_BUDGET_CORE_CONTEXT_LINES" ;;
    SESSION_STATE.md) printf '%s\n' "$CONTEXT_BUDGET_SESSION_LINES" ;;
    HANDOFF.md) printf '%s\n' "$CONTEXT_BUDGET_HANDOFF_LINES" ;;
    WORK_INDEX.md) printf '%s\n' "$CONTEXT_BUDGET_WORK_INDEX_ENTRIES" ;;
    work/*/STATE.md) printf '%s\n' "$CONTEXT_BUDGET_TASK_STATE_LINES" ;;
    work/*/HANDOFF.md) printf '%s\n' "$CONTEXT_BUDGET_TASK_HANDOFF_LINES" ;;
    *) printf '0\n' ;;
  esac
}

is_placeholder_file() {
  local target_dir="$1"
  local relative_path="$2"
  local project_path
  project_path="$(project_file_path "$target_dir" "$relative_path")"
  local baseline_path
  baseline_path="$(template_path "$relative_path")"

  [[ -f "$project_path" && -f "$baseline_path" ]] && cmp -s "$project_path" "$baseline_path"
}

json_escape() {
  local value="${1//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

print_json_array() {
  local -n array_ref=$1
  local first=1
  printf '['
  local item
  for item in "${array_ref[@]}"; do
    if (( first == 0 )); then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

safe_grep_count() {
  local pattern="$1"
  local file_path="$2"
  local count
  count="$(grep -Ec "$pattern" "$file_path" 2>/dev/null || true)"
  if [[ -z "$count" ]]; then
    count="0"
  fi
  printf '%s' "$count"
}

command_label_aliases() {
  local label="$1"
  case "$label" in
    "Browser automation"|"Browser tests / browser automation")
      printf 'Browser automation\nBrowser tests / browser automation\n'
      ;;
    "Mobile automation"|"Mobile / device tests")
      printf 'Mobile automation\nMobile / device tests\n'
      ;;
    "Desktop automation"|"Desktop app tests / automation")
      printf 'Desktop automation\nDesktop app tests / automation\n'
      ;;
    *)
      printf '%s\n' "$label"
      ;;
  esac
}

is_methodology_doc_relpath() {
  local relpath="$1"
  if [[ "$relpath" == "$PROJECT_METHODOLOGY_DIR_NAME/"* ]]; then
    relpath="${relpath#${PROJECT_METHODOLOGY_DIR_NAME}/}"
  fi

  local file_name
  for file_name in "${METHODOLOGY_ROOT_FILES[@]}"; do
    if [[ "$relpath" == "$file_name" ]]; then
      return 0
    fi
  done

  [[ "$relpath" == "specs/FEATURE_SPEC_TEMPLATE.md" || "$relpath" == "templates/FEATURE_SPEC_TEMPLATE.md" || "$relpath" == features/* ]]
}

is_archive_relpath() {
  local relpath="$1"
  [[ "$relpath" == archive/* ]]
}

latest_work_file_info() {
  local target_dir="$1"
  local latest_ts=0
  local latest_path=""
  local file_path
  local relpath
  local mtime

  while IFS= read -r -d '' file_path; do
    relpath="${file_path#$target_dir/}"
    if is_methodology_doc_relpath "$relpath" || is_archive_relpath "$relpath"; then
      continue
    fi

    mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo 0)
    if (( mtime > latest_ts )); then
      latest_ts=$mtime
      latest_path=$file_path
    fi
  done < <(
    find "$target_dir" \
      \( -type d \( \
        -name .git -o \
        -name node_modules -o \
        -name .next -o \
        -name dist -o \
        -name build -o \
        -name coverage -o \
        -name .cache -o \
        -name .turbo -o \
        -name .venv -o \
        -name venv -o \
        -name target -o \
        -name "$PROJECT_METHODOLOGY_DIR_NAME" -o \
        -name archive -o \
        -name out \
      \) -prune \) -o \
      -type f -print0
  )

  printf '%s\t%s\n' "$latest_ts" "$latest_path"
}

format_epoch() {
  local epoch="$1"
  if [[ "$epoch" -le 0 ]]; then
    printf 'n/a'
    return 0
  fi

  date -d "@$epoch" '+%Y-%m-%d %H:%M:%S'
}

timestamp_now() {
  date '+%Y-%m-%d %H:%M:%S'
}

today_date() {
  date '+%Y-%m-%d'
}

read_maturity_mode() {
  local target_dir="$1"
  target_dir="$(resolve_target_dir "$target_dir")"
  if [[ "$target_dir" == "$METHODOLOGY_DIR" ]]; then
    printf 'template_source'
    return 0
  fi
  local mode
  mode="$(awk '/^- Mode:/{sub(/^- Mode:[[:space:]]*/, ""); print; exit}' "$(project_file_path "$target_dir" "METHODOLOGY_MODE.md")" 2>/dev/null || true)"
  mode="$(trim_whitespace "$mode")"
  printf '%s' "${mode:-prototype}"
}

read_work_type() {
  local target_dir="$1"
  local work_type
  local mode
  work_type="$(project_brief_heading_value "$target_dir" "## Work Type")"
  work_type="$(trim_whitespace "$work_type")"
  work_type="${work_type//\`/}"
  if [[ -z "$work_type" ]] || is_placeholder_value "$work_type"; then
    mode="$(read_maturity_mode "$target_dir")"
    mode="$(trim_whitespace "$mode")"
    if [[ "$mode" == "template_source" ]]; then
      printf 'template_source'
      return 0
    fi
    printf 'product'
    return 0
  fi
  case "$work_type" in
    product|maintenance|infra|incident|template_source) printf '%s' "$work_type" ;;
    *) printf 'product' ;;
  esac
}

read_delegation_policy() {
  local target_dir="$1"
  local agent_team_file
  local policy
  agent_team_file="$(project_file_path "$target_dir" "AGENT_TEAM.md")"
  policy="$(python3 - "$agent_team_file" <<'PY' 2>/dev/null || true
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)

lines = path.read_text().splitlines()
in_section = False
for raw in lines:
    line = raw.strip()
    if line == "## Execution Policy":
        in_section = True
        continue
    if in_section and line.startswith("## "):
        break
    if not in_section:
        continue
    m = re.match(r"^-\s*Delegation policy:\s*(.+?)\s*$", line, re.I)
    if m:
        print(m.group(1).strip().strip("`"))
        break
PY
)"
  policy="$(trim_whitespace "$policy")"
  case "$policy" in
    single_agent_by_platform_policy|multi_agent_default) printf '%s\n' "$policy" ;;
    *) printf 'multi_agent_default\n' ;;
  esac
}

work_type_requires_business_context() {
  local work_type="${1:-product}"
  case "$work_type" in
    product) return 0 ;;
    *) return 1 ;;
  esac
}

bootstrap_surface_for() {
  local mode="${1:-prototype}"
  case "$mode" in
    product|production|template_source) printf 'full\n' ;;
    *) printf 'core\n' ;;
  esac
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

slugify() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  printf '%s' "$value"
}

strip_wrapping_backticks() {
  local value="$1"
  if [[ "$value" == \`* ]] && [[ "$value" == *\` ]]; then
    value="${value#\`}"
    value="${value%\`}"
  fi
  printf '%s' "$value"
}

has_git_repo() {
  local target_dir="$1"
  git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

ensure_git_repo() {
  local target_dir="$1"
  if has_git_repo "$target_dir"; then
    return 0
  fi
  git -C "$target_dir" init -b main >/dev/null
  echo "create $target_dir/.git"
}

ensure_git_identity() {
  local target_dir="$1"
  ensure_git_repo "$target_dir"
  local current_name current_email target_user email_user
  current_name="$(git -C "$target_dir" config user.name 2>/dev/null || true)"
  current_email="$(git -C "$target_dir" config user.email 2>/dev/null || true)"
  if [[ -n "$current_name" && -n "$current_email" ]]; then
    return 0
  fi

  target_user="$(stat -c '%U' "$target_dir" 2>/dev/null || true)"
  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    target_user="${SUDO_USER:-$USER}"
  fi
  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    target_user="codex"
  fi
  email_user="$(printf '%s' "$target_user" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$current_name" ]] || git -C "$target_dir" config user.name "$target_user"
  [[ -n "$current_email" ]] || git -C "$target_dir" config user.email "${email_user:-codex}@local"
}

git_has_uncommitted_changes() {
  local target_dir="$1"
  has_git_repo "$target_dir" || return 1
  [[ -n "$(git -C "$target_dir" status --short 2>/dev/null || true)" ]]
}

git_commit_all_if_changed() {
  local target_dir="$1"
  local commit_message="$2"
  ensure_git_repo "$target_dir"
  ensure_git_identity "$target_dir"
  if ! git_has_uncommitted_changes "$target_dir"; then
    echo "skip  git commit (no changes)"
    return 0
  fi
  git -C "$target_dir" add -A
  git -C "$target_dir" commit -m "$commit_message" >/dev/null
  echo "commit $commit_message"
}

current_git_branch() {
  local target_dir="$1"
  if ! has_git_repo "$target_dir"; then
    printf 'n/a'
    return 0
  fi

  local branch_name
  branch_name="$(git -C "$target_dir" branch --show-current 2>/dev/null || true)"
  if [[ -n "$branch_name" ]]; then
    printf '%s' "$branch_name"
    return 0
  fi

  branch_name="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "$branch_name" && "$branch_name" != "HEAD" ]]; then
    printf '%s' "$branch_name"
    return 0
  fi

  printf 'n/a'
}

git_status_short() {
  local target_dir="$1"
  if ! has_git_repo "$target_dir"; then
    return 0
  fi

  git -C "$target_dir" status --short 2>/dev/null || true
}

recent_work_files() {
  local target_dir="$1"
  local limit="${2:-10}"

  local emitted=0
  while IFS=$'\t' read -r _ file_path; do
    local relpath="${file_path#$target_dir/}"
    if is_methodology_doc_relpath "$relpath" || is_archive_relpath "$relpath"; then
      continue
    fi

    printf '%s\n' "$relpath"
    emitted=$((emitted + 1))
    if (( emitted >= limit )); then
      break
    fi
  done < <(
    find "$target_dir" \
      \( -type d \( \
        -name .git -o \
        -name node_modules -o \
        -name .next -o \
        -name dist -o \
        -name build -o \
        -name coverage -o \
        -name .cache -o \
        -name .turbo -o \
        -name .venv -o \
        -name venv -o \
        -name target -o \
        -name "$PROJECT_METHODOLOGY_DIR_NAME" -o \
        -name archive -o \
        -name out \
      \) -prune \) -o \
      -type f -printf '%T@\t%p\n' 2>/dev/null | sort -nr
  )
}

append_or_replace_auto_section() {
  local file_path="$1"
  local section_id="$2"
  local heading="$3"
  local body="$4"
  local start_marker="<!-- AUTO:START ${section_id} -->"
  local end_marker="<!-- AUTO:END ${section_id} -->"
  local tmp_file
  tmp_file="$(mktemp)"
  local marker_block
  marker_block="${start_marker}
${body}
${end_marker}"

  if [[ ! -f "$file_path" ]]; then
    printf '%s\n%s\n' "$heading" "$marker_block" > "$file_path"
    rm -f "$tmp_file"
    return 0
  fi

  if grep -Fq "$start_marker" "$file_path"; then
    awk -v start="$start_marker" -v end="$end_marker" -v block="$marker_block" '
      $0 == start {
        print block
        in_block = 1
        next
      }
      $0 == end {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$file_path" > "$tmp_file"
  else
    cp "$file_path" "$tmp_file"
    if [[ -s "$tmp_file" ]]; then
      printf '\n' >> "$tmp_file"
    fi
    printf '%s\n%s\n' "$heading" "$marker_block" >> "$tmp_file"
  fi

  mv "$tmp_file" "$file_path"
}

last_markdown_label_value() {
  local file_path="$1"
  local label="$2"
  python3 - "$file_path" "$label" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path

path = Path(sys.argv[1])
label = sys.argv[2]
if not path.exists():
    raise SystemExit(0)

needle = f"- {label}:"
value = ""
for raw in path.read_text().splitlines():
    line = raw.rstrip()
    if line.startswith(needle):
        value = line[len(needle):].strip()
print(value)
PY
}

extract_commands_from_markdown() {
  local commands_file="$1"
  if [[ ! -f "$commands_file" ]]; then
    return 0
  fi

  awk '
    /^## / {
      section = substr($0, 4)
      next
    }
    /^- / {
      line = substr($0, 3)
      sep = index(line, ":")
      if (sep == 0) next
      label = substr(line, 1, sep - 1)
      value = substr(line, sep + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", label)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print section "\t" label "\t" value
    }
  ' "$commands_file"
}

is_placeholder_value() {
  local value
  value="$(trim_whitespace "$1")"
  if [[ -z "$value" ]]; then
    return 0
  fi

  case "$value" in
    "What "*|\
    "Branch name or "*|\
    "Current status: green / yellow / red"|\
    "Owner:"|\
    "Metric:"|\
    "Name:"|\
    "Date:"|\
    "Target:"|\
    "Goal:"|\
    "Purpose:"|\
    "Risk:"|\
      "Current priority"|\
      "Active task"|\
      "Ready-to-start task"|\
      "Completed task with verification recorded"|\
      "Primary outcome:"|\
      "Leading indicator or proxy:"|\
      "The next concrete action the next agent should take"|\
      "Decision Needed:"|\
      Spec:*)
      return 0
      ;;
  esac

  return 1
}

task_limit_for_section() {
  local tasks_file="$1"
  local section_heading="$2"
  local label=""
  local default_limit=""
  case "$section_heading" in
    "## In Progress")
      label="In Progress"
      default_limit="1"
      ;;
    "## Ready")
      label="Ready"
      default_limit="3"
      ;;
    *)
      printf '0'
      return 0
      ;;
  esac

  local parsed_limit
  parsed_limit="$(awk -v label="$label" '
    $0 == "## WIP Limits" { in_limits = 1; next }
    /^## / && in_limits { exit }
    in_limits && $0 ~ "^- " label ":" {
      value = $0
      sub(/^- [^:]+:[[:space:]]*/, "", value)
      print value
      exit
    }
  ' "$tasks_file" 2>/dev/null || true)"
  parsed_limit="$(trim_whitespace "$parsed_limit")"
  if [[ "$parsed_limit" =~ ^[0-9]+$ ]]; then
    printf '%s' "$parsed_limit"
  else
    printf '%s' "$default_limit"
  fi
}

section_body() {
  local file_path="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section = 1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "$file_path" 2>/dev/null || true
}

count_tasks_in_section() {
  local file_path="$1"
  local section_heading="$2"
  local mode="${3:-open}"
  local placeholder_text=""
  case "$section_heading" in
    "## In Progress") placeholder_text="Active task" ;;
    "## Ready") placeholder_text="Ready-to-start task" ;;
    "## Done") placeholder_text="Completed task with verification recorded" ;;
  esac

  if [[ "$mode" == "done" ]]; then
    awk -v heading="$section_heading" -v placeholder="$placeholder_text" '
      $0 == heading { flag = 1; next }
      /^## / && flag { exit }
      flag && /^- (\[[xX ]\] )?[^[:space:]].+/ {
        sub(/^- (\[[xX ]\] )?/, "", $0)
        if ($0 != placeholder) count++
      }
      END { print count + 0 }
    ' "$file_path" 2>/dev/null
  else
    awk -v heading="$section_heading" -v placeholder="$placeholder_text" '
      $0 == heading { flag = 1; next }
      /^## / && flag { exit }
      flag && /^- (\[[xX ]\] )?[^[:space:]].+/ {
        sub(/^- (\[[xX ]\] )?/, "", $0)
        if ($0 != placeholder) count++
      }
      END { print count + 0 }
    ' "$file_path" 2>/dev/null
  fi
}

first_real_task_in_section() {
  local file_path="$1"
  local section_heading="$2"
  local placeholder_text=""
  case "$section_heading" in
    "## In Progress") placeholder_text="Active task" ;;
    "## Ready") placeholder_text="Ready-to-start task" ;;
    "## Done") placeholder_text="Completed task with verification recorded" ;;
  esac

  awk -v heading="$section_heading" -v placeholder="$placeholder_text" '
    $0 == heading { flag = 1; next }
    /^## / && flag { exit }
    flag && /^- (\[[xX ]\] )?[^[:space:]].+/ {
      sub(/^- (\[[xX ]\] )?/, "", $0)
      if ($0 != placeholder) {
        print
        exit
      }
    }
  ' "$file_path" 2>/dev/null || true
}

best_next_step() {
  local target_dir="$1"
  local next_step=""
  local session_file
  session_file="$(project_file_path "$target_dir" "SESSION_STATE.md")"

  next_step="$(
    section_body "$session_file" "## Next Exact Step" | awk '
      BEGIN { count = 0 }
      {
        line = $0
        sub(/^- /, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line == "" || line ~ /^<!--/) next
        if (count == 0) {
          out = line
        } else if (count < 3) {
          out = out " " line
        }
        count++
      }
      END { print out }
    '
  )"
  next_step="$(trim_whitespace "$next_step")"
  if ! is_placeholder_value "$next_step" && [[ -n "$next_step" ]]; then
    printf '%s' "$next_step"
    return 0
  fi

  next_step="$(awk '
    /^- Next step:/ {
      value = $0
      sub(/^- Next step:[[:space:]]*/, "", value)
      found = value
    }
    /^- Suggested next step:/ {
      value = $0
      sub(/^- Suggested next step:[[:space:]]*/, "", value)
      found = value
    }
    END {
      if (found != "") print found
    }
  ' "$session_file" 2>/dev/null || true)"
  next_step="$(trim_whitespace "$next_step")"
  if ! is_placeholder_value "$next_step" && [[ -n "$next_step" ]]; then
    printf '%s' "$next_step"
    return 0
  fi

  next_step="$(first_real_task_in_section "$(project_file_path "$target_dir" "TASKS.md")" "## In Progress")"
  if [[ -n "$next_step" ]]; then
    printf '%s' "$next_step"
    return 0
  fi

  next_step="$(first_real_task_in_section "$(project_file_path "$target_dir" "TASKS.md")" "## Ready")"
  if [[ -n "$next_step" ]]; then
    printf '%s' "$next_step"
    return 0
  fi

  next_step="$(first_real_task_in_section "$(project_file_path "$target_dir" "TASKS.md")" "## Planned")"
  printf '%s' "$next_step"
}

count_open_questions() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    printf '0'
    return 0
  fi
  awk '
    /^- / {
      sub(/^- /, "", $0)
      if ($0 != "Unresolved product questions" &&
          $0 != "Unresolved technical questions" &&
          $0 != "Decision Needed:" &&
          $0 !~ /^Owner:/ &&
          $0 !~ /^Decision deadline:/) {
        count++
      }
    }
    END { print count + 0 }
  ' "$file_path" 2>/dev/null
}

count_active_risks() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    printf '0'
    return 0
  fi
  awk '
    /^- Risk:/ {
      sub(/^- Risk:[[:space:]]*/, "", $0)
      if (length($0) > 0) count++
    }
    END { print count + 0 }
  ' "$file_path" 2>/dev/null
}

count_high_risks() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    printf '0'
    return 0
  fi
  awk '
    /^- Risk:/ { risk_line = $0 }
    /Severity:[[:space:]]*(critical|high)/ {
      if (risk_line !~ /^- Risk:[[:space:]]*$/) count++
    }
    END { print count + 0 }
  ' "$file_path" 2>/dev/null
}

last_verification_result() {
  local file_path="$1"
  local result_line
  result_line="$(awk '/^- Result:/{result=$0} END{print result}' "$file_path" 2>/dev/null || true)"
  result_line="${result_line#- Result:}"
  result_line="$(trim_whitespace "$result_line")"
  printf '%s' "${result_line:-unknown}"
}
