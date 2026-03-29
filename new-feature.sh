#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: new-feature.sh --title "Feature title" [options] [target-directory]

Creates a new feature spec in methodology/features/, adds a planned task, and
links the feature from SESSION_STATE.md.

Options:
  --title TEXT       Feature title (required)
  --slug TEXT        Explicit spec slug
  --story TEXT       User story summary
  --json             Print machine-readable output
EOF
}

target_arg=""
title=""
slug=""
story=""
json_mode=0

while (($# > 0)); do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --slug) slug="$2"; shift 2 ;;
    --story) story="$2"; shift 2 ;;
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
        usage >&2
        exit 1
      fi
      target_arg="$1"
      shift
      ;;
  esac
done

if [[ -z "$title" ]]; then
  echo "--title is required." >&2
  usage >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
mkdir -p "$(project_file_path "$target_dir" "features")"

if [[ -z "$slug" ]]; then
  slug="$(slugify "$title")"
fi

base_name="$(today_date)-${slug}"
spec_relpath="features/${base_name}.md"
suffix=1
while [[ -e "$(project_file_path "$target_dir" "$spec_relpath")" ]]; do
  spec_relpath="features/${base_name}-${suffix}.md"
  suffix=$((suffix + 1))
done

if [[ -z "$story" ]]; then
  story="As the target user, I want ${title}, so the project moves forward with a clearly defined scope."
fi

python3 - "$SCRIPT_DIR/templates/FEATURE_SPEC_TEMPLATE.md" "$(project_file_path "$target_dir" "$spec_relpath")" "$title" "$story" <<'PY'
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
title = sys.argv[3]
story = sys.argv[4]
text = template_path.read_text().splitlines()

out = []
in_user_story = False
story_written = False
for i, line in enumerate(text):
    if i == 0 and line.startswith("# "):
        out.append(f"# {title}")
        continue
    if line == "## User Story":
        in_user_story = True
        out.append(line)
        out.append(f"- {story}")
        story_written = True
        continue
    if in_user_story:
        if line.startswith("## "):
          in_user_story = False
          out.append(line)
        else:
          continue
        continue
    out.append(line)

if not story_written:
    out.extend(["", "## User Story", f"- {story}"])

output_path.write_text("\n".join(out).rstrip() + "\n")
PY

python3 - "$(project_file_path "$target_dir" "TASKS.md")" "$title" "$spec_relpath" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
title = sys.argv[2]
spec_relpath = sys.argv[3]
entry = f"- [ ] {title} ({spec_relpath})"
text = path.read_text() if path.exists() else "# Tasks\n\n## Planned\n\n## Ready\n\n## In Progress\n\n## Blocked\n\n## Done\n\n## Cancelled\n"
lines = text.splitlines()
out = []
inserted = False
in_planned = False
for line in lines:
    out.append(line)
    if line == "## Planned":
        in_planned = True
        continue
    if in_planned and line.startswith("## ") and not inserted:
        out.insert(len(out) - 1, entry)
        inserted = True
        in_planned = False

if not inserted:
    if "## Planned" not in lines:
        if out and out[-1] != "":
            out.append("")
        out.extend(["## Planned", entry])
    else:
        out.append(entry)

path.write_text("\n".join(out) + "\n")
PY

feature_body=$(cat <<EOF
- Created: $(timestamp_now)
- Title: ${title}
- Spec: ${spec_relpath}
- Task entry: ${title}
EOF
)
append_or_replace_auto_section "$(project_file_path "$target_dir" "SESSION_STATE.md")" "active-feature" "## Active Feature" "$feature_body"

if (( json_mode == 1 )); then
  printf '{"target":"%s","title":"%s","spec":"%s"}\n' \
    "$(json_escape "$target_dir")" \
    "$(json_escape "$title")" \
    "$(json_escape "$spec_relpath")"
else
  echo "Created feature spec: $spec_relpath"
  echo "Updated: TASKS.md, SESSION_STATE.md"
fi
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
