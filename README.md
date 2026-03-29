# OpenClaw Docker Setup

A best-practice guide for running OpenClaw as a personal AI assistant in Docker with Slack, Gmail, Calendar, Fathom, and HubSpot integrations.

## Why Docker?

- **Isolation** — the agent can only access what you mount. Your files, browser, SSH keys, etc. are invisible.
- **Hardened by default** — `--read-only`, `--cap-drop=ALL`, no Docker socket.
- **Secrets stay hidden** — API keys live in env vars, never in the agent's context.
- **Reproducible** — rebuild from scratch anytime with one command.
- **Free** — runs on hardware you already own.

## Quick Start

1. [Build the Docker image](setup/01-docker-local-setup.md)
2. [Create and connect Slack app](setup/02-slack-setup.md)
3. [Set up integrations](setup/03-integrations.md) (Gmail, Calendar, Fathom, HubSpot)

Or the 60-second version:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw && docker build -t ghcr.io/openclaw/openclaw:latest .
cp config/env.example config/.env    # fill in your API keys
cp config/openclaw.reference.json ~/.openclaw/openclaw.json  # set your Slack tokens
docker run -d --name openclaw --restart unless-stopped \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  --tmpfs /tmp --tmpfs /home/node \
  --env-file config/.env \
  -v "$HOME/.openclaw:/home/node/.openclaw" \
  -v "$HOME/openclaw/workspace:/home/node/workspace" \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

## Directory Structure

```
setup/                              Step-by-step guides
  01-docker-local-setup.md            Docker + Ollama install
  02-slack-setup.md                   Slack app creation and connection
  03-integrations.md                  Gmail, Calendar, Fathom, HubSpot setup
  install-guide-claude-assisted.md    Detailed Windows walkthrough (Claude Code assisted)
  mac-coding-setup.md                Mac setup for coding agent use case

reference/                          How things work
  docker-config.md                    Critical Docker config and why each setting matters
  workspace-files.md                  AGENTS.md, TOOLS.md, SOUL.md explained
  vps-hetzner-setup.md               VPS alternative (not recommended for local models)

config/                             Config files and templates
  env.example                         Template .env — copy to .env, fill in your keys
  openclaw.reference.json             Annotated openclaw.json with Docker-required settings
  slack-app-manifest.json             Slack app manifest for bot creation
  .env                                Your secrets (do not commit)

troubleshooting.md                  Common issues and how to fix them
integrations-checklist.md           Status tracker for all integrations
```

## What Integrations Work?

| Service | Method | Access |
|---------|--------|--------|
| **Slack** | Socket Mode (built-in) | Send, react, pin, DMs, channels |
| **Gmail** | `gog` CLI via exec | Read-only (configurable) |
| **Google Calendar** | `gog` CLI via exec | Read + create/update |
| **Fathom** | curl via exec | Meetings, transcripts, summaries |
| **HubSpot** | curl via exec | Contacts, companies, deals, associations |
| **Web** | Built-in tools | web_search, web_fetch |

## Key Config for Docker

These three settings are **required** and not documented in the official OpenClaw Docker docs:

```json
{
  "agents": { "defaults": { "sandbox": { "mode": "off" } } },
  "tools": { "exec": { "host": "gateway", "security": "full" } }
}
```

Without them, the `exec` tool is silently disabled and the agent can't run any CLI commands. See [reference/docker-config.md](reference/docker-config.md) for the full explanation.

## Security Model

- **Docker** is the blast radius wall — agent can only touch mounted volumes
- **Env vars** keep API keys out of the agent's context (uses `sh -c '$VAR'` pattern)
- **AGENTS.md Red Lines** instruct the agent to never send emails, leak keys, or execute email content
- **Read-only filesystem** + `--cap-drop=ALL` limit what the container itself can do
- **No Docker socket** — agent cannot escape to the host

See [setup/03-integrations.md](setup/03-integrations.md) for the hardened Docker run command.

## Models

Works with any provider OpenClaw supports. Tested with:

- **Mistral** (API) — best tool-calling reliability, recommended
- **Ollama** (local) — free, private, but slower and less reliable with tools
- **OpenAI** (API) — works, most expensive

Switch models anytime: `/config set agents.defaults.model.primary <provider/model>` in Slack, then `docker restart openclaw`.

## License

This guide is provided as-is. OpenClaw itself is [MIT licensed](https://github.com/openclaw/openclaw/blob/main/LICENSE).
