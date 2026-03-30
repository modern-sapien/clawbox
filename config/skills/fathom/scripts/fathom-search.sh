#!/bin/sh
# fathom-search.sh — Search Fathom calls by company domain(s)
# Usage: fathom-search.sh domain1.com [domain2.com ...] [--after YYYY-MM-DD] [--before YYYY-MM-DD] [--type external|internal|all]
#
# Automatically paginates through all results.
# Invalid domains are silently ignored by the API (returns empty, no error).

set -e

if [ -z "$FATHOM_API_KEY" ]; then
  echo "ERROR: FATHOM_API_KEY is not set" >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Usage: fathom-search.sh domain1.com [domain2.com ...] [--after YYYY-MM-DD] [--before YYYY-MM-DD] [--type external|internal|all]" >&2
  exit 1
fi

BASE_URL="https://api.fathom.ai/external/v1/meetings"
DOMAINS=""
AFTER=""
BEFORE=""
MEETING_TYPE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --after)
      AFTER="$2"
      shift 2
      ;;
    --before)
      BEFORE="$2"
      shift 2
      ;;
    --type)
      MEETING_TYPE="$2"
      shift 2
      ;;
    *)
      DOMAINS="${DOMAINS}&calendar_invitees_domains[]=$1"
      shift
      ;;
  esac
done

if [ -z "$DOMAINS" ]; then
  echo "ERROR: At least one domain is required" >&2
  exit 1
fi

# Build query string
QS="include_summary=true&include_action_items=true${DOMAINS}"
[ -n "$AFTER" ] && QS="${QS}&created_after=${AFTER}T00:00:00Z"
[ -n "$BEFORE" ] && QS="${QS}&created_before=${BEFORE}T23:59:59Z"
[ -n "$MEETING_TYPE" ] && QS="${QS}&meeting_type=${MEETING_TYPE}"

CURSOR=""
PAGE=1
TOTAL=0

while true; do
  URL="${BASE_URL}?${QS}"
  [ -n "$CURSOR" ] && URL="${URL}&cursor=${CURSOR}"

  RESPONSE=$(curl -s -H "X-API-Key: $FATHOM_API_KEY" "$URL")

  # Check for error
  echo "$RESPONSE" | grep -q '"error"' && {
    echo "API Error: $RESPONSE" >&2
    exit 1
  }

  # Count items on this page
  COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('items',[])))" 2>/dev/null || echo "0")

  if [ "$COUNT" = "0" ] && [ "$TOTAL" = "0" ]; then
    echo "No meetings found for the specified domain(s)."
    exit 0
  fi

  # Output results
  echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('items', []):
    invitees = m.get('calendar_invitees', [])
    external = [i for i in invitees if i.get('is_external')]
    external_str = ', '.join(f\"{i.get('name','')} <{i.get('email','')}>\" for i in external)
    print(f\"--- Call: {m.get('title', 'Untitled')} ---\")
    print(f\"Date: {m.get('created_at', '')[:10]}\")
    print(f\"Recording ID: {m.get('recording_id', 'N/A')}\")
    print(f\"URL: {m.get('url', 'N/A')}\")
    print(f\"Share URL: {m.get('share_url', 'N/A')}\")
    print(f\"Recorded by: {m.get('recorded_by', {}).get('name', 'N/A')} ({m.get('recorded_by', {}).get('team', 'N/A')})\")
    print(f\"External attendees: {external_str or 'None'}\")
    summary = m.get('default_summary')
    if summary:
        if isinstance(summary, dict):
            summary = summary.get('text', summary.get('summary', json.dumps(summary)))
        print(f\"Summary: {str(summary)[:500]}\")
    actions = m.get('action_items')
    if actions:
        print(f\"Action items: {json.dumps(actions)[:500]}\")
    print()
"

  TOTAL=$((TOTAL + COUNT))

  # Check for next page
  CURSOR=$(echo "$RESPONSE" | python3 -c "import sys,json; c=json.load(sys.stdin).get('next_cursor',''); print(c if c else '')" 2>/dev/null)

  if [ -z "$CURSOR" ]; then
    break
  fi

  PAGE=$((PAGE + 1))
done

echo "Total calls found: $TOTAL"
