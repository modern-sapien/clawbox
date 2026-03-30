# OpenClaw Integrations Setup (Docker)

How to connect Gmail, Google Calendar, and Fathom to OpenClaw running in Docker.

## Prerequisites

- OpenClaw Docker container running (see [01-docker-local-setup.md](01-docker-local-setup.md))
- Slack connected (see [02-slack-setup.md](02-slack-setup.md))

## Gmail & Google Calendar (via `gog` CLI)

### 1. Create a Google Cloud OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or use existing)
3. Enable **Gmail API** and **Calendar API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Application type: **Desktop app**
6. Download the `client_secret_*.json` file

### 2. Install `gog` CLI (on your host machine)

```bash
# Windows — download from GitHub releases
curl -sL -o gogcli.zip https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_windows_amd64.zip
unzip gogcli.zip -d ~/.local/bin/
```

### 3. Authenticate

```bash
gog auth credentials /path/to/client_secret.json
gog auth add you@gmail.com --services gmail,calendar,drive,docs,sheets
```

This opens a browser for OAuth consent. If you have Google Advanced Protection enabled, you must temporarily unenroll, authenticate, then re-enroll. The refresh token persists after re-enrollment.

> **Google Cloud APIs:** You must enable Gmail API, Calendar API, and Google Drive API in your Google Cloud project. Docs and Sheets APIs are optional (they use Drive for search/listing). Enable at: `console.developers.google.com/apis`

> **Scope warning:** `gog` requests full `drive` scope (read/write/delete). There is no `drive.readonly` option. Enforce read-only access via AGENTS.md Red Lines and TOOLS.md instructions. If you need hard enforcement, fork `gog` and change the scope string to `drive.readonly`. See [reference/docker-config.md](../reference/docker-config.md) for security model details.

### 4. Export token to file-based keyring

```bash
# Switch to file keyring (needed for Docker)
gog auth keyring file

# Export token from system keyring
gog auth tokens export you@gmail.com
# Token saved to ~/.openclaw/gogcli/token.json (or wherever you specify)
```

### 5. Install `gog` Linux binary for the container

```bash
# Download Linux binary
curl -sL -o /tmp/gogcli_linux.tar.gz https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz
tar -xzf /tmp/gogcli_linux.tar.gz -C /tmp/

# Copy to a persistent location
mkdir -p ~/.openclaw/bin
cp /tmp/gog ~/.openclaw/bin/gog
chmod +x ~/.openclaw/bin/gog

# Copy credentials
mkdir -p ~/.openclaw/gogcli
cp ~/AppData/Roaming/gogcli/credentials.json ~/.openclaw/gogcli/
```

### 6. Import token inside the container

After starting the container with the mounts (see Docker run command below):

```bash
docker exec -e GOG_KEYRING_PASSWORD=openclaw-local openclaw gog auth keyring file
docker exec -e GOG_KEYRING_PASSWORD=openclaw-local openclaw gog auth tokens import /home/node/.config/gogcli/token.json
```

### 7. Verify

```bash
docker exec -e GOG_KEYRING_PASSWORD=openclaw-local -e GOG_ACCOUNT=you@gmail.com openclaw gog gmail search 'newer_than:1d' --max 3
```

## Fathom (Meeting Notes)

Fathom uses a simple REST API with an API key. The Fathom skill handles all meeting lookups automatically — no TOOLS.md configuration needed.

### 1. Get your API key

Go to [Fathom Settings](https://fathom.video/settings) → API → Generate key.

### 2. Add API key to `.env`

Add to `config/.env`:

```bash
FATHOM_API_KEY=your-fathom-api-key
```

### 3. Install the Fathom skill

```bash
cp -r config/skills/fathom ~/.openclaw/workspace/skills/fathom
chmod +x ~/.openclaw/workspace/skills/fathom/scripts/fathom-search.sh
```

The skill auto-loads on container start — no additional configuration needed. It triggers automatically when the agent handles meeting/call/transcript queries and uses domain-based filtering to find calls for specific companies.

## Docker Run Command (with all integrations)

> **Windows (Git Bash) users:** prefix with `MSYS_NO_PATHCONV=1` to prevent path mangling. On Mac/Linux, omit it.

```bash
# Windows Git Bash: add MSYS_NO_PATHCONV=1 before docker
# Mac/Linux: run as-is
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

## Required openclaw.json Config

These settings are **required** for integrations to work in Docker:

```json
{
  "agents": {
    "defaults": {
      "sandbox": { "mode": "off" }
    }
  },
  "tools": {
    "profile": "coding",
    "exec": {
      "host": "gateway",
      "security": "full",
      "ask": "off"
    }
  }
}
```

- `sandbox.mode: "off"` — no Docker-in-Docker available, disables sandbox
- `exec.host: "gateway"` — run commands inside the container, not in a sandbox
- `exec.security: "full"` — allows curl for Fathom API access

## Workspace Files

The agent reads `TOOLS.md` at session startup for tool instructions. Add all CLI commands and API examples there. See [workspace-files.md](../reference/workspace-files.md) for how workspace files work.

Critical: add `TOOLS.md` to the session startup list in `AGENTS.md`:

```markdown
## Session Startup

Before doing anything else:

1. Read `SOUL.md`
2. Read `USER.md`
3. Read `TOOLS.md` ← this line is essential
4. Read `memory/YYYY-MM-DD.md`
5. If in MAIN SESSION: Also read `MEMORY.md`
```

Without this, the model won't know about your tools until you manually tell it to read TOOLS.md.
