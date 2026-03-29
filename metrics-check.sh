#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: metrics-check.sh [--json] [target-directory]

Validates that METRICS.md contains non-placeholder metrics, ownership, targets,
status, and operational follow-through.
EOF
}

target_arg=""
json_mode=0
write_metrics=1
while (($# > 0)); do
  case "$1" in
    --json) json_mode=1; shift ;;
    --no-write) write_metrics=0; shift ;;
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
metrics_file="$(project_file_path "$target_dir" "METRICS.md")"
work_type="$(read_work_type "$target_dir")"
mode="$(read_maturity_mode "$target_dir")"
issues=()

metric_name_count="$(grep -Ec '^- Metric:' "$metrics_file" 2>/dev/null || true)"
ai_metric_count="$(awk '
  $0 == "## AI / Agent Metrics" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- Metric:[[:space:]]*[^[:space:]].+/ { count++ }
  END { print count + 0 }
' "$metrics_file" 2>/dev/null || true)"
cost_metric_count="$(awk '
  $0 == "## Cost Metrics" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- Metric:[[:space:]]*[^[:space:]].+/ { count++ }
  END { print count + 0 }
' "$metrics_file" 2>/dev/null || true)"
north_star_count="$(awk '
  $0 == "## North Star" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- Metric:[[:space:]]*[^[:space:]].+/ { count++ }
  END { print count + 0 }
' "$metrics_file" 2>/dev/null || true)"
feature_metric_count="$(grep -Ec '^- Feature:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
methodology_kpi_count="$(awk '
  $0 == "## Methodology KPIs" { flag = 1; next }
  /^## / && flag { exit }
  flag && /^- Metric:[[:space:]]*[^[:space:]].+/ { count++ }
  END { print count + 0 }
' "$metrics_file" 2>/dev/null || true)"
real_target_count="$(grep -Ec '^[[:space:]]*Target:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
current_status_count="$(grep -Ec '^[[:space:]]*Current status:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
owner_count="$(grep -Ec '^[[:space:]]*Owner:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
source_count="$(grep -Ec '^[[:space:]]*Source / dashboard / query:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
type_count="$(grep -Ec '^[[:space:]]*Type:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
last_refreshed_count="$(grep -Ec '^[[:space:]]*Last refreshed:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
cadence_count="$(grep -Ec '^[[:space:]]*Refresh cadence:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
baseline_count="$(grep -Ec '^[[:space:]]*Baseline:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
threshold_count="$(grep -Ec '^[[:space:]]*Alert threshold:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
action_count="$(grep -Ec '^[[:space:]]*Action if red:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
reviewer_count="$(grep -Ec '^[[:space:]]*Review cadence / reviewer:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
service_level_count="$(grep -Ec '^[[:space:]]*Availability target:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
service_dashboard_count="$(grep -Ec '^[[:space:]]*Dashboard:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
service_runbook_count="$(grep -Ec '^[[:space:]]*Runbook:[[:space:]]*[^[:space:]].+' "$metrics_file" 2>/dev/null || true)"
verification_entry_count="$(safe_grep_count '^## Verification Entry - ' "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")")"
active_claim_count="$(safe_grep_count '^## Claim ' "$(project_file_path "$target_dir" "ACTIVE_CLAIMS.md")")"
stale_claim_count="$("$SCRIPT_DIR/stale-claims-check.sh" --json "$target_dir" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("stale_claims", [])))' 2>/dev/null || printf '0')"
audit_issue_count="$("$SCRIPT_DIR/methodology-audit.sh" --json "$target_dir" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("missing", [])) + len(data.get("placeholder", [])))' 2>/dev/null || printf '0')"
status_issue_count="$("$SCRIPT_DIR/methodology-status.sh" --json "$target_dir" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print(len(data.get("missing", [])) + len(data.get("stale", [])))' 2>/dev/null || printf '0')"
audit_issue_count="$(printf '%s' "$audit_issue_count" | tr -cd '0-9')"
status_issue_count="$(printf '%s' "$status_issue_count" | tr -cd '0-9')"
audit_issue_count="${audit_issue_count:-0}"
status_issue_count="${status_issue_count:-0}"
drift_issue_count="$((audit_issue_count + status_issue_count))"
cold_start_verified_count="$(( $(grep -Ec 'cold-start verified' "$(project_file_path "$target_dir" "VERIFICATION_LOG.md")" 2>/dev/null || true) + $(grep -Ec 'cold-start verified' "$(project_file_path "$target_dir" "MANUAL_CHECKS.md")" 2>/dev/null || true) ))"
ai_policy_present=0
if ! is_placeholder_file "$target_dir" "SECURITY_NOTES.md" && grep -Eq '^[[:space:]]*-[[:space:]]*Model / provider / version:[[:space:]]*[^[:space:]].+' "$(project_file_path "$target_dir" "SECURITY_NOTES.md")" 2>/dev/null; then
  ai_policy_present=1
fi

