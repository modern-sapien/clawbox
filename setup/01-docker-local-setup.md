# OpenClaw via Docker (Local Machine) with Ollama

## Why Local Docker?

- **Controlled directory access** — only mounted volumes are visible to OpenClaw
- **Credential isolation** — API keys and tokens stay inside the container
- **Throwaway environment** — nuke and recreate the container if anything goes wrong
- **Full local file access** — directly mount any folder on your machine
- **No ongoing cost** — runs on hardware you already own
- **Ollama on localhost** — no networking complexity, OpenClaw talks to Ollama directly

## Prerequisites

- **Docker Desktop for Windows** — [download here](https://www.docker.com/products/docker-desktop/)
- Docker Desktop requires WSL2 (it will prompt you to install it)
- Minimum 4 GB RAM available for Docker (on top of what Ollama needs)
- **Ollama** — [download here](https://ollama.com/) — install and run on your host machine

## Setup Steps

### 1. Install and Configure Ollama

1. Install [Ollama](https://ollama.com/)
2. Pull a recommended model (14B+ recommended, 8B models may hallucinate tool calls):

```bash
ollama pull qwen3
# or
ollama pull deepseek-r1
# or
ollama pull qwen2.5-coder
```

3. Verify Ollama is running:

```bash
curl http://localhost:11434/api/tags
```

> **Important:** Ollama defaults to a 2048 token context window. OpenClaw needs at least 16K-24K (64K recommended). Configure this in your model settings or via `OLLAMA_NUM_CTX=65536` environment variable.

### 2. Install Docker Desktop

1. Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Enable WSL2 integration when prompted
3. Verify installation:

```bash
docker --version
```

### 3. Run OpenClaw

**Recommended setup (hardened, with Ollama access):**

```bash
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/openclaw/workspace:/root/workspace \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

> **Ollama networking:** From inside Docker on Windows/Mac, use `host.docker.internal:11434` instead of `localhost:11434` to reach Ollama on your host machine.

### 4. Mount Your Repos

Only share folders OpenClaw actually needs:

```bash
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/openclaw/workspace:/root/workspace \
  -v /c/Users/yourname/Projects/my-repo:/root/workspace/my-repo \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

OpenClaw can then run git commands, tests, linters, etc. inside the container against your mounted repos.

> **Never mount** your entire home directory or the Docker socket.

### 5. Configure OpenClaw for Ollama

During onboarding or in `~/.openclaw/openclaw.json`, set the provider to Ollama:

```json
{
  "provider": "ollama",
  "model": "qwen3",
  "baseUrl": "http://host.docker.internal:11434"
}
```

### 6. Onboard and Configure Integrations

```bash
docker exec -it openclaw openclaw onboard
```

Configure integrations during onboarding:
- **GitHub** — OAuth or personal access token
- **Gmail** — Google OAuth via the Docker browser UI at `http://localhost:8080/browser/`
- **Slack** — Slack API (Socket Mode or HTTP Events) — not the desktop app
- **Fathom** — API key

> **OAuth quirk:** When authenticating via OAuth, OpenClaw may redirect to a non-running localhost URL. Copy that URL and paste it back into OpenClaw to complete the flow.

### 7. Alternative: Docker Compose (Easiest Path)

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
./docker-setup.sh
```

This uses the included `docker-compose.yml` and automatically creates:
- `~/.openclaw` — config, memory, API keys
- `~/openclaw/workspace` — files available to the agent

## What OpenClaw Can Do in Docker

- **Git:** clone, pull, checkout, diff, log, commit, push, create PRs via GitHub API
- **Code:** read/write files, run tests, linters, formatters, build steps
- **APIs:** Slack, Gmail, GitHub, Fathom — all via API, not desktop apps
- **Shell:** full Linux shell access within the container

## What It Cannot Do

- Control VS Code or other desktop apps on your Windows machine
- Access files/directories you haven't explicitly mounted
- Interact with your Windows clipboard or desktop environment

## Managing the Container

```bash
# View logs
docker logs -f openclaw

# Stop
docker stop openclaw

# Start
docker start openclaw

# Restart
docker restart openclaw

# Remove and recreate
docker rm -f openclaw
# Then run the docker run command again
```

## Security Best Practices

- Use hardened Docker flags: `--read-only`, `--cap-drop=ALL`, `--no-new-privileges`
- Only mount directories the agent explicitly needs
- Never mount the Docker socket (`/var/run/docker.sock`)
- Never run as root inside the container if avoidable
- Bind ports to `127.0.0.1` to prevent network exposure
- Keep Docker Desktop and OpenClaw images updated
- Local Ollama models can hallucinate tool calls (especially <14B) — Docker isolation protects you from destructive commands
- **GPU note:** Gaming or other GPU apps will push Ollama to CPU, causing slow/timed-out responses. Size your context window to fit your GPU VRAM (e.g., 16K-24K for 8GB VRAM)

## References

- [OpenClaw Docker Docs](https://docs.openclaw.ai/install/docker)
- [Ollama + OpenClaw Integration](https://docs.ollama.com/integrations/openclaw)
- [Docker Setup Script](https://github.com/openclaw/openclaw/blob/main/docker-setup.sh)
- [Run OpenClaw Securely in Docker Sandboxes](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/)
- [OpenClaw + Ollama Setup Guide](https://codersera.com/blog/openclaw-ollama-setup-guide-run-local-ai-agents-2026/)
- [OpenClaw Security Guide](https://alirezarezvani.medium.com/openclaw-security-my-complete-hardening-guide-for-vps-and-docker-deployments-14d754edfc1e)
