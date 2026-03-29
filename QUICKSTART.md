# Quickstart

Get OpenClaw running in Docker with Slack, Gmail, Calendar, Fathom, and HubSpot in ~15 minutes.

## Prerequisites

**Required:**
- Docker Desktop installed and running
- A Slack workspace where you can install apps (admin or app install permissions)

**At least one LLM provider (pick one):**
- Mistral API key — [console.mistral.ai](https://console.mistral.ai) (recommended, free tier available)
- OpenAI API key — [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- Ollama running locally — [ollama.com](https://ollama.com) (free, no API key needed)

**For Gmail / Calendar / Drive integration:**
- A Google account
- A Google Cloud project with OAuth 2.0 credentials (Desktop app type)
- Gmail API, Calendar API, and Google Drive API enabled on the project
- If Google Advanced Protection is enabled: you'll need to temporarily unenroll during OAuth setup, then re-enroll

**For Fathom integration (optional):**
- Fathom account with API access
- API key from Fathom Settings → API → Generate key

**For HubSpot integration (optional):**
- HubSpot account with admin access
- Private App access token from Settings → Integrations → Private Apps
- Scopes needed: `crm.objects.contacts.read`, `crm.objects.companies.read`, `crm.objects.deals.read` (add `.write` scopes if you want the agent to update records)

## 1. Build the Docker image

```bash
docker pull ghcr.io/openclaw/openclaw:latest
```

## 2. Set up secrets

```bash
cp config/env.example config/.env
```

Edit `config/.env` and fill in your API keys.

## 3. Set up the config

```bash
mkdir -p ~/.openclaw
cp config/openclaw.reference.json ~/.openclaw/openclaw.json
```

Edit `~/.openclaw/openclaw.json`:
- Replace `xoxb-YOUR-BOT-TOKEN` with your Slack bot token
- Replace `xapp-YOUR-APP-TOKEN` with your Slack app token
- Replace `GENERATE-A-RANDOM-TOKEN-HERE` with output of `openssl rand -hex 24`
- Replace `YOUR-SLACK-USER-ID` with your Slack member ID (Profile → ⋯ → Copy member ID)

## 4. Set up the Slack app

1. Go to https://api.slack.com/apps → Create New App → From manifest
2. Paste contents of `config/slack-app-manifest.json`
3. Install to workspace → copy the Bot Token (`xoxb-...`)
4. Basic Information → App-Level Tokens → Generate with `connections:write` scope → copy (`xapp-...`)
5. Put both tokens in `~/.openclaw/openclaw.json`

## 5. Set up Gmail & Calendar

Install `gog` CLI on your host machine:

```bash
# Windows
curl -sL -o gogcli.zip https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_windows_amd64.zip
unzip gogcli.zip -d ~/.local/bin/

# Mac (Apple Silicon)
curl -sL -o gogcli.tar.gz https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_darwin_arm64.tar.gz
tar -xzf gogcli.tar.gz -C ~/.local/bin/
```

Create a Google Cloud OAuth client:
1. Go to https://console.cloud.google.com
2. Create/select a project
3. Enable Gmail API, Calendar API, Google Drive API
4. Credentials → Create OAuth 2.0 Client ID (Desktop app)
5. Download `client_secret_*.json`

Authenticate:
```bash
gog auth credentials /path/to/client_secret.json
gog auth add you@gmail.com --services gmail,calendar,drive,docs,sheets
```

> **Google Advanced Protection users:** temporarily unenroll, authenticate, then re-enroll. The token persists.

Install Linux binary and export token for Docker:
```bash
# Download Linux binary for inside the container
mkdir -p ~/.openclaw/bin
curl -sL https://github.com/steipete/gogcli/releases/latest/download/gogcli_0.12.0_linux_amd64.tar.gz | tar -xz -C ~/.openclaw/bin/
chmod +x ~/.openclaw/bin/gog

# Export credentials
mkdir -p ~/.openclaw/gogcli
cp ~/AppData/Roaming/gogcli/credentials.json ~/.openclaw/gogcli/   # Windows
# cp ~/Library/Application\ Support/gogcli/credentials.json ~/.openclaw/gogcli/  # Mac
gog auth tokens export you@gmail.com --out ~/.openclaw/gogcli/token.json
```

## 6. Set up workspace files

```bash
mkdir -p ~/.openclaw/workspace
cp config/TOOLS.reference.md ~/.openclaw/workspace/TOOLS.md
cp config/AGENTS.reference.md ~/.openclaw/workspace/AGENTS.md
```

Edit `~/.openclaw/workspace/TOOLS.md` — replace placeholder values with your own. `AGENTS.md` is pre-configured with TOOLS.md in the startup sequence and security Red Lines.

## 7. Start the container

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

## 8. Import gog token into the container

```bash
docker exec -e GOG_KEYRING_PASSWORD=openclaw-local openclaw gog auth keyring file
docker exec -e GOG_KEYRING_PASSWORD=openclaw-local openclaw gog auth tokens import /home/node/.config/gogcli/token.json
```

## 9. (Optional) Set up recurring email check

Copy the cron jobs template:
```bash
mkdir -p ~/.openclaw/cron
cp config/cron-jobs.reference.json ~/.openclaw/cron/jobs.json
```

Edit `~/.openclaw/cron/jobs.json`:
- Replace `YOUR_SLACK_USER_ID_LOWERCASE` with your Slack member ID in lowercase (e.g., `u04p211kwr5`)
- Adjust `everyMs` for frequency (14400000 = 4 hours, 3600000 = 1 hour)

Or skip this and ask Dr. Claw in Slack: "Create a cron job to check my email every 4 hours. Use the current session, not isolated."

## 10. Verify

```bash
# Check it's running
docker logs openclaw --tail 5

# Should see:
# [gateway] agent model: mistral/mistral-small-latest
# [slack] socket mode connected
```

Send a DM to your bot in Slack. Try:
- "What's on my calendar this week?"
- "Who sent my last email?"
- "What was my last Fathom meeting?"
- "Search HubSpot for contacts at acme.com"

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Agent says "I don't have access" to everything | Check `sandbox.mode: "off"` and `exec.host: "gateway"` in openclaw.json |
| `[tools]` warning about `cron` | Add `ownerAllowFrom: ["slack:YOUR-ID"]` to `commands` in openclaw.json |
| Stale session remembers old restrictions | Delete session: `docker exec openclaw find /home/node/.openclaw/agents/main/sessions/ -name "*.jsonl" -exec rm {} \;` then `docker restart openclaw` |
| Container crash-loops | Check `--tmpfs /tmp --tmpfs /home/node` in docker run command |
| Volume mount errors on Windows | Prefix with `MSYS_NO_PATHCONV=1` |
| Gmail/Calendar 401 | Re-export and re-import gog token (step 5 + 8) |
| Cron jobs not delivering to Slack DMs | Cron must use `isolatedSession: false` / `sessionTarget: "current"`. Isolated sessions lose owner tool access. |
| Mistral 400 errors after failed cron | Session poisoned. Delete `~/.openclaw/agents/main/sessions/*.jsonl` and restart |
| Google Drive full write scope | `gog` requests full `drive` scope. Enforce read-only via AGENTS.md Red Lines. Fork `gog` to change scope to `drive.readonly`. |

See [troubleshooting.md](troubleshooting.md) for the full list.

## CLI Access

The full OpenClaw CLI is available inside the container:

```bash
# Health check and auto-fix
docker exec openclaw openclaw doctor

# Terminal chat UI (alternative to Slack)
docker exec -it openclaw openclaw tui

# List skills
docker exec openclaw openclaw skills list

# Manage cron jobs
docker exec openclaw openclaw cron list

# View sessions
docker exec openclaw openclaw sessions

# Security audit
docker exec openclaw openclaw security audit
```
