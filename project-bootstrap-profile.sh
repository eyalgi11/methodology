#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: project-bootstrap-profile.sh [--git] <profile> <target-directory>

Supported profiles:
  saas-web
  api-service
  internal-tool
  mobile-backend
  monorepo
  agent-service
  desktop-app
  cli-tooling
  data-pipeline
EOF
}

init_git=0
profile=""
target_dir=""

while (($# > 0)); do
  case "$1" in
    --git) init_git=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$profile" ]]; then
        profile="$1"
      elif [[ -z "$target_dir" ]]; then
        target_dir="$1"
      else
        echo "Too many arguments." >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$profile" || -z "$target_dir" ]]; then
  usage >&2
  exit 1
fi

stack=""
brief_summary=""
work_type=""
verification_summary=""
commands_summary=""
case "$profile" in
  saas-web)
    stack="next"
    brief_summary="SaaS web application with product, billing, and operational concerns."
    work_type="product"
    verification_summary="Browser automation is first-class. Expect cold-start web checks, end-to-end browser automation, and rollout/rollback thinking for user-facing changes."
    commands_summary=$'- Browser automation: npm run e2e\n- End-to-end tests: npm run e2e\n- Health / preflight command: curl -fsS http://localhost:3000 || npm run dev'
    ;;
  api-service)
    stack="fastapi"
    brief_summary="Backend/API service with operational, auth, and integration concerns."
    work_type="product"
    verification_summary="API health checks, integration tests, and schema/runtime verification should be first-class. Prefer cold-start preflight plus health endpoint verification."
    commands_summary=$'- Integration tests: pytest\n- Health / preflight command: curl -fsS http://localhost:8000/health\n- Browser automation: n/a'
    ;;
  internal-tool)
    stack="vite"
    brief_summary="Internal productivity tool with lightweight UI and operational workflows."
    work_type="product"
    verification_summary="Browser automation is expected when the UI meaningfully changes, but release discipline can stay lighter unless the tool becomes operationally critical."
    commands_summary=$'- Browser automation: npm run e2e\n- End-to-end tests: npm run e2e\n- Health / preflight command: npm run dev'
    ;;
  mobile-backend)
    stack="express"
    brief_summary="Backend service intended to support a mobile client application."
    work_type="product"
    verification_summary="Device workflows matter even if this repo is backend-only. Keep API health checks plus explicit mobile/device verification expectations for dependent client flows."
    commands_summary=$'- Integration tests: npm test\n- Mobile automation: appium-mobile\n- Health / preflight command: curl -fsS http://localhost:3000/health'
    ;;
  monorepo)
    stack="node-cli"
    brief_summary="Workspace-style monorepo intended to host multiple packages, apps, or services behind one operating model."
    work_type="infra"
    verification_summary="Verification should be workspace-aware: package-scoped smoke checks, cross-package integration checks, and a clear canonical package-manager entrypoint."
    commands_summary=$'- Setup: pnpm install\n- Test: pnpm -r test\n- Browser automation: add package-scoped command when a web app exists\n- Health / preflight command: pnpm -r --if-present test'
    ;;
  agent-service)
    stack="fastapi"
    brief_summary="Agent-facing or model-driven backend service with tool use, eval discipline, and runtime cost/latency concerns."
    work_type="product"
    verification_summary="Keep API health checks, eval/golden-task verification, cost/latency budgets, and confirmation-required tool boundaries visible from the start."
    commands_summary=$'- Integration tests: pytest\n- End-to-end tests: pytest\n- Health / preflight command: curl -fsS http://localhost:8000/health\n- Browser automation: n/a'
    ;;
  desktop-app)
    stack="vite"
    brief_summary="Desktop application with browser-tech or shell-hosted UI where release, update, and automation expectations differ from a plain web app."
    work_type="product"
    verification_summary="Desktop automation is first-class. Use Playwright/Electron for browser-tech desktop apps or native desktop automation where relevant, and keep packaging/run commands explicit."
    commands_summary=$'- Desktop automation: npm run desktop:e2e\n- Browser automation: npm run desktop:e2e\n- Health / preflight command: npm run dev'
    ;;
  cli-tooling)
    stack="node-cli"
    brief_summary="CLI or developer-tooling project where reproducibility, sample inputs, and exit-code behavior matter more than UI polish."
    work_type="maintenance"
    verification_summary="Verification should focus on deterministic command output, sample fixtures, exit codes, and shell-safe usage from a cold start."
    commands_summary=$'- Test: npm test\n- End-to-end tests: node src/index.js --help\n- Health / preflight command: node src/index.js --help'
    ;;
  data-pipeline)
    stack="node-cli"
    brief_summary="Batch, ETL, or pipeline-style project where idempotence, checkpoints, and data-quality verification are part of normal done criteria."
    work_type="infra"
    verification_summary="Verification should focus on dry runs, fixture-backed sample datasets, idempotence, failure recovery, and explicit cleanup/reset commands."
    commands_summary=$'- Test: npm test\n- Integration tests: npm test\n- Health / preflight command: node src/index.js --help\n- Cleanup / Reset: add fixture reset and output cleanup commands'
    ;;
  *)
    echo "Unsupported profile: $profile" >&2
    exit 1
    ;;
esac

if (( init_git == 1 )); then
  "$SCRIPT_DIR/scaffold-stack.sh" --git "$stack" "$target_dir" >/dev/null
else
  "$SCRIPT_DIR/scaffold-stack.sh" "$stack" "$target_dir" >/dev/null
fi
source "$SCRIPT_DIR/methodology-common.sh"
resolved_target_dir="$(resolve_target_dir "$target_dir")"
project_brief_file="$(project_file_path "$resolved_target_dir" "PROJECT_BRIEF.md")"
commands_file="$(project_file_path "$resolved_target_dir" "COMMANDS.md")"

brief_body=$(cat <<EOF
- Bootstrap profile: ${profile}
- Recommended stack scaffold: ${stack}
- Summary: ${brief_summary}
- Default work type: ${work_type}
- Verification expectations: ${verification_summary}
EOF
)
commands_body=$(cat <<EOF
- Profile: ${profile}
- Stack scaffold: ${stack}
- Default work type: ${work_type}
- Verification expectations: ${verification_summary}
${commands_summary}
EOF
)
"$SCRIPT_DIR/auto-update-from-git.sh" "$resolved_target_dir" >/dev/null 2>&1 || true
append_or_replace_auto_section "$project_brief_file" "bootstrap-profile" "## Bootstrap Profile" "$brief_body"
append_or_replace_auto_section "$commands_file" "bootstrap-profile" "## Bootstrap Profile Defaults" "$commands_body"

python3 - "$project_brief_file" "$work_type" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
work_type = sys.argv[2]
lines = path.read_text().splitlines()
out = []
in_target = False

for line in lines:
    if line == "## Work Type":
        out.append(line)
        out.append("")
        out.append(work_type)
        in_target = True
        continue
    if in_target:
        if line.startswith("## "):
            out.append("")
            out.append(line)
            in_target = False
        else:
            continue
    else:
        out.append(line)

path.write_text("\n".join(out).rstrip() + "\n")
PY

echo "Bootstrapped profile $profile at $target_dir"
echo "Base stack: $stack"
