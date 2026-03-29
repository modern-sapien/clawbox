# Docker Gateway Config Reference

Critical configuration for running OpenClaw in Docker. These were discovered through troubleshooting — the official docs don't cover all of them.

## Must-Have Settings

### Sandbox mode off

```json
{ "agents": { "defaults": { "sandbox": { "mode": "off" } } } }
```

**Why:** Default sandbox mode tries to spin up Docker-in-Docker containers for exec. Without the Docker socket mounted (which you shouldn't do), this fails silently and the `exec` tool is disabled entirely. The agent can't run any shell commands.

**Symptom:** Agent says "I don't have access" to everything despite having `exec` in its tool list.

### Exec host = gateway

```json
{ "tools": { "exec": { "host": "gateway" } } }
```

**Why:** Default `exec.host` is `"sandbox"`. With sandbox off, `host=sandbox` fails closed — exec is blocked. Must explicitly set to `"gateway"` so commands run inside the container.

### Exec security

```json
{ "tools": { "exec": { "security": "full" } } }
```

Options:
- `"full"` — any command allowed. Use this if your container is already isolated.
- `"allowlist"` — only allowlisted binaries. Note: `safeBins` is for stdin-only filters (cut, head, tail), NOT for CLIs like curl or gog. Use `exec-approvals.json` for real allowlisting.
- `"deny"` — exec disabled.

### Tmpfs mounts

```bash
--tmpfs /tmp --tmpfs /home/node
```

**Why:** `--read-only` flag prevents writing to the filesystem. OpenClaw needs `/tmp` for logs and temp files, and `/home/node` for runtime state.

### Volume mount paths

```bash
-v "$HOME/.openclaw:/home/node/.openclaw"   # NOT /root/.openclaw
```

**Why:** Container runs as `node` user (uid 1000), not root. Config lives at `/home/node/.openclaw`.

### Owner allowlist (for cron and gateway tools)

```json
{ "commands": { "ownerAllowFrom": ["slack:YOUR-SLACK-USER-ID"] } }
```

**Why:** The `cron` and `gateway` tools are marked `ownerOnly`. Without this setting, no Slack user is recognized as the owner and these tools are silently stripped from the agent's tool list.

**How to find your Slack ID:** In Slack, click your profile picture → Profile → ⋯ → Copy member ID.

**Note:** The `"*"` wildcard is intentionally ignored for security. You must use your actual Slack user ID prefixed with `slack:`.

**Symptom:** `[tools] tools.profile (coding) allowlist contains unknown entries (cron)` in logs.

### Cron jobs with Slack DMs

When the agent creates cron jobs via chat, they must use `isolatedSession: false` (or `sessionTarget: "current"`) to run within the existing DM session. Without this, cron runs spawn isolated sessions that lose owner context — exec and other `ownerOnly` tools get stripped, and the job fails silently or errors.

**What works:**
- Cron jobs created in chat with `sessionTarget: "current"` — runs in your DM session, has all tools
- Ask the agent to create the job and specify "run in current session" or "don't use isolated session"

**What doesn't work:**
- Isolated cron sessions — no owner context, no exec, no tool access
- `systemEvent` payloads to main session — don't appear in Slack DMs

**Symptom:** Cron job runs but never delivers results, or `user_not_found` errors, or `400 status code` from Mistral after a failed cron attempt poisons the session history.

**If cron poisons the session (400 errors):** Delete the session transcript and restart:
```bash
rm -f ~/.openclaw/agents/main/sessions/*.jsonl
docker restart openclaw
```

### Windows Git Bash path fix

```bash
MSYS_NO_PATHCONV=1 docker run ...
```

**Why:** Git Bash/MSYS2 on Windows mangles Linux paths (e.g., `/home` becomes `C:/Git/home`). This env var disables the conversion.

## Session Management

Sessions persist across restarts. If the model learned incorrect information in a session (e.g., "I can't run curl"), it remembers it. To force a fresh session:

```bash
# Find and delete the session transcript
docker exec openclaw ls /home/node/.openclaw/agents/main/sessions/
docker exec openclaw rm /home/node/.openclaw/agents/main/sessions/<session-id>.jsonl
docker restart openclaw
```

## Switching Models

Via Slack (if native commands enabled):
```
/config set agents.defaults.model.primary mistral/mistral-small-latest
```

Then restart: `docker restart openclaw`

Or edit `openclaw.json` directly and restart.

## Useful Commands

```bash
# Container status
docker ps --filter name=openclaw --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Recent logs
docker logs openclaw --tail 20

# Check what model is active
docker logs openclaw 2>&1 | grep "agent model" | tail -1

# Check tool warnings
docker logs openclaw 2>&1 | grep "\[tools\]"

# Run openclaw doctor
docker exec -it openclaw openclaw doctor

# List skills
docker exec openclaw openclaw skills list

# Test exec from inside container
docker exec openclaw gog gmail search 'newer_than:1d' --max 1
```
