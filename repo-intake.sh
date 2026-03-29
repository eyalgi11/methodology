#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: repo-intake.sh [--json] [--no-write] [target-directory]

Detects repo characteristics and updates methodology docs with auto-detected
sections for commands, repo map, architecture, and dependencies.
EOF
}

json_mode=0
write_mode=1
target_arg=""

while (($# > 0)); do
  case "$1" in
    --json)
      json_mode=1
      shift
      ;;
    --no-write)
      write_mode=0
      shift
      ;;
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

stack=()
key_dirs=()
entrypoints=()
important_state=()
dependency_items=()

install_cmd=""
init_env_cmd=""
start_app_cmd=""
start_backend_cmd=""
start_workers_cmd=""
health_cmd=""
preflight_cmd=""
canonical_db="n/a"
db_reset_cmd="n/a"
unit_test_cmd=""
integration_test_cmd=""
e2e_test_cmd=""
browser_test_cmd=""
mobile_test_cmd=""
desktop_test_cmd=""
lint_cmd=""
typecheck_cmd=""
format_check_cmd=""
build_cmd=""
release_cmd=""
package_manager=""
purpose_summary=""
background_services="n/a"

detect_package_manager() {
  if [[ -f "$target_dir/pnpm-lock.yaml" ]]; then
    printf 'pnpm'
  elif [[ -f "$target_dir/yarn.lock" ]]; then
    printf 'yarn'
  elif [[ -f "$target_dir/bun.lockb" || -f "$target_dir/bun.lock" ]]; then
    printf 'bun'
  elif [[ -f "$target_dir/package-lock.json" ]]; then
    printf 'npm'
  elif [[ -f "$target_dir/package.json" ]]; then
    printf 'npm'
  elif [[ -f "$target_dir/uv.lock" ]]; then
    printf 'uv'
  elif [[ -f "$target_dir/poetry.lock" ]]; then
    printf 'poetry'
  elif [[ -f "$target_dir/requirements.txt" ]]; then
    printf 'pip'
  elif [[ -f "$target_dir/Cargo.toml" ]]; then
    printf 'cargo'
  elif [[ -f "$target_dir/go.mod" ]]; then
    printf 'go'
  else
    printf 'unknown'
  fi
}

run_node_package_reader() {
  local expr="$1"
  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi

  (cd "$target_dir" && node -e "$expr") 2>/dev/null || true
}

package_manager="$(detect_package_manager)"

