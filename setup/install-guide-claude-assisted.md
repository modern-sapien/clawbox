# OpenClaw Local Install — Claude-Assisted Walkthrough

Instructions for Claude Code to assist the user through a local Docker + Ollama install of OpenClaw on Windows 11.

---

## Pre-Flight Checks

Run these to assess what's already installed and what needs setting up:

```bash
# Check if Docker is installed and running
docker --version
docker info

# Check if WSL2 is available
wsl --list --verbose

# Check if Ollama is installed and running
ollama --version
curl http://localhost:11434/api/tags

# Check available RAM (need enough for Ollama model + Docker)
systeminfo | findstr /C:"Total Physical Memory"

# Check available disk space
wmic logicaldisk get size,freespace,caption
```

### Decision point: what's missing?

| Check | If missing |
|-------|-----------|
| WSL2 | User must run `wsl --install` in admin PowerShell and reboot |
| Docker Desktop | User must download and install from https://www.docker.com/products/docker-desktop/ |
| Ollama | User must download and install from https://ollama.com/ |

> **Note:** WSL2 and Docker Desktop installs require user action (admin privileges, GUI installers, reboots). Claude Code cannot do these steps — guide the user through them and wait for confirmation before continuing.

---

## Phase 1: Ollama Setup

### 1.1 Verify Ollama is running

```bash
curl http://localhost:11434/api/tags
```

If this returns a JSON response, Ollama is running. If it fails, tell the user to start Ollama (it should be in their system tray or launch via `ollama serve`).

### 1.2 Pull a model

User's model: **qwen3.5:9b-q4_K_M** (admin tasks — email, Fathom, Slack, web research)

- **Qwen 3.5 9B** — lightweight, fast, multimodal (text + vision)
- **9.7B parameters, q4_K_M quantization** — ~6.6 GB file size, ~8-10 GB RAM usage
- **256K context window** (max supported)
- **Tool calling support** — native, built-in
- **Role:** Admin assistant on Windows (32GB). Heavy coding work goes to the Mac (128GB).

Pull the model:

```bash
ollama pull qwen3.5:9b-q4_K_M
```

Verify the model is available:

```bash
ollama list | grep qwen3.5
```

### 1.3 Set context window

Ollama defaults to 2048 tokens — OpenClaw needs much more. With ~8-10 GB model usage on 32GB RAM, you have plenty of headroom. Test at 32K:

```bash
# Test with extended context
curl http://localhost:11434/api/generate -d '{
  "model": "qwen3.5:9b-q4_K_M",
  "prompt": "Hello",
  "options": { "num_ctx": 32768 }
}'
```

Then check `ollama ps` to confirm RAM usage is comfortable. On 32GB you can likely push to 64K+ with this small model.

> **Note:** Context window is set per-request by OpenClaw via the config, not globally in Ollama.

---

## Phase 2: Docker Setup

### 2.1 Verify Docker is running

```bash
docker info
```

If this fails, tell the user to start Docker Desktop.

### 2.2 Test Docker can reach Ollama on the host

```bash
docker run --rm curlimages/curl curl -s http://host.docker.internal:11434/api/tags
```

This must return Ollama's model list. If it fails:
- Ollama may not be running
- Docker Desktop networking may need a restart
- Firewall may be blocking the connection

### 2.3 Create workspace directories

```bash
mkdir -p ~/openclaw/workspace
mkdir -p ~/.openclaw
```

### 2.4 Identify repos/directories to mount

Ask the user which directories OpenClaw should have access to. Common examples:

```
/c/Users/yourname/Projects/repo-name
/c/Users/yourname/OneDrive/Desktop/code/example
```

Build `-v` flags for each. **Never mount the entire home directory or Docker socket.**

---

## Phase 3: Deploy OpenClaw Container

### 3.1 Run the container

Build the command using the user's chosen directories. Template:

```bash
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/openclaw/workspace:/root/workspace \
  -v /c/Users/yourname/Projects/REPO_NAME:/root/workspace/REPO_NAME \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

### 3.2 Verify the container is running

```bash
docker ps --filter name=openclaw
docker logs openclaw
```

### 3.3 If the container fails to start

Common issues:
- **Read-only filesystem errors** — some versions need writable temp dirs. Try adding `-v /tmp` or removing `--read-only` temporarily.
- **Port conflict** — something else on 18789. Check with `netstat -an | grep 18789`.
- **Image pull failure** — network issue. Retry `docker pull ghcr.io/openclaw/openclaw:latest` first.

---

## Phase 4: Configure OpenClaw for Ollama

### 4.1 Run onboarding

```bash
docker exec -it openclaw openclaw onboard
```

During onboarding:
- **Provider:** Select Ollama / local model
- **Model:** Enter the model name pulled in Phase 1 (e.g., `qwen3.5:9b-q4_K_M`)
- **Base URL:** `http://host.docker.internal:11434`
- **Skip API key** (not needed for Ollama)

