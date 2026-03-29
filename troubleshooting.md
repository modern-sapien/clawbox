# OpenClaw Troubleshooting Log

Issues encountered during local Docker + Ollama + Slack setup on Windows 11.

---

## Issue 1: Bot starts typing but never responds (typing TTL reached 2m)

**Symptom:** Message arrives in OpenClaw (typing indicator appears in Slack), but after 2 minutes the typing stops and no response is sent.

**Root cause:** Agent-level config (`/home/node/.openclaw/agents/main/agent/models.json`) was overriding the main config (`/home/node/.openclaw/openclaw.json`). The agent config had the wrong API adapter (`openai-completions` instead of `ollama`) and wrong base URL (`/v1` suffix).

**Fix:** Both config files must be consistent. Check and update:

```bash
# Main config
docker exec openclaw bash -c "cat /home/node/.openclaw/openclaw.json"

# Agent-level config (this one overrides the main!)
docker exec openclaw bash -c "cat /home/node/.openclaw/agents/main/agent/models.json"
```

Ensure both have:
- `"api": "ollama"` (not `"openai-completions"`)
- `"baseUrl": "http://host.docker.internal:11434"` (no `/v1` suffix for ollama api mode)

After fixing, restart: `docker restart openclaw`

---

## Issue 2: Messages not reaching OpenClaw at all (no typing, no logs)

**Symptom:** Sending a DM to the bot in Slack produces no activity in OpenClaw logs whatsoever.

**Possible causes:**
1. **Missing Slack scopes** — The manifest was missing `im:read` and `im:write`. Without these, the bot can't receive or send DMs.
   - Fix: Add scopes in https://api.slack.com/apps → OAuth & Permissions → Bot Token Scopes
   - Must **reinstall the app** to workspace after adding scopes
2. **Wrong API adapter** — Switching to `openai-completions` broke event processing entirely. Messages stopped arriving.
   - Fix: Revert to `"api": "ollama"` in both config files

---

## Issue 3: Slack "missing_scope" warning on channel resolve

**Symptom:** Log shows `[slack] channel resolve failed; using config entries. Error: An API error occurred: missing_scope`

**Cause:** Bot is missing the `channels:join` scope needed to auto-resolve channel names.

**Impact:** Non-critical. OpenClaw falls back to channels listed in the config. DMs are unaffected.

**Fix (optional):** Add `channels:join` to Bot Token Scopes and reinstall the app.

---

## Issue 4: Anthropic API key errors on startup

**Symptom:** Logs show `No API key found for provider "anthropic"` and `model fallback decision: candidate=anthropic/claude-opus-4-6 reason=auth`

**Cause:** OpenClaw defaults to Anthropic as a fallback model. If you're only using Ollama, this error fires when it tries the fallback.

**Fix:** After initial onboarding, restart the container. The config reload picks up the correct Ollama-only model and the errors stop. If they persist, check that `agents.defaults.model.primary` in `openclaw.json` is set to `ollama/your-model-name`.

---

## Issue 5: Slack pairing not working

**Symptom:** Bot responds with "access not configured" and a pairing code.

**Fix:** Run the approve command with the code provided:

```bash
docker exec -it openclaw openclaw pairing approve slack <PAIRING_CODE>
```

Verify pairing stuck:

```bash
docker exec openclaw bash -c "cat /home/node/.openclaw/credentials/slack-default-allowFrom.json"
```

Should contain your Slack user ID in the `allowFrom` array.

---

## Issue 6: K8s containers consuming resources and restarting

**Symptom:** Dozens of `k8s_*` containers running alongside OpenClaw, eating RAM and CPU. Stopping them with `docker stop` doesn't persist — they restart.

**Cause:** Docker Desktop has Kubernetes enabled, which automatically recreates containers.

**Fix:**
1. Open Docker Desktop → Settings → Kubernetes
2. Uncheck "Enable Kubernetes"
3. Apply & Restart

To force-remove existing k8s containers:

```bash
docker ps --format "{{.Names}}" | grep "^k8s_" | xargs docker rm -f
```

---

## Issue 7: Container shows "Gateway failed to start: gateway already running"

**Symptom:** Log shows `Gateway failed to start: gateway already running (pid X); lock timeout after 5000ms`

**Cause:** Docker restart didn't cleanly stop the previous gateway process before starting a new one.

**Impact:** Usually resolves itself on the next restart attempt. The container will eventually start correctly.

**Fix:** If it persists:

```bash
docker rm -f openclaw
# Then re-run the docker run command
```

---

## Useful Diagnostic Commands

