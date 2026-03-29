# OpenClaw on Mac (M4 Max 128GB) — Coding Agent Setup

## Machine Specs

- Apple M4 Max — 16-core CPU, 40-core GPU, 16-core Neural Engine
- 128GB unified memory
- 2TB SSD

This machine handles the heavy coding work: code review, testing, complex reasoning, large codebase analysis. The Windows machine handles lightweight admin tasks separately.

## Role

- Code review and iteration
- Git workflows (clone, branch, test, commit, PR)
- Large codebase exploration with full context windows
- Running test suites, linters, build steps

## Model Selection

With 128GB unified memory you can run large models comfortably. Recommended options:

| Model | Size | RAM usage | Context | Strength |
|-------|------|-----------|---------|----------|
| devstral:24b-small-2505-q8_0 | ~26 GB | ~28-35 GB | 128K | High-quality quant of your current coding model |
| qwen3:72b-q4_K_M | ~42 GB | ~45-55 GB | 128K | Much stronger reasoning |
| deepseek-r1:70b-q4_K_M | ~42 GB | ~45-55 GB | 128K | Strong reasoning with chain-of-thought |
| devstral-small-2:24b | ~14 GB | ~16-20 GB | 256K | Newer Devstral with 256K context |

> With 128GB you can even run 70B+ models at q8 quantization or load multiple models. Pick based on what coding tasks demand.

---

## Setup: Native Install vs Docker

### Recommendation: Native Install (npm)

On macOS, Docker runs through a Linux VM which adds overhead. Apple Silicon is fast enough that the native install is the standard recommendation for Mac. With 128GB RAM, isolation concerns around memory pressure don't apply.

However, if you still want Docker isolation, the Docker path works too — instructions included below for both.

---

## Option A: Native Install

### 1. Install Prerequisites

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js 22+
brew install node@22

# Verify
node --version  # must be >= 22
```

### 2. Install Ollama

```bash
brew install ollama

# Start Ollama
ollama serve
```

> On Mac, Ollama runs natively on Apple Silicon and uses unified memory for GPU acceleration — no separate VRAM needed.

### 3. Pull Your Coding Model

```bash
# Pick one based on your preference:
ollama pull devstral:24b-small-2505-q8_0
# or for stronger reasoning:
ollama pull qwen3:72b-q4_K_M
```

Verify it's running:

```bash
ollama list
curl http://localhost:11434/api/tags
```

### 4. Install OpenClaw

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

The onboarding wizard will ask:
- **Provider:** Ollama / local model
- **Model:** your chosen model name (e.g., `devstral:24b-small-2505-q8_0`)
- **Base URL:** `http://localhost:11434`
- **Messaging platform:** your choice (Discord, Slack, web UI, etc.)

### 5. Configure for Coding

The config lives at `~/.openclaw/openclaw.json`. Ensure the model config looks like:

```json
{
  "models": {
    "providers": [
      {
        "name": "ollama",
        "baseUrl": "http://127.0.0.1:11434/v1",
        "apiKey": "ollama-local",
        "api": "openai-completions"
      }
    ],
    "list": [
      {
        "id": "devstral:24b-small-2505-q8_0",
        "name": "Devstral Small 24B Q8",
        "provider": "ollama",
        "contextWindow": 131072,
        "maxTokens": 8192
      }
    ]
  }
}
```

> **Critical:** Use `"api": "openai-completions"` for Ollama — not `"openai-responses"`. Wrong adapter causes silent failures.

With 128GB, you can safely set `contextWindow` to the model's full supported length (128K or 256K depending on model).

### 6. Connect Integrations

```bash
# GitHub — main integration for coding work
openclaw config github
```

Use a personal access token (https://github.com/settings/tokens) with `repo`, `read:org` scopes.

Other integrations (if you want this machine to also handle some admin):

```bash
openclaw config slack
openclaw config gmail
```

### 7. Verify

```bash
# Check the daemon is running
openclaw status

# Check Ollama connectivity
curl http://localhost:11434/api/tags

# Test via web UI
open http://localhost:18789
```

---

## Option B: Docker Install

### 1. Install Prerequisites

```bash
# Install Docker Desktop for Mac
brew install --cask docker

# Install Ollama (runs on host, not in Docker)
brew install ollama
ollama serve
```

### 2. Pull Your Model

```bash
ollama pull devstral:24b-small-2505-q8_0
```

### 3. Test Docker-to-Ollama Connectivity

```bash
docker run --rm curlimages/curl curl -s http://host.docker.internal:11434/api/tags
```

Must return your model list.

### 4. Run OpenClaw Container

```bash
docker run -d \
  --name openclaw \
  --restart unless-stopped \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -v ~/.openclaw:/root/.openclaw \
  -v ~/openclaw/workspace:/root/workspace \
  -v ~/Projects/YOUR_REPO:/root/workspace/YOUR_REPO \
  -p 127.0.0.1:18789:18789 \
  ghcr.io/openclaw/openclaw:latest
```

### 5. Onboard

```bash
docker exec -it openclaw openclaw onboard
```

- **Provider:** Ollama
- **Base URL:** `http://host.docker.internal:11434`
- **Model:** your chosen model

### 6. Manual Config (if needed)

Same as native install config above, but change the baseUrl:

```json
"baseUrl": "http://host.docker.internal:11434/v1"
```

---

## macOS-Specific Notes

- **Docker overhead on Mac:** Docker Desktop runs a Linux VM on macOS, which adds ~10-15% overhead. With 128GB this is negligible, but native install avoids it entirely.
- **Unified memory advantage:** Ollama on Apple Silicon uses the same memory pool for CPU and GPU — no separate VRAM allocation. Models load faster and run efficiently.
- **Energy efficiency:** M4 Max is power-efficient enough to run Ollama 24/7 at minimal electricity cost.
- **Launchd daemon:** `openclaw onboard --install-daemon` installs a launchd service so OpenClaw starts automatically on boot (native install only).

## Two-Machine Architecture

| Machine | Role | Model | OpenClaw tasks |
|---------|------|-------|---------------|
| **Windows (32GB)** | Admin assistant | qwen3.5:9b-q4_K_M | Email, Fathom notes, Slack, web research |
| **Mac (128GB)** | Coding agent | devstral 24B+ or 70B | Code review, git, testing, complex reasoning |

Both connect to the same GitHub, Slack, etc. via API. They operate independently.

---

## Troubleshooting

| Problem | Check |
|---------|-------|
| OpenClaw can't reach Ollama (native) | `curl http://localhost:11434/api/tags` |
| OpenClaw can't reach Ollama (Docker) | `docker exec -it openclaw curl http://host.docker.internal:11434/api/tags` |
| Slow responses | Check `ollama ps` for memory pressure; reduce context window |
| Model not loading | `ollama list` to verify model is pulled |
| Daemon not starting on boot | `launchctl list | grep openclaw` |
| Docker container won't start | `docker logs openclaw` |

## References

- [OpenClaw on Mac Guide](https://www.getopenclaw.ai/en/openclaw-mac)
- [OpenClaw Docker Docs](https://docs.openclaw.ai/install/docker)
- [Ollama + OpenClaw Integration](https://docs.ollama.com/integrations/openclaw)
- [OpenClaw on Mac Mini (similar setup)](https://boilerplatehub.com/blog/openclaw-mac-mini)
- [OpenClaw Mac Setup & Optimization](https://insiderllm.com/guides/openclaw-mac-setup-guide/)
