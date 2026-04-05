#!/usr/bin/env bash

# Shared shell helpers for bash and zsh.
# Source this file after METHODOLOGY_HOME is available.

_methodology_resolve_home() {
  if [[ -n "${METHODOLOGY_HOME:-}" && -d "${METHODOLOGY_HOME:-}" ]]; then
    printf '%s' "$METHODOLOGY_HOME"
    return 0
  fi
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/methodology/config.env"
  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi
  if [[ -n "${METHODOLOGY_HOME:-}" && -d "${METHODOLOGY_HOME:-}" ]]; then
    printf '%s' "$METHODOLOGY_HOME"
    return 0
  fi
  return 1
}

_methodology_fix_perms_if_needed() {
  local target="$1"
  local methodology_home
  methodology_home="$(_methodology_resolve_home)" || return 0
  if find "$target" -xdev \( -uid 0 -o -gid 0 \) -print -quit 2>/dev/null | grep -q .; then
    local target_user
    target_user="$(stat -c '%U' "$target" 2>/dev/null || true)"
    if [[ -z "$target_user" || "$target_user" == "root" ]]; then
      target_user="${SUDO_USER:-$USER}"
    fi
    echo "Root-owned project files detected. Normalizing ownership and permissions..."
    sudo bash "$methodology_home/fix-project-perms.sh" --user "$target_user" "$target"
  fi
}

_methodology_print_filtered_output() {
  local text="$1"
  local filtered
  filtered="$(printf '%s\n' "$text" | sed '/^skip  /d' | sed '/^archived_count=0$/d')"
  if [[ -n "$filtered" ]]; then
    printf '%s\n' "$filtered"
  fi
}

_methodology_is_managed_project() {
  local target="$1"
  [[ -f "$target/AGENTS.md" && -d "$target/methodology" ]]
}

_methodology_has_nontrivial_existing_content() {
  local target="$1"
  find "$target" -mindepth 1 -maxdepth 1 \
    ! -name '.git' \
    ! -name 'AGENTS.md' \
    ! -name 'methodology' \
    -print -quit 2>/dev/null | grep -q .
}

_methodology_capture_state() {
  local target="$1"
  python3 - "$target" <<'PY'
import hashlib
import json
import pathlib
import sys

target = pathlib.Path(sys.argv[1]).resolve()
paths = []
agents = target / "AGENTS.md"
if agents.is_file():
    paths.append(agents)
methodology = target / "methodology"
if methodology.is_dir():
    paths.extend(sorted(p for p in methodology.rglob("*") if p.is_file()))

snapshot = {}
for path in paths:
    rel = path.relative_to(target).as_posix()
    try:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        continue
    snapshot[rel] = digest

print(json.dumps(snapshot, sort_keys=True))
PY
}

_methodology_report_changes() {
  local before_json="$1"
  local after_json="$2"
  python3 - "$before_json" "$after_json" <<'PY'
import json
import pathlib
import sys

before = json.loads(sys.argv[1] or "{}")
after = json.loads(sys.argv[2] or "{}")

added = sorted(path for path in after if path not in before)
removed = sorted(path for path in before if path not in after)
modified = sorted(path for path in after if path in before and after[path] != before[path])

if not (added or removed or modified):
    print("Methodology update completed. No methodology files changed.")
    raise SystemExit(0)

def is_refresh_only(path: str) -> bool:
    p = pathlib.PurePosixPath(path)
    name = p.name
    if path in {
        "methodology/HANDOFF.md",
        "methodology/SESSION_STATE.md",
        "methodology/WORK_INDEX.md",
        "methodology/CORE_CONTEXT.md",
        "methodology/docs-archive-index.json",
        "methodology/methodology-audit.html",
        "methodology/methodology-state.json",
    }:
        return True
    if len(p.parts) >= 3 and p.parts[0] == "methodology" and p.parts[1] == "work" and name in {"HANDOFF.md", "STATE.md", "TASK.json"}:
        return True
    return False

changes = [(path, "added") for path in added] + [(path, "modified") for path in modified] + [(path, "removed") for path in removed]
refresh_only = [(path, kind) for path, kind in changes if is_refresh_only(path)]
structural = [(path, kind) for path, kind in changes if not is_refresh_only(path)]

if structural:
    print(
        "Methodology update completed. "
        f"Updated {len(structural)} structural path(s)"
        + (f" and refreshed {len(refresh_only)} state path(s):" if refresh_only else ":")
    )
    for path, kind in sorted(structural, key=lambda item: (item[1], item[0])):
        print(f"  {kind:<8} {path}")
    if refresh_only:
        print("State refresh paths:")
        for path, kind in sorted(refresh_only, key=lambda item: (item[1], item[0])):
            print(f"  {kind:<8} {path}")
else:
    print(f"Methodology update completed. No structural methodology files changed; refreshed {len(refresh_only)} state path(s):")
    for path, kind in sorted(refresh_only, key=lambda item: (item[1], item[0])):
        print(f"  {kind:<8} {path}")
PY
}