stale_claim_rate="0.00"
if (( active_claim_count > 0 )); then
  stale_claim_rate="$(python3 -c 'import sys; stale=int(sys.argv[1]); active=int(sys.argv[2]); print(f\"{stale/active:.2f}\")' "$stale_claim_count" "$active_claim_count" 2>/dev/null || printf '0.00')"
fi

if is_placeholder_file "$target_dir" "METRICS.md"; then
  issues+=("METRICS.md is still untouched template content.")
fi
if [[ "$work_type" == "product" ]] && (( north_star_count == 0 )); then
  issues+=("No north-star metric is defined.")
fi
if (( metric_name_count == 0 )); then
  issues+=("No metrics are defined in METRICS.md.")
fi
if [[ "$work_type" == "product" ]] && (( feature_metric_count == 0 )); then
  issues+=("No feature outcome metrics are recorded.")
fi
if (( real_target_count == 0 )); then
  issues+=("No metric targets are filled in.")
fi
if (( current_status_count == 0 )); then
  issues+=("No current metric status values are filled in.")
fi
if (( owner_count == 0 )); then
  issues+=("No metric owners are filled in.")
fi
if (( source_count == 0 )); then
  issues+=("No metric data sources are filled in.")
fi
if (( type_count == 0 )); then
  issues+=("No leading / lagging / guardrail metric types are filled in.")
fi
if (( last_refreshed_count == 0 )); then
  issues+=("No metric last-refreshed timestamps are filled in.")
fi
if (( cadence_count == 0 )); then
  issues+=("No metric refresh cadences are filled in.")
fi
if (( baseline_count == 0 )); then
  issues+=("No metric baselines are filled in.")
fi
if (( reviewer_count == 0 )); then
  issues+=("No metric review cadence / reviewer fields are filled in.")
fi
if (( action_count == 0 )); then
  issues+=("No action-if-red guidance is filled in.")
fi
if [[ "$mode" == "production" ]] && (( methodology_kpi_count == 0 )); then
  issues+=("No methodology KPIs are recorded for production mode.")
fi
if [[ "$mode" == "production" ]] && (( threshold_count == 0 )); then
  issues+=("No alert thresholds are filled in for production mode.")
fi
if [[ "$mode" == "production" ]] && (( service_level_count == 0 )); then
  issues+=("No service-level expectations are recorded for production mode.")
fi
if [[ "$mode" == "production" ]] && (( service_dashboard_count == 0 )); then
  issues+=("No service dashboards are recorded for production mode.")
fi
if [[ "$mode" == "production" ]] && (( service_runbook_count == 0 )); then
  issues+=("No service runbooks are recorded for production mode.")
fi
if (( ai_policy_present == 1 )) && (( ai_metric_count == 0 )); then
  issues+=("AI / agent policy exists, but no AI / agent metrics are recorded.")
fi
if (( ai_policy_present == 1 )) && (( cost_metric_count == 0 )); then
  issues+=("AI / agent policy exists, but no cost metrics are recorded.")
fi

metrics_body=$(cat <<EOF
- Reviewed at: $(timestamp_now)
- North-star metrics: ${north_star_count}
- Metric entries: ${metric_name_count}
- Feature outcome metrics: ${feature_metric_count}
- AI / agent metrics: ${ai_metric_count}
- Cost metrics: ${cost_metric_count}
- Methodology KPIs: ${methodology_kpi_count}
- Owners filled: ${owner_count}
- Sources filled: ${source_count}
- Types filled: ${type_count}
- Last-refreshed fields filled: ${last_refreshed_count}
- Cadences filled: ${cadence_count}
- Baselines filled: ${baseline_count}
- Targets filled: ${real_target_count}
- Thresholds filled: ${threshold_count}
- Current statuses filled: ${current_status_count}
- Reviewers filled: ${reviewer_count}
- Actions-if-red filled: ${action_count}
- Service levels filled: ${service_level_count}
- Service dashboards filled: ${service_dashboard_count}
- Service runbooks filled: ${service_runbook_count}
- Issues found: ${#issues[@]}
EOF
)
if (( write_metrics == 1 )); then
  append_or_replace_auto_section "$metrics_file" "metrics-check" "## Auto Metrics Check" "$metrics_body"
  append_or_replace_auto_section "$metrics_file" "methodology-kpis" "## Methodology KPI Snapshot" "$(cat <<EOF
- Reviewed at: $(timestamp_now)
- Verification evidence entries: ${verification_entry_count}
- Cold-start verified deliveries recorded: ${cold_start_verified_count}
- Active claims: ${active_claim_count}
- Stale claims: ${stale_claim_count}
- Stale-claim rate: ${stale_claim_rate}
- Drift contradictions detected: ${drift_issue_count}
EOF
)"
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
    echo "Metrics check passed."
  else
    echo "Metrics issues found in $target_dir"
    printf '  - %s\n' "${issues[@]}"
  fi
fi

if (( ${#issues[@]} == 0 )); then
  exit 0
fi
if (( write_metrics == 1 )); then
  "$SCRIPT_DIR/refresh-methodology-state.sh" "$target_dir" >/dev/null 2>&1 || true
fi
exit 1