if [[ -f "$target_dir/package.json" ]]; then
  stack+=("Node.js")
  if [[ -f "$target_dir/tsconfig.json" ]] || find "$target_dir" -path "$target_dir/node_modules" -prune -o -type f \( -name '*.ts' -o -name '*.tsx' \) | grep -q .; then
    stack+=("TypeScript")
  fi

  purpose_summary="JavaScript/TypeScript application"

  case "$package_manager" in
    npm) install_cmd="npm install" ;;
    pnpm) install_cmd="pnpm install" ;;
    yarn) install_cmd="yarn install" ;;
    bun) install_cmd="bun install" ;;
    *) install_cmd="npm install" ;;
  esac

  pm_run() {
    local script_name="$1"
    case "$package_manager" in
      npm|pnpm) printf '%s run %s' "$package_manager" "$script_name" ;;
      yarn) printf 'yarn %s' "$script_name" ;;
      bun) printf 'bun run %s' "$script_name" ;;
      *) printf 'npm run %s' "$script_name" ;;
    esac
  }

  has_script() {
    local script_name="$1"
    local found
    found="$(run_node_package_reader "const p=require('./package.json'); process.stdout.write((p.scripts && p.scripts['$script_name']) ? 'yes' : '');")"
    [[ "$found" == "yes" ]]
  }

  detect_script_command() {
    local script_name="$1"
    if has_script "$script_name"; then
      pm_run "$script_name"
    fi
  }

  detect_first_script_command() {
    local script_name
    for script_name in "$@"; do
      if has_script "$script_name"; then
        pm_run "$script_name"
        return 0
      fi
    done
    return 1
  }

  start_app_cmd="$(detect_script_command dev || true)"
  if [[ -z "$start_app_cmd" ]]; then
    start_app_cmd="$(detect_script_command start || true)"
  fi
  start_backend_cmd="$(detect_script_command server || true)"
  if [[ -z "$start_backend_cmd" ]]; then
    start_backend_cmd="$(detect_script_command api || true)"
  fi
  start_workers_cmd="$(detect_script_command worker || true)"
  unit_test_cmd="$(detect_script_command test || true)"
  integration_test_cmd="$(detect_script_command test:integration || true)"
  e2e_test_cmd="$(detect_script_command test:e2e || true)"
  browser_test_cmd="$(detect_first_script_command test:browser test:web test:ui || true)"
  mobile_test_cmd="$(detect_first_script_command test:mobile test:device test:appium test:android || true)"
  desktop_test_cmd="$(detect_first_script_command test:desktop test:electron test:tauri test:macos test:windows || true)"
  health_cmd="$(detect_first_script_command health healthcheck doctor check:health || true)"
  preflight_cmd="$(detect_first_script_command preflight doctor setup:check check:env || true)"
  lint_cmd="$(detect_script_command lint || true)"
  typecheck_cmd="$(detect_script_command typecheck || true)"
  if [[ -z "$typecheck_cmd" ]]; then
    typecheck_cmd="$(detect_script_command type-check || true)"
  fi
  format_check_cmd="$(detect_script_command format:check || true)"
  if [[ -z "$format_check_cmd" ]]; then
    format_check_cmd="$(detect_script_command check:format || true)"
  fi
  build_cmd="$(detect_script_command build || true)"
  release_cmd="$(detect_script_command release || true)"

  while IFS= read -r item; do
    [[ -n "$item" ]] && dependency_items+=("$item")
  done < <(
    run_node_package_reader '
      const p=require("./package.json");
      const deps=Object.keys({...p.dependencies, ...p.devDependencies}).slice(0, 12);
      process.stdout.write(deps.join("\n"));
    '
  )

  package_main="$(run_node_package_reader 'const p=require("./package.json"); process.stdout.write(p.main || "");')"
  if [[ -n "$package_main" ]]; then
    entrypoints+=("$package_main")
  fi
fi

if [[ -f "$target_dir/Makefile" ]]; then
  install_cmd="${install_cmd:-make install}"
  start_app_cmd="${start_app_cmd:-make dev}"
  unit_test_cmd="${unit_test_cmd:-make test}"
  build_cmd="${build_cmd:-make build}"
fi

if [[ -f "$target_dir/Justfile" || -f "$target_dir/justfile" ]]; then
  install_cmd="${install_cmd:-just install}"
  start_app_cmd="${start_app_cmd:-just dev}"
  unit_test_cmd="${unit_test_cmd:-just test}"
  build_cmd="${build_cmd:-just build}"
fi

if [[ -f "$target_dir/docker-compose.yml" || -f "$target_dir/docker-compose.yaml" || -f "$target_dir/compose.yml" || -f "$target_dir/compose.yaml" ]]; then
  init_env_cmd="${init_env_cmd:-docker compose up -d}"
  preflight_cmd="${preflight_cmd:-docker compose ps}"
  background_services="docker compose services"
fi

deps_lower="$(printf '%s\n' "${dependency_items[@]:-}" | tr '[:upper:]' '[:lower:]')"
if printf '%s' "$deps_lower" | grep -Eq 'playwright|@playwright/test'; then
  browser_test_cmd="${browser_test_cmd:-${package_manager:-npm} run test:e2e}"
fi
if printf '%s' "$deps_lower" | grep -Eq 'cypress'; then
  browser_test_cmd="${browser_test_cmd:-${package_manager:-npm} run cypress}"
fi
if printf '%s' "$deps_lower" | grep -Eq 'appium|webdriverio'; then
  mobile_test_cmd="${mobile_test_cmd:-${package_manager:-npm} run test:appium}"
fi
if printf '%s' "$deps_lower" | grep -Eq 'electron|electron-builder|tauri'; then
  desktop_test_cmd="${desktop_test_cmd:-${package_manager:-npm} run test:desktop}"
fi

if [[ -f "$target_dir/pnpm-workspace.yaml" ]]; then
  start_app_cmd="${start_app_cmd:-pnpm -r dev}"
  unit_test_cmd="${unit_test_cmd:-pnpm -r test}"
  build_cmd="${build_cmd:-pnpm -r build}"
fi