mstart() {
  local methodology_home target
  methodology_home="$(_methodology_resolve_home)" || {
    echo "METHODOLOGY_HOME is not set. Run install-toolkit.sh first." >&2
    return 1
  }
  target="${1:-.}"
  if _methodology_is_managed_project "$target"; then
    echo "Existing methodology-managed project detected. Using resume flow instead."
    mresume "$target"
    return
  fi
  if [[ -d "$target" ]] && _methodology_has_nontrivial_existing_content "$target"; then
    echo "Directory is not empty and is not a clean fresh project: $target"
    echo "Use mresume if this is an existing project, madopt if this is an existing codebase, or clear the directory before mstart."
    return 1
  fi
  _methodology_fix_perms_if_needed "$target"
  "$methodology_home/methodology-entry.sh" --git "$target" && _methodology_fix_perms_if_needed "$target" && cd "$target"
}

mresume() {
  local methodology_home target
  methodology_home="$(_methodology_resolve_home)" || {
    echo "METHODOLOGY_HOME is not set. Run install-toolkit.sh first." >&2
    return 1
  }
  target="${1:-.}"
  _methodology_fix_perms_if_needed "$target"
  "$methodology_home/methodology-entry.sh" "$target" && _methodology_fix_perms_if_needed "$target" && cd "$target"
}

mupdate() {
  local methodology_home target output cmd_status before_state after_state
  methodology_home="$(_methodology_resolve_home)" || {
    echo "METHODOLOGY_HOME is not set. Run install-toolkit.sh first." >&2
    return 1
  }
  target="${1:-.}"
  _methodology_fix_perms_if_needed "$target"
  before_state="$(_methodology_capture_state "$target")"

  output="$(bash "$methodology_home/migrate-methodology-layout.sh" "$target" 2>&1)"
  cmd_status=$?
  _methodology_print_filtered_output "$output"
  (( cmd_status == 0 )) || return $cmd_status

  output="$("$methodology_home/bootstrap-methodology.sh" "$target" 2>&1)"
  cmd_status=$?
  _methodology_print_filtered_output "$output"
  (( cmd_status == 0 )) || return $cmd_status

  output="$(bash "$methodology_home/upgrade-template-placeholders.sh" "$target" 2>&1)"
  cmd_status=$?
  _methodology_print_filtered_output "$output"
  (( cmd_status == 0 )) || return $cmd_status

  output="$("$methodology_home/archive-cold-docs.sh" "$target" 2>&1)"
  cmd_status=$?
  _methodology_print_filtered_output "$output"
  (( cmd_status == 0 )) || return $cmd_status

  "$methodology_home/methodology-entry.sh" "$target" || return 1

  if "$methodology_home/methodology-audit.sh" --summary "$target"; then
    :
  else
    echo "Methodology update completed with audit warnings summarized above."
  fi

  after_state="$(_methodology_capture_state "$target")"
  _methodology_report_changes "$before_state" "$after_state"
}

madopt() {
  local methodology_home target
  methodology_home="$(_methodology_resolve_home)" || {
    echo "METHODOLOGY_HOME is not set. Run install-toolkit.sh first." >&2
    return 1
  }
  target="${1:-.}"
  _methodology_fix_perms_if_needed "$target"
  "$methodology_home/adopt-methodology.sh" "$target" && _methodology_fix_perms_if_needed "$target" && cd "$target"
}