### 4.2 If onboarding doesn't offer Ollama, manually configure

Write the config directly:

```bash
docker exec -it openclaw cat /root/.openclaw/openclaw.json
```

The config should include (adapt model name to what the user pulled):

```json
{
  "models": {
    "providers": [
      {
        "name": "ollama",
        "baseUrl": "http://host.docker.internal:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions"
      }
    ],
    "list": [
      {
        "id": "qwen3.5:9b-q4_K_M",
        "name": "Qwen 3.5 9B",
        "provider": "ollama",
        "contextWindow": 32768,
        "maxTokens": 8192
      }
    ]
  }
}
```

> **Critical:** Use `"api": "openai-completions"` for Ollama — not `"openai-responses"`. Wrong adapter causes silent failures.

### 4.3 Verify LLM connectivity from inside the container

```bash
docker exec -it openclaw curl -s http://host.docker.internal:11434/api/tags
```

Should return the list of models.

---

## Phase 5: Connect Integrations

### 5.1 GitHub

```bash
docker exec -it openclaw openclaw config github
```

Options:
- **Personal access token (easiest):** User creates one at https://github.com/settings/tokens with repo, read:org scopes
- **OAuth:** Follow the browser flow

### 5.2 Gmail

```bash
docker exec -it openclaw openclaw config gmail
```

Requires Google OAuth. The Docker browser UI at `http://localhost:8080/browser/` handles the auth flow. Warn the user about the OAuth redirect quirk — they may need to copy-paste a localhost URL back into OpenClaw.

### 5.3 Slack

```bash
docker exec -it openclaw openclaw config slack
```

Uses Slack API (Socket Mode or HTTP Events). User needs to create a Slack app at https://api.slack.com/apps with appropriate scopes.

### 5.4 Fathom

```bash
docker exec -it openclaw openclaw config fathom
```

API key from Fathom dashboard.

---

## Phase 6: Verify Everything Works

### 6.1 Test the chat interface

Access `http://localhost:18789` in a browser and send a test message.

### 6.2 Test git access

```bash
docker exec -it openclaw bash -c "cd /root/workspace/REPO_NAME && git status"
```

### 6.3 Test Ollama is responding through OpenClaw

Send a simple prompt through the web UI or connected chat channel and confirm a response comes back.

### 6.4 Test integrations

Ask OpenClaw to:
- List recent GitHub notifications
- Check Gmail inbox
- Send a test Slack message to yourself

---

## Troubleshooting Quick Reference

| Problem | Check |
|---------|-------|
| OpenClaw can't reach Ollama | `docker exec -it openclaw curl http://host.docker.internal:11434/api/tags` |
| Slow/garbage responses | Model context too small — check `num_ctx` in config is ≥16384 |
| Container won't start | `docker logs openclaw` — check for filesystem or port errors |
| OAuth redirect fails | Copy the failed localhost URL and paste it back into OpenClaw |
| Git permission denied | Check volume mount paths and permissions |
| Model OOMs | Reduce `contextWindow` in config or switch to a smaller model |
| Tool calls hallucinated | Model too small (<14B) — upgrade model |

---

## References

- [OpenClaw Windows/WSL2 Docs](https://docs.openclaw.ai/platforms/windows)
- [OpenClaw Docker Docs](https://docs.openclaw.ai/install/docker)
- [Ollama + OpenClaw Integration](https://docs.ollama.com/integrations/openclaw)
- [Ollama OpenClaw Tutorial](https://ollama.com/blog/openclaw-tutorial)
- [OpenClaw Config Example](https://gist.github.com/digitalknk/4169b59d01658e20002a093d544eb391)
- [Context Window Bug (known issue)](https://github.com/openclaw/openclaw/issues/24068)
- [Silent Failures with Ollama](https://medium.com/@rogerio.a.r/setting-up-a-private-local-llm-with-ollama-for-use-with-openclaw-a-tale-of-silent-failures-01cadfee717f)