if [[ -f "$target_dir/pyproject.toml" || -f "$target_dir/requirements.txt" ]]; then
  stack+=("Python")
  if [[ -z "$purpose_summary" ]]; then
    purpose_summary="Python application"
  fi

  case "$package_manager" in
    uv)
      install_cmd="${install_cmd:-uv sync}"
      unit_test_cmd="${unit_test_cmd:-uv run pytest}"
      lint_cmd="${lint_cmd:-uv run ruff check .}"
      typecheck_cmd="${typecheck_cmd:-uv run pyright}"
      ;;
    poetry)
      install_cmd="${install_cmd:-poetry install}"
      unit_test_cmd="${unit_test_cmd:-poetry run pytest}"
      lint_cmd="${lint_cmd:-poetry run ruff check .}"
      typecheck_cmd="${typecheck_cmd:-poetry run pyright}"
      ;;
    pip|unknown)
      if [[ -f "$target_dir/requirements.txt" ]]; then
        install_cmd="${install_cmd:-pip install -r requirements.txt}"
      fi
      unit_test_cmd="${unit_test_cmd:-pytest}"
      lint_cmd="${lint_cmd:-ruff check .}"
      typecheck_cmd="${typecheck_cmd:-pyright}"
      ;;
  esac

  if [[ -f "$target_dir/main.py" ]]; then
    entrypoints+=("main.py")
  fi
  if [[ -f "$target_dir/manage.py" ]]; then
    entrypoints+=("manage.py")
  fi
fi

if [[ -f "$target_dir/Cargo.toml" ]]; then
  stack+=("Rust")
  package_manager="cargo"
  purpose_summary="${purpose_summary:-Rust application}"
  install_cmd="${install_cmd:-cargo fetch}"
  unit_test_cmd="${unit_test_cmd:-cargo test}"
  lint_cmd="${lint_cmd:-cargo clippy --all-targets --all-features -- -D warnings}"
  build_cmd="${build_cmd:-cargo build}"
  if [[ -f "$target_dir/src/main.rs" ]]; then
    entrypoints+=("src/main.rs")
  fi
fi

if [[ -f "$target_dir/go.mod" ]]; then
  stack+=("Go")
  package_manager="go"
  purpose_summary="${purpose_summary:-Go application}"
  unit_test_cmd="${unit_test_cmd:-go test ./...}"
  build_cmd="${build_cmd:-go build ./...}"
  if [[ -f "$target_dir/main.go" ]]; then
    entrypoints+=("main.go")
  fi
fi

candidate_dirs=(src app backend frontend server api tests test packages libs components scripts prisma db migrations)
for dir_name in "${candidate_dirs[@]}"; do
  if [[ -d "$target_dir/$dir_name" ]]; then
    key_dirs+=("$dir_name/")
  fi
done

while IFS= read -r relpath; do
  [[ -n "$relpath" ]] && entrypoints+=("$relpath")
done < <(
  find "$target_dir" \
    \( -type d \( -name .git -o -name node_modules -o -name .next -o -name dist -o -name build -o -name target \) -prune \) -o \
    -type f \( \
      -name 'index.ts' -o -name 'index.tsx' -o -name 'main.ts' -o -name 'main.tsx' -o \
      -name 'index.js' -o -name 'main.js' -o -name 'server.ts' -o -name 'server.js' -o \
      -name 'app.ts' -o -name 'app.js' -o -name 'main.py' -o -name 'manage.py' -o \
      -name 'main.rs' -o -name 'main.go' \
    \) -printf '%P\n' 2>/dev/null | awk 'NR <= 8'
)

important_candidates=(.env .env.example .env.local docker-compose.yml docker-compose.yaml compose.yml compose.yaml tsconfig.json pyproject.toml Cargo.toml go.mod prisma/schema.prisma)
for file_name in "${important_candidates[@]}"; do
  if [[ -f "$target_dir/$file_name" ]]; then
    important_state+=("$file_name")
  fi
done

