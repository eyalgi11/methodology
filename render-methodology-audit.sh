#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: render-methodology-audit.sh [--output path] [target-directory]

Generate a static HTML methodology audit dashboard from real repo state.

Defaults:
  target-directory: current working directory
  output path:      <target-directory>/methodology/methodology-audit.html
                     or <target-directory>/methodology-audit.html when the
                     target is the methodology source repo itself
EOF
}

target_arg=""
output_arg=""

while (($# > 0)); do
  case "$1" in
    --output)
      shift
      [[ $# -gt 0 ]] || { echo "--output requires a path" >&2; exit 1; }
      output_arg="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
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

target_dir="${target_arg:-$PWD}"
if [[ ! -d "$target_dir" ]]; then
  echo "Target directory does not exist: $target_dir" >&2
  exit 1
fi
target_dir="$(cd "$target_dir" && pwd)"
if [[ -n "$output_arg" ]]; then
  output_path="$output_arg"
elif [[ -d "$target_dir/methodology" ]]; then
  output_path="$target_dir/methodology/methodology-audit.html"
else
  output_path="$target_dir/methodology-audit.html"
fi
mkdir -p "$(dirname "$output_path")"

python3 - "$SCRIPT_DIR" "$target_dir" "$output_path" <<'PY'
import datetime as dt
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path

script_dir = Path(sys.argv[1])
target_dir = Path(sys.argv[2])
output_path = Path(sys.argv[3])


def run_json_check(name, cmd):
    proc = subprocess.run(cmd, text=True, capture_output=True)
    stdout = proc.stdout.strip()
    stderr = proc.stderr.strip()
    data = None
    if stdout:
        for line in reversed(stdout.splitlines()):
            line = line.strip()
            if line.startswith("{") and line.endswith("}"):
                try:
                    data = json.loads(line)
                    break
                except json.JSONDecodeError:
                    continue
    return {
        "name": name,
        "command": cmd,
        "returncode": proc.returncode,
        "ok": proc.returncode == 0,
        "data": data,
        "stdout": stdout,
        "stderr": stderr,
    }


def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return {}


def methodology_root(target: Path):
    project_methodology = target / "methodology"
    if project_methodology.is_dir():
        return project_methodology
    return target


def extract_auto_section_labels(path: Path, section_id: str):
    if not path.exists():
        return {}
    start = f"<!-- AUTO:START {section_id} -->"
    end = f"<!-- AUTO:END {section_id} -->"
    in_block = False
    labels = {}
    for raw in path.read_text().splitlines():
        line = raw.rstrip()
        if line == start:
            in_block = True
            continue
        if line == end:
            in_block = False
            continue
        if not in_block:
            continue
        if line.startswith("- ") and ":" in line:
            key, value = line[2:].split(":", 1)
            labels[key.strip()] = value.strip()
    return labels


def parse_user_facing_lists(path: Path):
    sections = {}
    current = None
    if not path.exists():
        return sections
    for raw in path.read_text().splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
            continue
        if current and line.startswith("- `"):
            item = line.split("`", 2)[1]
            sections[current].append(item)
    return sections


def split_loaded_docs(raw):
    if not raw or raw == "none recorded":
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


def count_root_owned(root: Path):
    skip_dirs = {
        ".git",
        "node_modules",
        ".next",
        "dist",
        "build",
        "coverage",
        ".turbo",
        ".cache",
        "vendor",
        "venv",
        ".venv",
        "__pycache__",
    }
    count = 0
    sample = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for filename in filenames:
            path = Path(dirpath) / filename
            try:
                stat = path.stat()
            except OSError:
                continue
            if stat.st_uid == 0:
                count += 1
                if len(sample) < 12:
                    sample.append(str(path.relative_to(root)))
    return count, sample


methodology_dir = methodology_root(target_dir)
os.environ["METHODOLOGY_DASHBOARD_SKIP_DRIFT"] = "1"

checks = {
    "dashboard": run_json_check("dashboard", [str(script_dir / "project-dashboard.sh"), "--json", str(target_dir)]),
    "drift": run_json_check("drift", [str(script_dir / "drift-check.sh"), "--json", str(target_dir)]),
    "observable": run_json_check("observable", [str(script_dir / "observable-compliance-check.sh"), "--json", str(target_dir)]),
    "status": run_json_check("status", [str(script_dir / "methodology-status.sh"), "--json", str(target_dir)]),
    "audit": run_json_check("audit", [str(script_dir / "methodology-audit.sh"), "--json", str(target_dir)]),
    "mode": run_json_check("mode", [str(script_dir / "mode-check.sh"), "--json", "--light", str(target_dir)]),
    "metrics": run_json_check("metrics", [str(script_dir / "metrics-check.sh"), "--json", "--no-write", str(target_dir)]),
    "stale_claims": run_json_check("stale_claims", [str(script_dir / "stale-claims-check.sh"), "--json", str(target_dir)]),
}

state = read_json(methodology_dir / "methodology-state.json")
session_labels = extract_auto_section_labels(methodology_dir / "SESSION_STATE.md", "observable-compliance")
handoff_labels = extract_auto_section_labels(methodology_dir / "HANDOFF.md", "observable-compliance")
user_facing = parse_user_facing_lists(script_dir / "reference" / "USER_FACING_FILES.md")
root_owned_count, root_owned_sample = count_root_owned(target_dir)

dashboard = checks["dashboard"]["data"] or {}
drift = checks["drift"]["data"] or {}
observable = checks["observable"]["data"] or {}
status = checks["status"]["data"] or {}
audit = checks["audit"]["data"] or {}
mode = checks["mode"]["data"] or {}
metrics = checks["metrics"]["data"] or {}
stale_claims = checks["stale_claims"]["data"] or {}

target = dashboard.get("target") or str(target_dir)
repo_name = Path(target).name
mode_name = dashboard.get("mode") or state.get("maturity_mode") or "unknown"
work_type = dashboard.get("work_type") or state.get("work_type") or "unknown"
branch = dashboard.get("branch") or "n/a"
git_state = dashboard.get("git_state") or "unknown"
active_task = dashboard.get("active_task") or state.get("active_task") or "n/a"
active_state = dashboard.get("active_task_state") or state.get("active_task_state") or "n/a"
next_step = dashboard.get("next_step") or state.get("next_recommended_command") or "n/a"
business_owner = dashboard.get("business_owner") or state.get("business_owner") or session_labels.get("Business owner") or "n/a"
leading_metric = dashboard.get("leading_metric") or state.get("leading_metric") or session_labels.get("Leading metric") or "n/a"
customer_signal = dashboard.get("customer_signal") or state.get("customer_signal") or session_labels.get("Customer signal") or "n/a"
decision_deadline = dashboard.get("decision_deadline") or state.get("decision_deadline") or session_labels.get("Decision deadline") or "n/a"
risk_class = dashboard.get("active_risk_class") or state.get("active_risk_class") or handoff_labels.get("Risk class") or "n/a"
release_risk = dashboard.get("active_release_risk") or state.get("active_release_risk") or handoff_labels.get("Release risk") or "n/a"
verification_path = session_labels.get("Verification path") or state.get("verification_path") or "n/a"
spec_path = session_labels.get("Spec") or state.get("active_spec") or "n/a"
workspace_path = handoff_labels.get("Active workspace") or dashboard.get("active_task_workspace") or state.get("active_workspace_path") or "n/a"
delegation_policy = state.get("delegation_policy", "unknown")
is_template_source = mode_name == "template_source"
loaded_docs = split_loaded_docs(session_labels.get("Loaded docs") or handoff_labels.get("Loaded docs") or "")

required_control_docs = ["METHODOLOGY_PRINCIPLES.md", "DEFAULT_BEHAVIOR.md", "METHODOLOGY_CONTROL_LOOP.md"]
required_runtime_docs = ["TASKS.md", "SESSION_STATE.md", "HANDOFF.md"]
missing_control_docs = [doc for doc in required_control_docs if doc not in loaded_docs]
missing_runtime_docs = [doc for doc in required_runtime_docs if doc not in loaded_docs]

session_quality_reasons = []
session_quality = "good"
if not loaded_docs:
    session_quality = "bad"
    session_quality_reasons.append("No loaded-doc evidence is visible in the current observable checkpoint.")
if workspace_path == "n/a":
    session_quality = "bad"
    session_quality_reasons.append("The active workspace is not visible in the current checkpoint.")
if verification_path == "n/a":
    session_quality = "bad"
    session_quality_reasons.append("The verification path is not visible in the current checkpoint.")
if not is_template_source and not observable.get("ok", False):
    session_quality = "bad"
    session_quality_reasons.append("Observable compliance is currently failing.")
if is_template_source and missing_control_docs and session_quality != "bad":
    session_quality = "warn"
    session_quality_reasons.append(f"Missing control-surface docs in the current checkpoint: {', '.join(missing_control_docs)}.")
if not is_template_source and missing_runtime_docs and session_quality != "bad":
    session_quality = "warn"
    session_quality_reasons.append(f"Missing continuity docs in the current checkpoint: {', '.join(missing_runtime_docs)}.")
if not session_quality_reasons:
    session_quality_reasons.append("The current checkpoint shows task, workspace, verification, and the expected methodology control surface.")

proof_mode = "Source proof" if is_template_source else "Dogfood proof"
proof_scope = (
    "Toolkit correctness: templates, scripts, bootstrap, migration, registry, and packaging behavior."
    if is_template_source
    else "Lived workflow behavior: task flow, handoff quality, verification ergonomics, recovery, and day-to-day usability."
)
proof_expectation = (
    "Pair source-repo proof with the separate dogfood repo before treating a workflow claim as proven in practice."
    if is_template_source
    else "This repo is the lived-workflow proof surface. Use the source repo only for toolkit correctness claims."
)


def should_suppress_issue(source, issue):
    if not is_template_source:
        return False
    lowered = issue.lower()
    if source == "observable-compliance-check.sh":
        suppressed_phrases = (
            "session_state.md does not show observable methodology evidence yet",
            "handoff.md does not show observable methodology evidence yet",
            "observable compliance is missing real loaded-doc evidence",
            "observable compliance is missing a real verification path",
            "observable compliance is missing the work type",
            "observable compliance is missing the business owner",
            "observable compliance is missing the leading metric",
            "observable compliance is missing the customer signal",
            "observable compliance is missing the decision or review date",
        )
        return any(phrase in lowered for phrase in suppressed_phrases)
    if source == "drift-check.sh":
        suppressed_phrases = (
            "methodology usage is not visibly recorded in the current project state",
            "commands.md does not contain runnable commands yet",
            "process_exceptions.md has exceptions without a risk level",
            "process_exceptions.md has exceptions without a compensating control",
            "process_exceptions.md has exceptions without an owner",
            "process_exceptions.md has exceptions without an approver",
            "process_exceptions.md has exceptions without an expiry",
        )
        return any(phrase in lowered for phrase in suppressed_phrases)
    if source == "metrics-check.sh":
        return True
    return False


def status_level(ok: bool, warn_count: int = 0):
    if not ok:
        return "bad"
    if warn_count:
        return "warn"
    return "good"


combined_issue_rows = []


def add_issue(source, rule, observed, fix, severity="warn"):
    combined_issue_rows.append(
        {
            "source": source,
            "rule": rule,
            "observed": observed,
            "fix": fix,
            "severity": severity,
        }
    )


if audit.get("missing"):
    add_issue(
        "methodology-audit.sh",
        "Required methodology files should exist.",
        f"Missing files: {', '.join(audit['missing'][:8])}" + ("..." if len(audit["missing"]) > 8 else ""),
        "Bootstrap or adopt the methodology again, then fill the missing files that are actually part of the repo's active surface.",
        "bad",
    )

if audit.get("placeholder"):
    add_issue(
        "methodology-audit.sh",
        "Active repo docs should not stay as untouched placeholders indefinitely.",
        f"{len(audit['placeholder'])} docs still look untouched: {', '.join(audit['placeholder'][:6])}" + ("..." if len(audit["placeholder"]) > 6 else ""),
        "Either fill the docs that are genuinely active for this repo or reduce the active surface so placeholder-only docs stay optional.",
        "warn",
    )

for issue in drift.get("issues", []):
    if should_suppress_issue("drift-check.sh", issue):
        continue
    source = "drift-check.sh"
    fix = "Inspect the referenced file and update the visible state so the docs, checks, and repo reality match."
    severity = "warn"
    lower = issue.lower()
    if "process_exceptions" in lower:
        source = "drift-check.sh / PROCESS_EXCEPTIONS.md"
        fix = "Fill the required exception fields or remove stale placeholder exception entries."
    elif "handoff.md remaining" in lower:
        source = "drift-check.sh / HANDOFF.md"
        fix = "Update HANDOFF.md with a concrete remaining section and exact next step."
    elif "verification" in lower:
        source = "drift-check.sh / verify-project.sh"
        fix = "Run the intended verification path or record a clear exception for why it was skipped."
    elif "continuity" in lower:
        source = "drift-check.sh / methodology-status.sh"
        fix = "Refresh SESSION_STATE.md, HANDOFF.md, and the task-local workspace so current work is visible again."
    elif "wip limit" in lower:
        source = "drift-check.sh / TASKS.md"
        fix = "Reduce active work-in-progress or record the reason for exceeding the normal limit."
    add_issue(source, "Repo state and methodology state should agree.", issue, fix, severity)

if not observable.get("ok", True):
    for issue in observable.get("issues", []):
        if should_suppress_issue("observable-compliance-check.sh", issue):
            continue
        add_issue(
            "observable-compliance-check.sh",
            "Meaningful work should be visible on disk, not only in chat.",
            issue,
            "Refresh the observable-compliance checkpoint in SESSION_STATE.md and HANDOFF.md so the active task, workspace, spec, and verification path are visible.",
            "bad",
        )

if not status.get("ok", True):
    if status.get("missing"):
        add_issue(
            "methodology-status.sh",
            "Continuity files should exist for active work.",
            f"Missing continuity files: {', '.join(status['missing'])}",
            "Rebuild or restore the missing continuity files, then rerun the startup flow.",
            "bad",
        )
    if status.get("stale"):
        add_issue(
            "methodology-status.sh",
            "Continuity files should be fresher than the latest non-methodology work.",
            f"Stale continuity files: {', '.join(status['stale'])}",
            "Refresh the stale files from the current repo state before continuing.",
            "warn",
        )

if not mode.get("ok", True):
    for issue in mode.get("issues", []):
        add_issue(
            "mode-check.sh",
            "Declared methodology mode should match actual repo rigor.",
            issue,
            "Either strengthen the missing mode requirements or lower the declared mode if the repo is intentionally lighter.",
            "warn",
        )

if not metrics.get("ok", True):
    for issue in metrics.get("issues", []):
        if should_suppress_issue("metrics-check.sh", issue):
            continue
        add_issue(
            "metrics-check.sh",
            "Important metrics should be actionable, not decorative.",
            issue,
            "Fill the missing owner/source/cadence/threshold/action fields or reduce the metric surface to what the repo can maintain.",
            "warn",
        )

if stale_claims.get("stale_claims"):
    add_issue(
        "stale-claims-check.sh",
        "Claim leases should not expire silently during active multi-agent work.",
        f"{len(stale_claims['stale_claims'])} stale claim(s) detected.",
        "Refresh or release stale claims before further coordination work continues.",
        "warn",
    )

if root_owned_count > 0:
    add_issue(
        "filesystem ownership check",
        "Project files should remain editable from the normal user shell.",
        f"{root_owned_count} root-owned file(s) detected: {', '.join(root_owned_sample[:5])}" + ("..." if len(root_owned_sample) > 5 else ""),
        "Run fix-project-perms.sh or chown the affected files back to the normal project user.",
        "bad",
    )

issue_count = len(combined_issue_rows)
bad_count = sum(1 for row in combined_issue_rows if row["severity"] == "bad")
warn_count = issue_count - bad_count


def category_card(name, checks_list, extra_warns=0, extra_fails=0):
    fails = extra_fails + sum(0 if checks[key].get("ok", False) else 1 for key in checks_list)
    warns = extra_warns
    level = "good"
    if fails:
        level = "bad"
    elif warns:
        level = "warn"
    return {"name": name, "fails": fails, "warns": warns, "level": level}


def issue_levels(prefixes):
    fails = 0
    warns = 0
    for row in combined_issue_rows:
        if any(row["source"].startswith(prefix) for prefix in prefixes):
            if row["severity"] == "bad":
                fails += 1
            else:
                warns += 1
    return fails, warns


startup_issue_fails, startup_issue_warns = issue_levels([
    "methodology-status.sh",
    "observable-compliance-check.sh",
    "drift-check.sh / HANDOFF.md",
    "drift-check.sh / methodology-status.sh",
])
verification_issue_fails, verification_issue_warns = issue_levels([
    "metrics-check.sh",
    "drift-check.sh / verify-project.sh",
])
governance_issue_fails, governance_issue_warns = issue_levels([
    "mode-check.sh",
])
repo_hygiene_issue_fails, repo_hygiene_issue_warns = issue_levels([
    "methodology-audit.sh",
    "drift-check.sh / PROCESS_EXCEPTIONS.md",
    "drift-check.sh / TASKS.md",
    "filesystem ownership check",
    "drift-check.sh",
])
collaboration_issue_fails, collaboration_issue_warns = issue_levels([
    "stale-claims-check.sh",
])


categories = [
    category_card(
        "Startup & Continuity",
        [],
        extra_warns=startup_issue_warns + (0 if (dashboard.get("continuity") == "current" or is_template_source) else 1),
        extra_fails=startup_issue_fails,
    ),
    category_card(
        "Verification & QA",
        [],
        extra_warns=verification_issue_warns + (0 if (dashboard.get("last_verification") == "passed" or is_template_source) else 1),
        extra_fails=verification_issue_fails,
    ),
    category_card(
        "Governance & Mode",
        [],
        extra_warns=governance_issue_warns + (0 if (checks["mode"].get("ok", True) and (checks["metrics"].get("ok", True) or is_template_source)) else 1),
        extra_fails=governance_issue_fails,
    ),
    category_card(
        "Repo Hygiene",
        [],
        extra_warns=repo_hygiene_issue_warns,
        extra_fails=repo_hygiene_issue_fails,
    ),
    category_card(
        "Collaboration",
        [],
        extra_warns=collaboration_issue_warns + (1 if dashboard.get("claim_coverage") == "missing" and delegation_policy != "single_agent_by_platform_policy" else 0),
        extra_fails=collaboration_issue_fails,
    ),
]

principles = [
    {
        "title": "Active task state is visible",
        "status": "pass" if is_template_source or (observable.get("ok", False) and status.get("ok", False)) else "fail",
        "evidence": f"Task: {active_task} ({active_state}) | Workspace: {workspace_path}",
    },
    {
        "title": "Startup and resume are deterministic",
        "status": "pass" if state else "fail",
        "evidence": "machine state present" if state else "methodology-state.json missing or unreadable",
    },
    {
        "title": "Verification is visible and honest",
        "status": "pass" if (dashboard.get("last_verification") == "passed" or is_template_source) else "warn",
        "evidence": "Template source does not require product-style verification history." if is_template_source else f"Last verification: {dashboard.get('last_verification', 'n/a')}",
    },
    {
        "title": "Multi-agent behavior is not being faked",
        "status": "pass" if delegation_policy == "single_agent_by_platform_policy" or dashboard.get("claim_coverage") != "missing" else "warn",
        "evidence": f"Delegation: {delegation_policy} | Claim coverage: {dashboard.get('claim_coverage', 'n/a')}",
    },
    {
        "title": "Files stay editable by the normal user",
        "status": "pass" if root_owned_count == 0 else "fail",
        "evidence": "No root-owned files detected" if root_owned_count == 0 else f"{root_owned_count} root-owned file(s) detected",
    },
    {
        "title": "Specs do not drift silently",
        "status": "pass",
        "evidence": "Policy is read-only by default; mismatches should be recorded outside the spec until the user approves a change.",
    },
]


def esc(value):
    return html.escape(str(value))


def badge(level):
    cls = {"good": "good", "warn": "warn", "bad": "bad", "pass": "good", "fail": "bad"}.get(level, "muted")
    label = {"good": "Aligned", "warn": "Watch", "bad": "Broken", "pass": "Pass", "fail": "Fail"}.get(level, level.title())
    return f'<span class="badge {cls}">{esc(label)}</span>'


user_main = user_facing.get("Main User-Facing Files", [])
user_conditional = user_facing.get("Conditionally User-Facing Files", [])
user_internal = user_facing.get("Mostly Agent/Internal Files", [])

generated_at = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

bundle = {
    "target": str(target_dir),
    "generated_at": generated_at,
    "state": state,
    "checks": {name: {k: v for k, v in check.items() if k != "command"} for name, check in checks.items()},
}

html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Methodology Audit · {esc(repo_name)}</title>
  <style>
    :root {{
      --bg: #0f1117;
      --panel: rgba(255,255,255,0.06);
      --panel-strong: rgba(255,255,255,0.1);
      --text: #f6f8ff;
      --muted: #adb5d2;
      --accent: #69a8ff;
      --accent-2: #8ef0c8;
      --warn: #ffbe6b;
      --bad: #ff7e88;
      --good: #7ff0a8;
      --line: rgba(255,255,255,0.12);
      --shadow: 0 20px 60px rgba(0,0,0,.35);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 20% 0%, rgba(105,168,255,.18), transparent 34%),
        radial-gradient(circle at 100% 20%, rgba(142,240,200,.12), transparent 28%),
        linear-gradient(180deg, #0d1018, #10141d 45%, #0b0f17);
      min-height: 100vh;
    }}
    .wrap {{
      width: min(1380px, calc(100vw - 48px));
      margin: 28px auto 64px;
    }}
    .hero {{
      display: grid;
      grid-template-columns: 1.4fr .9fr;
      gap: 20px;
      margin-bottom: 24px;
    }}
    .panel {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 24px;
      box-shadow: var(--shadow);
      backdrop-filter: blur(12px);
    }}
    .hero-main {{
      padding: 28px 30px;
      position: relative;
      overflow: hidden;
    }}
    .eyebrow {{
      color: var(--accent-2);
      text-transform: uppercase;
      letter-spacing: .18em;
      font-size: 12px;
      margin-bottom: 14px;
    }}
    h1 {{
      margin: 0 0 12px;
      font-size: clamp(34px, 5vw, 56px);
      line-height: .95;
      letter-spacing: -.04em;
    }}
    .lede {{
      color: var(--muted);
      font-size: 16px;
      line-height: 1.6;
      max-width: 70ch;
    }}
    .hero-strip {{
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 18px;
    }}
    .pill {{
      padding: 10px 14px;
      border-radius: 999px;
      background: rgba(255,255,255,.07);
      border: 1px solid rgba(255,255,255,.1);
      color: var(--muted);
      font-size: 13px;
    }}
    .hero-side {{
      padding: 22px;
      display: grid;
      gap: 14px;
    }}
    .score {{
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 12px;
    }}
    .score-card {{
      padding: 18px;
      border-radius: 18px;
      background: rgba(255,255,255,.04);
      border: 1px solid rgba(255,255,255,.08);
    }}
    .score-k {{
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: .14em;
      margin-bottom: 8px;
    }}
    .score-v {{
      font-size: 26px;
      font-weight: 700;
      letter-spacing: -.03em;
    }}
    .tabs {{
      display: inline-flex;
      gap: 8px;
      padding: 8px;
      background: rgba(255,255,255,.05);
      border: 1px solid var(--line);
      border-radius: 999px;
      margin: 14px 0 22px;
    }}
    .tab {{
      border: 0;
      background: transparent;
      color: var(--muted);
      padding: 10px 16px;
      border-radius: 999px;
      cursor: pointer;
      font: inherit;
    }}
    .tab.active {{
      color: #07121f;
      background: linear-gradient(135deg, var(--accent), #d8e7ff);
      font-weight: 700;
    }}
    .view {{ display: none; }}
    .view.active {{ display: block; }}
    .grid {{
      display: grid;
      gap: 18px;
    }}
    .metrics-grid {{
      grid-template-columns: repeat(4, minmax(0, 1fr));
      margin-bottom: 20px;
    }}
    .metric {{
      padding: 20px;
      min-height: 134px;
    }}
    .metric strong {{
      display: block;
      margin-top: 6px;
      font-size: 28px;
      letter-spacing: -.04em;
    }}
    .muted {{ color: var(--muted); }}
    .badge {{
      display: inline-flex;
      align-items: center;
      padding: 6px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: .05em;
      text-transform: uppercase;
    }}
    .badge.good {{ background: rgba(127,240,168,.15); color: var(--good); }}
    .badge.warn {{ background: rgba(255,190,107,.15); color: var(--warn); }}
    .badge.bad {{ background: rgba(255,126,136,.15); color: var(--bad); }}
    .badge.muted {{ background: rgba(255,255,255,.1); color: var(--muted); }}
    .section {{
      padding: 22px 24px 24px;
    }}
    .section h2 {{
      margin: 0 0 14px;
      font-size: 24px;
      letter-spacing: -.03em;
    }}
    .section p {{
      margin: 0;
      color: var(--muted);
      line-height: 1.6;
    }}
    .two-col {{
      display: grid;
      grid-template-columns: 1.15fr .85fr;
      gap: 18px;
      margin-bottom: 18px;
    }}
    .principles {{
      display: grid;
      gap: 12px;
      margin-top: 16px;
    }}
    .principle {{
      padding: 16px 18px;
      border-radius: 18px;
      background: rgba(255,255,255,.04);
      border: 1px solid rgba(255,255,255,.08);
      display: grid;
      gap: 8px;
    }}
    .principle-top {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: center;
    }}
    .heatmap {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      margin-top: 16px;
    }}
    .heat {{
      padding: 16px;
      border-radius: 18px;
      border: 1px solid rgba(255,255,255,.08);
      background: rgba(255,255,255,.04);
    }}
    .heat.good {{ box-shadow: inset 0 0 0 1px rgba(127,240,168,.14); }}
    .heat.warn {{ box-shadow: inset 0 0 0 1px rgba(255,190,107,.18); }}
    .heat.bad {{ box-shadow: inset 0 0 0 1px rgba(255,126,136,.18); }}
    .issues {{
      display: grid;
      gap: 12px;
      margin-top: 14px;
    }}
    .issue {{
      padding: 18px;
      border-radius: 18px;
      border: 1px solid rgba(255,255,255,.08);
      background: rgba(255,255,255,.04);
    }}
    .issue h3 {{
      margin: 0 0 8px;
      font-size: 18px;
      letter-spacing: -.02em;
    }}
    .issue-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px 18px;
      margin-top: 10px;
    }}
    .issue dt {{
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: .12em;
      margin-bottom: 6px;
    }}
    .issue dd {{
      margin: 0;
      line-height: 1.5;
    }}
    .list-grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
      margin-top: 14px;
    }}
    .list-card {{
      padding: 18px;
      border-radius: 18px;
      background: rgba(255,255,255,.04);
      border: 1px solid rgba(255,255,255,.08);
    }}
    ul.clean {{
      margin: 12px 0 0;
      padding-left: 18px;
      color: var(--muted);
      line-height: 1.7;
    }}
    code, pre {{
      font-family: "IBM Plex Mono", "SFMono-Regular", monospace;
    }}
    .agent-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 18px;
    }}
    .kv {{
      display: grid;
      grid-template-columns: 190px 1fr;
      gap: 8px 14px;
      margin-top: 14px;
      font-size: 14px;
    }}
    .kv div:nth-child(odd) {{
      color: var(--muted);
    }}
    pre.json {{
      margin: 0;
      padding: 16px;
      overflow: auto;
      border-radius: 18px;
      background: #0a0d14;
      border: 1px solid rgba(255,255,255,.08);
      color: #d4dcff;
      font-size: 12px;
      line-height: 1.55;
      max-height: 520px;
    }}
    .footer {{
      margin-top: 18px;
      color: var(--muted);
      font-size: 12px;
      text-align: center;
    }}
    @media (max-width: 1120px) {{
      .hero, .two-col, .agent-grid, .list-grid, .metrics-grid {{
        grid-template-columns: 1fr;
      }}
      .heatmap {{
        grid-template-columns: 1fr;
      }}
      .issue-grid, .score {{
        grid-template-columns: 1fr;
      }}
      .kv {{
        grid-template-columns: 1fr;
      }}
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <section class="hero">
      <div class="panel hero-main">
        <div class="eyebrow">Methodology Audit</div>
        <h1>{esc(repo_name)}<br>Methodology Signal Board</h1>
        <p class="lede">
          This page audits the methodology from real repo state, not from hand-written summaries.
          It shows what the methodology is currently deciding, where reality drifts from intent,
          and which files matter most for a human to review.
        </p>
        <div class="hero-strip">
          <span class="pill">mode: {esc(mode_name)}</span>
          <span class="pill">work type: {esc(work_type)}</span>
          <span class="pill">branch: {esc(branch)}</span>
          <span class="pill">git: {esc(git_state)}</span>
          <span class="pill">delegation: {esc(delegation_policy)}</span>
          <span class="pill">generated: {esc(generated_at)}</span>
        </div>
      </div>
      <div class="panel hero-side">
        <div class="score">
          <div class="score-card">
            <div class="score-k">Active Task</div>
            <div class="score-v">{esc(active_task)}</div>
            <div class="muted">{esc(active_state)}</div>
          </div>
          <div class="score-card">
            <div class="score-k">Current Risk</div>
            <div class="score-v">{esc(risk_class)}</div>
            <div class="muted">release {esc(release_risk)}</div>
          </div>
          <div class="score-card">
            <div class="score-k">Audit Issues</div>
            <div class="score-v">{issue_count}</div>
            <div class="muted">{bad_count} broken · {warn_count} watch</div>
          </div>
          <div class="score-card">
            <div class="score-k">Last Verification</div>
            <div class="score-v">{esc(dashboard.get("last_verification", "n/a"))}</div>
            <div class="muted">entries {esc(dashboard.get("verification_entries", "0"))}</div>
          </div>
        </div>
      </div>
    </section>

    <div class="tabs" role="tablist" aria-label="Audit views">
      <button class="tab active" data-view="user">User View</button>
      <button class="tab" data-view="agent">Agent View</button>
    </div>

    <section class="view active" id="view-user">
      <div class="grid metrics-grid">
        <div class="panel metric">
          <div class="score-k">Business Owner</div>
          <strong>{esc(business_owner)}</strong>
          <div class="muted">{esc(customer_signal)}</div>
        </div>
        <div class="panel metric">
          <div class="score-k">Leading Metric</div>
          <strong>{esc(leading_metric)}</strong>
          <div class="muted">decision {esc(decision_deadline)}</div>
        </div>
        <div class="panel metric">
          <div class="score-k">Spec Path</div>
          <strong style="font-size:18px; line-height:1.25">{esc(spec_path)}</strong>
          <div class="muted">workspace {esc(workspace_path)}</div>
        </div>
        <div class="panel metric">
          <div class="score-k">Next Step</div>
          <strong style="font-size:18px; line-height:1.25">{esc(next_step)}</strong>
          <div class="muted">verification {esc(verification_path)}</div>
        </div>
      </div>

      <div class="two-col">
        <section class="panel section">
          <h2>Methodology-Following Quality</h2>
          <p>This is the current signal for whether the methodology appears to be actively steering the work instead of only existing on disk.</p>
          <div class="principles">
            <div class="principle">
              <div class="principle-top">
                <strong>Current session quality</strong>
                {badge(session_quality)}
              </div>
              <div class="muted">{esc(' '.join(session_quality_reasons))}</div>
            </div>
            <div class="principle">
              <div class="principle-top">
                <strong>Loaded docs seen in the checkpoint</strong>
                {badge("good" if loaded_docs else "warn")}
              </div>
              <div class="muted">{esc(', '.join(loaded_docs) if loaded_docs else 'No loaded-doc evidence recorded.')}</div>
            </div>
          </div>
        </section>

        <section class="panel section">
          <h2>Proof Model</h2>
          <p>This shows what kind of claim this repo can prove well, so source proof and dogfood proof do not get mixed together.</p>
          <div class="principles">
            <div class="principle">
              <div class="principle-top">
                <strong>{esc(proof_mode)}</strong>
                {badge("good")}
              </div>
              <div class="muted">{esc(proof_scope)}</div>
            </div>
            <div class="principle">
              <div class="principle-top">
                <strong>Expected companion proof</strong>
                {badge("warn" if is_template_source else "good")}
              </div>
              <div class="muted">{esc(proof_expectation)}</div>
            </div>
          </div>
        </section>
      </div>

      <div class="two-col">
        <section class="panel section">
          <h2>Principles vs Reality</h2>
          <p>The methodology should serve these principles. This view compares the intended guardrails to the repo's current state.</p>
          <div class="principles">
            {''.join(
                f'''<div class="principle">
                  <div class="principle-top">
                    <strong>{esc(item["title"])}</strong>
                    {badge(item["status"])}
                  </div>
                  <div class="muted">{esc(item["evidence"])}</div>
                </div>'''
                for item in principles
            )}
          </div>
        </section>

        <section class="panel section">
          <h2>Drift Heatmap</h2>
          <p>Each tile shows whether that part of the methodology is aligned, needs attention, or is broken.</p>
          <div class="heatmap">
            {''.join(
                f'''<div class="heat {esc(cat["level"])}">
                  <div class="principle-top">
                    <strong>{esc(cat["name"])}</strong>
                    {badge(cat["level"])}
                  </div>
                  <div class="muted" style="margin-top:10px">{cat["fails"]} failing check(s) · {cat["warns"]} warning signal(s)</div>
                </div>'''
                for cat in categories
            )}
          </div>
        </section>
      </div>

      <section class="panel section">
        <h2>Why Am I Seeing This?</h2>
        <p>Each item ties an observed problem to its source rule and a concrete next fix, so the dashboard explains itself instead of just complaining.</p>
        <div class="issues">
          {''.join(
              f'''<article class="issue">
                <div class="principle-top">
                  <h3>{esc(item["observed"])}</h3>
                  {badge("bad" if item["severity"] == "bad" else "warn")}
                </div>
                  <dl class="issue-grid">
                  <div><dt>Source</dt><dd>{esc(item["source"])}</dd></div>
                  <div><dt>Rule</dt><dd>{esc(item["rule"])}</dd></div>
                  <div style="grid-column: span 2;"><dt>Recommended Fix</dt><dd>{esc(item["fix"])}</dd></div>
                </dl>
              </article>'''
              for item in combined_issue_rows
          ) if combined_issue_rows else '<article class="issue"><div class="principle-top"><h3>No current audit blockers</h3>' + badge("good") + '</div><div class="muted">The methodology checks are aligned with current repo state right now.</div></article>'}
        </div>
      </section>

      <section class="panel section">
        <h2>User vs Internal Surfaces</h2>
        <p>This makes it easier to tell which files are meant for you to read directly versus which ones mostly exist for continuity, recovery, and agent coordination.</p>
        <div class="list-grid">
          <div class="list-card">
            <strong>Main user-facing files</strong>
            <ul class="clean">{''.join(f'<li>{esc(item)}</li>' for item in user_main)}</ul>
          </div>
          <div class="list-card">
            <strong>Conditionally user-facing</strong>
            <ul class="clean">{''.join(f'<li>{esc(item)}</li>' for item in user_conditional)}</ul>
          </div>
          <div class="list-card">
            <strong>Mostly internal / agent-facing</strong>
            <ul class="clean">{''.join(f'<li>{esc(item)}</li>' for item in user_internal)}</ul>
          </div>
        </div>
      </section>
    </section>

    <section class="view" id="view-agent">
      <div class="agent-grid">
        <section class="panel section">
          <h2>Resolved Current State</h2>
          <p>This is the compact state the methodology is effectively working from right now.</p>
          <div class="kv">
            <div>Target</div><div>{esc(target)}</div>
            <div>Mode</div><div>{esc(mode_name)}</div>
            <div>Work type</div><div>{esc(work_type)}</div>
            <div>Branch</div><div>{esc(branch)}</div>
            <div>Git state</div><div>{esc(git_state)}</div>
            <div>Delegation policy</div><div>{esc(delegation_policy)}</div>
            <div>Active task</div><div>{esc(active_task)} ({esc(active_state)})</div>
            <div>Spec</div><div>{esc(spec_path)}</div>
            <div>Verification path</div><div>{esc(verification_path)}</div>
            <div>Workspace</div><div>{esc(workspace_path)}</div>
            <div>Risk class</div><div>{esc(risk_class)}</div>
            <div>Release risk</div><div>{esc(release_risk)}</div>
            <div>Next step</div><div>{esc(next_step)}</div>
            <div>Business owner</div><div>{esc(business_owner)}</div>
            <div>Leading metric</div><div>{esc(leading_metric)}</div>
            <div>Customer signal</div><div>{esc(customer_signal)}</div>
          </div>
        </section>

        <section class="panel section">
          <h2>Check Matrix</h2>
          <p>Every row below comes from a real methodology script.</p>
          <div class="principles">
            {''.join(
                f'''<div class="principle">
                  <div class="principle-top">
                    <strong>{esc(name)}</strong>
                    {badge("good" if check.get("ok") else "bad")}
                  </div>
                  <div class="muted">exit {check.get("returncode")} · {esc((check.get("data") or {{}}).get("target", str(target_dir)))}</div>
                </div>'''
                for name, check in checks.items()
            )}
          </div>
        </section>
      </div>

      <section class="panel section" style="margin-top:18px;">
        <h2>Raw Audit Bundle</h2>
        <p>This is the machine-readable bundle used to render the page. It makes the dashboard auditable instead of purely decorative.</p>
        <pre class="json">{esc(json.dumps(bundle, indent=2, sort_keys=True))}</pre>
      </section>
    </section>

    <div class="footer">Generated by render-methodology-audit.sh · {esc(output_path.name)}</div>
  </div>

  <script type="application/json" id="audit-bundle">{html.escape(json.dumps(bundle))}</script>
  <script>
    const tabs = document.querySelectorAll('.tab');
    const views = document.querySelectorAll('.view');
    tabs.forEach((tab) => {{
      tab.addEventListener('click', () => {{
        tabs.forEach(t => t.classList.remove('active'));
        views.forEach(v => v.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('view-' + tab.dataset.view).classList.add('active');
      }});
    }});
  </script>
</body>
</html>
"""

output_path.write_text(html_doc)
print(output_path)
PY

if [[ "$EUID" -eq 0 && -f "$output_path" ]]; then
  target_user="${SUDO_USER:-}"
  if [[ -z "$target_user" ]]; then
    repo_owner="$(stat -c '%U' "$target_dir" 2>/dev/null || true)"
    if [[ -n "$repo_owner" && "$repo_owner" != "root" && "$repo_owner" != "UNKNOWN" ]]; then
      target_user="$repo_owner"
    else
      target_user="$(id -un)"
    fi
  fi
  if id "$target_user" >/dev/null 2>&1; then
    target_group="$(id -gn "$target_user")"
    chown "$target_user:$target_group" "$output_path" 2>/dev/null || true
  fi
fi
