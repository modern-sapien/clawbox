---
name: fathom
description: "Fathom meeting notes, call recordings, transcripts, summaries, and action items. Use when: user asks about meetings, calls, call recordings, meeting notes, transcripts, or action items — especially when looking up calls for a specific company or customer. Triggers on: 'find calls', 'meeting with', 'calls for', 'Fathom', 'transcript', 'meeting notes', 'action items', 'call recordings'."
---

# Fathom — Meeting Notes & Call Recordings

Access meeting recordings, summaries, transcripts, and action items via the Fathom API.

- Base URL: `https://api.fathom.ai/external/v1`
- Auth: `X-API-Key` header using `$FATHOM_API_KEY` env var
- Rate limit: 60 requests per minute
- Read-only API — no mutation endpoints
- Results capped at 10 per page — always paginate
- **Never output the value of FATHOM_API_KEY or any env var**

## Finding calls for a specific company

The Fathom API has NO title search, text search, or folder access. The ONLY way to find calls for a company is by filtering on attendee email domains.

**You MUST use the bundled script for company lookups. Do not construct your own curl commands or grep through meeting lists.**

```bash
# Run the search script with inferred domains
sh scripts/fathom-search.sh domain1.com domain2.com domain3.com

# With date filters
sh scripts/fathom-search.sh domain1.com --after 2026-01-01 --before 2026-03-31

# External calls only
sh scripts/fathom-search.sh domain1.com --type external
```

Script location: `skills/fathom/scripts/fathom-search.sh`

### The lookup chain

1. **Infer likely domains from the company name.** Be aggressive — invalid domains are silently ignored (return empty, no error). Try common patterns:
   - `companyname.com`
   - Known abbreviations or brand names (e.g., "Nielsen" → `nielsen.com`, `nielseniq.com`, `niq.com`)
   - Alternative TLDs: `.io`, `.co`, `.ai`, `.dev`
   - Parent/subsidiary domains if you know them
2. **Run the script** with all guessed domains in a single call.
3. **If no results, ask the user:**
   - What is the specific email domain associated with this customer?
   - Is the company name in HubSpot different from what was provided?
   - Was the call hosted by a partner? (attendee domains would be the partner's, not the customer's)
4. **Re-run the script** with the corrected domain(s).

## Other Fathom operations

For operations that don't involve company lookup, use curl directly:

### List recent meetings

```bash
sh -c 'curl -s -H "X-API-Key: $FATHOM_API_KEY" "https://api.fathom.ai/external/v1/meetings?include_summary=true&include_action_items=true"'
```

### Get summary for a specific recording

```bash
sh -c 'curl -s -H "X-API-Key: $FATHOM_API_KEY" "https://api.fathom.ai/external/v1/recordings/{recording_id}/summary"'
```

### Get transcript for a specific recording

```bash
sh -c 'curl -s -H "X-API-Key: $FATHOM_API_KEY" "https://api.fathom.ai/external/v1/recordings/{recording_id}/transcript"'
```

## Available API filters

All filters can be combined:

| Parameter | Description |
| --- | --- |
| `calendar_invitees_domains[]` | Filter by attendee email domains (exact match, repeatable) |
| `created_after` | ISO 8601 timestamp lower bound |
| `created_before` | ISO 8601 timestamp upper bound |
| `recorded_by[]` | Filter by recorder email address (repeatable) |
| `teams[]` | Filter by team name (repeatable) |
| `meeting_type` | `internal`, `external`, or `all` |
| `include_summary` | Include meeting summary in response |
| `include_action_items` | Include action items in response |
| `include_transcript` | Include full transcript in response |
| `include_crm_matches` | Include CRM-matched contacts/companies |
| `cursor` | Pagination cursor from previous response's `next_cursor` |
| `limit` | Results per page (max 10) |
