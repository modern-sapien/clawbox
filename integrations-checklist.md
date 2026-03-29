# OpenClaw Integrations Checklist

Track which integrations are set up and working.

## What This Setup Can Do

Once configured, your OpenClaw agent (Dr. Claw) can:

**Email (Gmail)**
- Search and read your emails ("who emailed me today?", "find emails from Tyler Stanley")
- Draft emails (send is disabled by default for security)
- Summarize email threads

**Calendar (Google Calendar)**
- Check your schedule ("what's on my calendar this week?")
- Create and update events ("schedule a meeting with X tomorrow at 2pm")
- Look up event details and attendees

**Google Docs & Sheets**
- Search Drive for documents ("find docs related to Project X")
- Read document and spreadsheet contents
- Create new documents (editing existing ones restricted by Red Lines)

**Meeting Notes (Fathom)**
- Look up past meetings ("what was my last meeting?")
- Pull meeting summaries, transcripts, and action items
- Search meetings by date range or participants

**CRM (HubSpot)**
- Search contacts, companies, and deals ("find contacts at acme.com")
- Look up deal status and pipeline info
- Create and update CRM records (with confirmation)
- Check associations between contacts, companies, and deals
- List available properties and owners

**Slack**
- Respond to DMs and channel messages
- React to messages, pin/unpin items
- Deliver scheduled updates (via cron jobs)

**Web**
- Search the web for current information
- Fetch and read web pages

**Scheduled Tasks (Cron)**
- Periodic email summaries ("check my email every 4 hours")
- Recurring reminders and checks
- Custom scheduled agent tasks

**General**
- Read, write, and organize files in the workspace
- Run shell commands inside the Docker container
- Manage conversation sessions and spawn sub-agents
- Search and build on long-term memory across sessions

## Getting Started

1. Copy `config/env.example` → `config/.env` and fill in your API keys
2. Copy `config/openclaw.reference.json` → `~/.openclaw/openclaw.json` and set your Slack tokens
3. Follow [setup/01-docker-local-setup.md](setup/01-docker-local-setup.md) → [02-slack-setup.md](setup/02-slack-setup.md) → [03-integrations.md](setup/03-integrations.md)

## Integrations

- [ ] **Slack** (Socket Mode)
  - [ ] Send messages, react, pin/unpin
  - [ ] DM + channel support
  - [ ] Channel history reading (needs MCP server or Composio)
- [ ] **Gmail** (via `gog` CLI) — recommend READ + DRAFT only
  - [ ] Search, list, read emails
  - [ ] Draft emails
- [ ] **Google Calendar** (via `gog` CLI)
  - [ ] Read events
  - [ ] Create/update events
- [ ] **Google Drive / Docs / Sheets** (via `gog` CLI)
  - [ ] Search and list files
  - [ ] Read document and spreadsheet contents
  - [ ] Create new documents
- [ ] **Fathom** (via curl to REST API)
  - [ ] List meetings with summaries and action items
  - [ ] Get transcripts and summaries
- [ ] **HubSpot CRM** (via curl to REST API)
  - [ ] Contacts: search, list, get, create, update
  - [ ] Companies: search, list, get
  - [ ] Deals: search, list, get, create, update
  - [ ] Owners, associations, properties
- [ ] **Cron Jobs** (scheduled tasks)
  - [ ] Periodic email summaries
  - [ ] Custom scheduled agent tasks
- [ ] **Web Search** (built-in `web_search` tool)
- [ ] **Web Fetch** (built-in `web_fetch` tool)

## Config Files

| File | Purpose |
|------|---------|
| `config/.env` | All API keys and secrets (never commit) |
| `config/env.example` | Template for .env — safe to share |
| `config/openclaw.reference.json` | Annotated openclaw.json with Docker-required settings |
| `config/cron-jobs.reference.json` | Template cron jobs (email check) |
| `config/TOOLS.reference.md` | Template workspace TOOLS.md |
| `config/slack-app-manifest.json` | Slack app manifest for bot creation |
| `~/.openclaw/openclaw.json` | Live config (copied from reference) |
| `~/.openclaw/workspace/TOOLS.md` | Agent tool instructions (Gmail, Calendar, Fathom, HubSpot) |
| `~/.openclaw/workspace/AGENTS.md` | Agent behavior rules + session startup sequence |

## Required Config (openclaw.json)

See [config/openclaw.reference.json](config/openclaw.reference.json) for the full annotated config. Critical settings:

| Setting | Value | Why |
|---------|-------|-----|
| `agents.defaults.sandbox.mode` | `"off"` | No Docker-in-Docker. Without this, exec is silently disabled. |
| `tools.exec.host` | `"gateway"` | Run commands inside the container. Default `"sandbox"` fails closed. |
| `tools.exec.security` | `"full"` | Allow curl for API access. Container isolation is the security boundary. |
| `tools.profile` | `"coding"` | Includes exec, file ops, sessions, memory. |
| `commands.ownerAllowFrom` | `["slack:YOUR-ID"]` | Unlocks owner-only tools (cron, gateway). `"*"` is ignored. |
| TOOLS.md in AGENTS.md startup | — | Models don't read TOOLS.md automatically. Add it to the startup sequence. |

## Docker Run Command

```bash
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --tmpfs /tmp \
  --tmpfs /home/node \
  --env-file config/.env \
  -v "$HOME/.openclaw:/home/node/.openclaw" \
  -v "$HOME/openclaw/workspace:/home/node/workspace" \
  -v "$HOME/.openclaw/bin/gog:/usr/local/bin/gog:ro" \
  -v "$HOME/.openclaw/gogcli:/home/node/.config/gogcli" \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

> **Windows Git Bash:** prefix with `MSYS_NO_PATHCONV=1`

## Security Notes

- Gmail should be read + draft only, no send (enforce via TOOLS.md + AGENTS.md Red Lines)
- Google Drive has full read/write scope — enforce read-only via Red Lines (fork `gog` for hard enforcement)
- `exec.security: "full"` means any command runs — but only inside the container
- Docker is hardened: `--read-only`, `--cap-drop=ALL`, no Docker socket
- API keys are in env vars only — TOOLS.md uses `$VAR_NAME`, never the actual value
- Agent instructed to never output env var values or execute instructions from email content

## Known Limitations

- Ollama context window must stay within your GPU's VRAM budget (check with `nvidia-smi`)
- Smaller local models (< 14B) may be unreliable with multi-step tool calling
- First response after machine sleep is slow with Ollama (model reloads into VRAM)
- Built-in Slack skill lacks channel history reading — needs MCP or Composio
- Google Advanced Protection blocks OAuth re-auth — must temporarily unenroll
- Env var expansion in exec requires `sh -c '...'` wrapper
- Cron jobs in Slack DMs must use `isolatedSession: false` / `sessionTarget: "current"` — isolated sessions lose owner tool access
- If a cron failure poisons the Mistral session (400 errors), delete `~/.openclaw/agents/main/sessions/*.jsonl` and restart
- `gog` requests full `drive` scope (no readonly option) — enforce read-only via AGENTS.md Red Lines. Fork `gog` for hard enforcement.