```bash
# Container status
docker ps --filter name=openclaw --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Recent logs
docker logs openclaw --tail 20

# Detailed log file (verbose)
docker exec openclaw bash -c "tail -50 /tmp/openclaw/openclaw-2026-03-14.log"

# Test Ollama connectivity from inside container
docker exec openclaw bash -c 'curl -s http://host.docker.internal:11434/api/tags'

# Test LLM response from inside container
docker exec openclaw bash -c 'curl -s http://host.docker.internal:11434/api/generate -d "{\"model\": \"qwen3.5:9b-q4_K_M\", \"prompt\": \"say hello\", \"stream\": false}"'

# Check main config
docker exec openclaw bash -c "cat /home/node/.openclaw/openclaw.json"

# Check agent-level config (overrides main!)
docker exec openclaw bash -c "cat /home/node/.openclaw/agents/main/agent/models.json"

# Check Slack pairing
docker exec openclaw bash -c "cat /home/node/.openclaw/credentials/slack-default-allowFrom.json"

# Test bot can send messages via Slack API
docker exec openclaw bash -c 'curl -s -X POST -H "Authorization: Bearer YOUR_BOT_TOKEN" -H "Content-Type: application/json" -d "{\"channel\": \"YOUR_USER_ID\", \"text\": \"test\"}" https://slack.com/api/chat.postMessage'

# Check Ollama memory usage
ollama ps

# Check GPU VRAM usage and competing processes
nvidia-smi
```

---

## Issue 8: Model runs on 100% CPU, responses time out (THE ROOT CAUSE)

**Symptom:** Bot starts typing but never responds. `ollama ps` shows `size_vram: 0` and `context_length: 262144`.

**Root cause:** OpenClaw's config had `"contextWindow": 262144` (256K) for qwen3.5:9b. When Ollama allocated the KV cache for 256K context, it exceeded GPU VRAM and fell back to 100% CPU. Inference on CPU with a large context is too slow — every LLM call timed out after 2 minutes.

**Fix:** Lower `contextWindow` in **both** config files to a value your GPU can handle:

```bash
# Check current GPU usage
ollama ps
# Look at size_vram vs size — if size_vram is 0, model is on CPU

# Update both configs
docker exec openclaw bash -c "sed -i 's/\"contextWindow\": 262144/\"contextWindow\": 24576/g' /home/node/.openclaw/openclaw.json"
docker exec openclaw bash -c "sed -i 's/\"contextWindow\": 262144/\"contextWindow\": 24576/g' /home/node/.openclaw/agents/main/agent/models.json"
docker restart openclaw
```

**Guidelines for context window sizing (adjust for your GPU VRAM):**
- 16K-24K: Safe, fast, good GPU offload (~4.7 GB VRAM used)
- 32K: Workable, may reduce GPU offload slightly
- 64K+: Likely pushes model off GPU entirely — avoid
- 262K: Will absolutely time out — never use this

**GPU sharing with games:**
- If your GPU has limited VRAM (8 GB or less), a game will consume most of it
- When gaming, Ollama gets pushed to CPU and responses will be slow or time out
- Check with `nvidia-smi` to see what's using the GPU
- Options: accept slower responses while gaming, pause Ollama (`ollama stop`), or use a tiny CPU-friendly model

**How to verify:** After a response, run `ollama ps` and check that `size_vram` is > 0 and the CPU/GPU split favors GPU. Run `nvidia-smi` to see total VRAM usage and competing processes.

---

## Issue 9: Stuck after machine sleep (limbo state)

**Symptom:** Machine went to sleep while OpenClaw had an active LLM request. After waking, dr-claw shows typing but never responds, or doesn't respond at all.

**Cause:** The in-flight LLM request was interrupted by sleep. When the machine wakes, the request is stuck — blocking new messages from being processed.

**How to detect:**
1. Send dr-claw a message
2. If no response or typing indicator for 2+ minutes, check logs:
   ```bash
   docker logs openclaw --since 5m
   ```
3. If you see `typing TTL reached (2m)` or no log activity after your message, it's stuck

**Fix:**
```bash
docker restart openclaw
```

**Normal behavior after sleep:** Container and Ollama auto-restart. First message after wake will be slow (model reloading into GPU), then responses return to normal. Manual restart is only needed if a request was mid-flight when sleep occurred.

---

## Key Lesson 1: Two Config Files

OpenClaw has **two** model config locations. The agent-level one overrides the main one:

1. **Main config:** `/home/node/.openclaw/openclaw.json` → `models.providers`
2. **Agent config:** `/home/node/.openclaw/agents/main/agent/models.json` → `providers`

If you change the main config but the agent config still has old values, the old values win. Always update both.

## Key Lesson 2: Volume Mount Path

OpenClaw runs as the `node` user, NOT root. The config directory is `/home/node/.openclaw`, NOT `/root/.openclaw`.

**Wrong:**
```bash
-v ~/.openclaw:/root/.openclaw  # Config won't persist!
```

**Correct:**
```bash
-v ~/.openclaw:/home/node/.openclaw
```

If the volume mount is wrong, config appears to save but is lost on container restart, reverting to Anthropic defaults.
