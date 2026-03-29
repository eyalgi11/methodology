#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/eyal/system-docs/methodology/methodology-common.sh
source "$SCRIPT_DIR/methodology-common.sh"

usage() {
  cat <<EOF
Usage: lookup-archived-doc.sh --query "text" [options] [target-directory]

Searches docs-archive-index.json and returns the most relevant archived docs
without loading the full archived markdown files.

Options:
  --query TEXT    Search query to rank against archived doc metadata
  --limit N       Maximum matches to return. Default: 3
  --json          Output JSON
  -h, --help      Show this help text
EOF
}

target_arg=""
query=""
limit=3
json_mode=0

while (($# > 0)); do
  case "$1" in
    --query) query="$2"; shift 2 ;;
    --limit) limit="$2"; shift 2 ;;
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

if [[ -z "$query" ]]; then
  echo "--query is required." >&2
  usage >&2
  exit 1
fi

if [[ ! "$limit" =~ ^[0-9]+$ ]]; then
  echo "--limit must be a non-negative integer." >&2
  exit 1
fi

target_dir="$(resolve_target_dir "${target_arg:-$PWD}")"
index_path="$(project_file_path "$target_dir" "docs-archive-index.json")"

if [[ ! -f "$index_path" ]]; then
  "$SCRIPT_DIR/refresh-docs-archive-index.sh" "$target_dir" >/dev/null
fi

python3 - "$index_path" "$query" "$limit" "$json_mode" <<'PY'
import json
import re
import sys

index_path = sys.argv[1]
query = sys.argv[2]
limit = int(sys.argv[3])
json_mode = int(sys.argv[4]) == 1

with open(index_path, "r", encoding="utf-8") as fh:
    payload = json.load(fh)

def tokenize(value: str):
    return [token for token in re.split(r"[^a-z0-9]+", value.lower()) if len(token) >= 2]

query_tokens = tokenize(query)
entries = payload.get("entries", [])
scored = []

for entry in entries:
    haystacks = {
        "title": " ".join(tokenize(entry.get("title", ""))),
        "path": " ".join(tokenize(entry.get("original_path", ""))),
        "summary": " ".join(tokenize(entry.get("summary", ""))),
        "keywords": " ".join(tokenize(" ".join(entry.get("keywords", [])))),
        "headings": " ".join(tokenize(" ".join(entry.get("headings", [])))),
        "topics": " ".join(tokenize(" ".join(entry.get("topics", [])))),
    }
    score = 0
    matched = []
    for token in query_tokens:
        if token in haystacks["title"].split():
            score += 6
            matched.append(token)
        elif token in haystacks["topics"].split():
            score += 5
            matched.append(token)
        elif token in haystacks["keywords"].split():
            score += 4
            matched.append(token)
        elif token in haystacks["headings"].split():
            score += 3
            matched.append(token)
        elif token in haystacks["path"].split():
            score += 2
            matched.append(token)
        elif token in haystacks["summary"].split():
            score += 1
            matched.append(token)
    if score > 0:
        item = dict(entry)
        item["score"] = score
        item["matched_terms"] = sorted(set(matched))
        scored.append(item)

scored.sort(key=lambda item: (-item["score"], item.get("title", "")))
scored = scored[:limit]

if json_mode:
    print(json.dumps({
        "query": query,
        "match_count": len(scored),
        "matches": scored,
    }, indent=2))
    raise SystemExit(0)

if not scored:
    print(f"No archived-doc matches found for: {query}")
    raise SystemExit(0)

print(f"Archived-doc matches for: {query}")
for item in scored:
    print()
    print(f"- Title: {item['title']}")
    print(f"  Original: {item['original_path']}")
    print(f"  Archive: {item['archive_path']}")
    print(f"  Score: {item['score']}")
    print(f"  Matched terms: {', '.join(item['matched_terms']) if item['matched_terms'] else 'n/a'}")
    print(f"  Summary: {item['summary']}")
    headings = item.get("headings", [])[:4]
    if headings:
        print(f"  Headings: {' | '.join(headings)}")
    topics = item.get("topics", [])[:5]
    if topics:
        print(f"  Topics: {' | '.join(topics)}")
PY