if [[ ${#stack[@]} -eq 0 ]]; then
  stack+=("Undetermined")
  purpose_summary="Repository shape could not be confidently detected"
fi

dedupe_lines() {
  awk '!seen[$0]++'
}

if [[ ${#entrypoints[@]} -gt 0 ]]; then
  mapfile -t entrypoints < <(printf '%s\n' "${entrypoints[@]}" | dedupe_lines | awk 'NR <= 10')
fi
if [[ ${#dependency_items[@]} -gt 0 ]]; then
  mapfile -t dependency_items < <(printf '%s\n' "${dependency_items[@]}" | dedupe_lines | awk 'NR <= 12')
fi

build_body() {
  local title="$1"
  shift
  printf -- '- Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf -- '- Source: %s\n' "$title"
  while (($# > 0)); do
    printf '%s\n' "$1"
    shift
  done
}

ensure_doc_from_template() {
  local file_path="$1"
  local template_name="$2"
  local template_path="$SCRIPT_DIR/$template_name"

  if [[ -f "$file_path" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$file_path")"
  if [[ -f "$template_path" ]]; then
    cp "$template_path" "$file_path"
    return 0
  fi

  printf '# %s\n' "${template_name%.md}" > "$file_path"
}

stack_joined="$(printf '%s, ' "${stack[@]}")"
stack_joined="${stack_joined%, }"

commands_body="$(build_body "repo-intake.sh" \
  "- Detected package manager: ${package_manager}" \
  "- Install dependencies: ${install_cmd:-n/a}" \
  "- Initialize local environment: ${init_env_cmd:-n/a}" \
  "- Canonical dev database: ${canonical_db:-n/a}" \
  "- Disposable DB reset command: ${db_reset_cmd:-n/a}" \
  "- Required background services: ${background_services}" \
  "- Start app: ${start_app_cmd:-n/a}" \
  "- Start backend: ${start_backend_cmd:-n/a}" \
  "- Start workers: ${start_workers_cmd:-n/a}" \
  "- Health / preflight command: ${health_cmd:-${preflight_cmd:-n/a}}" \
  "- Unit tests: ${unit_test_cmd:-n/a}" \
  "- Integration tests: ${integration_test_cmd:-n/a}" \
  "- End-to-end tests: ${e2e_test_cmd:-n/a}" \
  "- Browser automation: ${browser_test_cmd:-n/a}" \
  "- Mobile automation: ${mobile_test_cmd:-n/a}" \
  "- Desktop automation: ${desktop_test_cmd:-n/a}" \
  "- Lint: ${lint_cmd:-n/a}" \
  "- Type-check: ${typecheck_cmd:-n/a}" \
  "- Format check: ${format_check_cmd:-n/a}" \
  "- Production build: ${build_cmd:-n/a}" \
  "- Release command: ${release_cmd:-n/a}")"

repo_map_lines=(
  "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  "- Detected stack: ${stack_joined}"
  "- Purpose summary: ${purpose_summary}"
)
if [[ ${#key_dirs[@]} -gt 0 ]]; then
  repo_map_lines+=("- Key directories: $(printf '%s, ' "${key_dirs[@]}" | sed 's/, $//')")
fi
if [[ ${#entrypoints[@]} -gt 0 ]]; then
  repo_map_lines+=("- Entrypoints: $(printf '%s, ' "${entrypoints[@]}" | sed 's/, $//')")
fi
if [[ ${#important_state[@]} -gt 0 ]]; then
  repo_map_lines+=("- Important state/config: $(printf '%s, ' "${important_state[@]}" | sed 's/, $//')")
fi
repo_map_body="$(printf '%s\n' "${repo_map_lines[@]}")"

architecture_lines=(
  "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  "- Runtime stack: ${stack_joined}"
  "- Package manager: ${package_manager}"
)
if [[ -n "$start_app_cmd" ]]; then
  architecture_lines+=("- Primary application run path: ${start_app_cmd}")
fi
if [[ -n "$start_backend_cmd" ]]; then
  architecture_lines+=("- Primary backend run path: ${start_backend_cmd}")
fi
if [[ ${#key_dirs[@]} -gt 0 ]]; then
  architecture_lines+=("- Main code areas: $(printf '%s, ' "${key_dirs[@]}" | sed 's/, $//')")
fi
architecture_body="$(printf '%s\n' "${architecture_lines[@]}")"

dependency_lines=(
  "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  "- Package manager / build tool: ${package_manager}"
)
if [[ ${#dependency_items[@]} -gt 0 ]]; then
  dependency_lines+=("- Detected dependencies: $(printf '%s, ' "${dependency_items[@]}" | sed 's/, $//')")
else
  dependency_lines+=("- Detected dependencies: none auto-detected")
fi
dependencies_body="$(printf '%s\n' "${dependency_lines[@]}")"

update_commands_file() {
  local file_path="$1"
  local map_file
  map_file="$(mktemp)"
  cat > "$map_file" <<EOF
Setup	Install dependencies	${install_cmd:-}
Setup	Initialize local environment	${init_env_cmd:-}
Run	Start app	${start_app_cmd:-}
Run	Start backend	${start_backend_cmd:-}
Run	Start workers	${start_workers_cmd:-}
Test	Unit tests	${unit_test_cmd:-}
Test	Integration tests	${integration_test_cmd:-}
Test	End-to-end tests	${e2e_test_cmd:-}
Test	Browser automation	${browser_test_cmd:-}
Test	Mobile automation	${mobile_test_cmd:-}
Test	Desktop automation	${desktop_test_cmd:-}
Quality	Lint	${lint_cmd:-}
Quality	Type-check	${typecheck_cmd:-}
Quality	Format check	${format_check_cmd:-}
Build / Release	Production build	${build_cmd:-}
Build / Release	Release command	${release_cmd:-}
EOF

  python3 - "$file_path" "$map_file" <<'PY'
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
mapping_path = Path(sys.argv[2])
mapping = {}
for raw_line in mapping_path.read_text().splitlines():
    if not raw_line.strip():
        continue
    section, label, value = raw_line.split("\t", 2)
    mapping[(section, label)] = value

lines = file_path.read_text().splitlines()
section = None
updated = []
for line in lines:
    if line.startswith("## "):
        section = line[3:]
        updated.append(line)
        continue

    if line.startswith("- ") and ":" in line and section is not None:
        label, _ = line[2:].split(":", 1)
        label = label.strip()
        replacement = mapping.get((section, label))
        if replacement is not None:
          updated.append(f"- {label}: {replacement}")
          continue

    updated.append(line)

file_path.write_text("\n".join(updated) + "\n")
PY

  rm -f "$map_file"
}

if (( write_mode == 1 )); then
  commands_file="$(project_file_path "$target_dir" "COMMANDS.md")"
  repo_map_file="$(project_file_path "$target_dir" "REPO_MAP.md")"
  architecture_file="$(project_file_path "$target_dir" "ARCHITECTURE.md")"
  dependencies_file="$(project_file_path "$target_dir" "DEPENDENCIES.md")"
  ensure_doc_from_template "$commands_file" "COMMANDS.md"
  ensure_doc_from_template "$repo_map_file" "REPO_MAP.md"
  ensure_doc_from_template "$architecture_file" "ARCHITECTURE.md"
  ensure_doc_from_template "$dependencies_file" "DEPENDENCIES.md"
  update_commands_file "$commands_file"
  append_or_replace_auto_section "$commands_file" "repo-intake" "## Auto-Detected Commands" "$commands_body"
  append_or_replace_auto_section "$repo_map_file" "repo-intake" "## Auto-Detected Snapshot" "$repo_map_body"
  append_or_replace_auto_section "$architecture_file" "repo-intake" "## Auto-Detected Snapshot" "$architecture_body"
  append_or_replace_auto_section "$dependencies_file" "repo-intake" "## Auto-Detected Snapshot" "$dependencies_body"
fi

if (( json_mode == 1 )); then
  stack_json=()
  map_json=()
  deps_json=()
  stack_json=("${stack[@]}")
  map_json=("${key_dirs[@]}")
  deps_json=("${dependency_items[@]}")
  printf '{'
  printf '"target":"%s",' "$(json_escape "$target_dir")"
  printf '"write_mode":%s,' "$( (( write_mode == 1 )) && printf true || printf false )"
  printf '"package_manager":"%s",' "$(json_escape "$package_manager")"
  printf '"stack":'
  print_json_array stack_json
  printf ','
  printf '"key_directories":'
  print_json_array map_json
  printf ','
  printf '"dependencies":'
  print_json_array deps_json
  printf ','
  printf '"entrypoints":'
  print_json_array entrypoints
  printf '}\n'
else
  echo "Repo intake complete for $target_dir"
  echo "Detected stack: $stack_joined"
  echo "Detected package manager: $package_manager"
  if (( write_mode == 1 )); then
    echo "Updated: COMMANDS.md, REPO_MAP.md, ARCHITECTURE.md, DEPENDENCIES.md"
  else
    echo "No files were modified."
  fi
fi
"$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
