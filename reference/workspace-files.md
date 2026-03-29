# OpenClaw Workspace Files Reference

## How the Agent Gets Its Instructions

OpenClaw injects workspace files into the agent's system prompt at the start of every session. These files live in `~/.openclaw/workspace/` and are loaded automatically — no config changes needed.

### Bootstrap Files (loaded every session)

| File | Purpose |
|------|---------|
| `AGENTS.md` | Core behavior rules, session startup, memory, red lines, group chat etiquette |
| `SOUL.md` | Agent personality and identity |
| `USER.md` | Info about you (the human) |
| `TOOLS.md` | Environment-specific tool notes (your setup, not the skill definitions) |
| `IDENTITY.md` | Additional identity context |
| `HEARTBEAT.md` | Checklist for periodic background checks |
| `BOOTSTRAP.md` | First-run instructions (deleted after first use) |
| `MEMORY.md` | Long-term curated memories |

### How It Works

1. Agent wakes up in a new session
2. OpenClaw reads all bootstrap files from the workspace
3. Front matter (YAML between `---` markers) is stripped
4. Content is injected into the system prompt under "Project Context"
5. Skills (from `/app/skills/`) are also injected based on availability
6. The model sees all of this as context before your first message

### TOOLS.md Specifically

`TOOLS.md` is **free-form markdown** — not a structured config file. It's your cheat sheet for environment-specific details the agent needs. Examples:

- CLI tools available and how to use them (like `gog` for Gmail)
- SSH hosts and credentials references
- Camera names, speaker names, device nicknames
- API endpoints or service URLs

The agent reads this and knows what tools it has access to and how to invoke them via the `exec` tool.

### Key Limits

- Max 2MB per bootstrap file
- Total bootstrap budget: ~150KB across all files
- Skills can be truncated if total prompt exceeds `maxSkillsPromptChars` (default 30K)

## Tool Profiles

`tools.profile` in `openclaw.json` controls what the agent can do:

| Profile | Tools Available |
|---------|----------------|
| `minimal` | `session_status` only |
| `coding` | File read/write/edit, exec (shell), sessions, memory, image |
| `messaging` | Messaging, sessions |
| `full` | Everything (no restrictions) |

The `coding` profile includes `group:runtime` which gives the agent `exec` — the ability to run shell commands. This is how it runs `gog`.

## Recommended Reading

- [OpenClaw Tools & Skills Tutorial (WenHao Yu)](https://yu-wenhao.com/en/blog/openclaw-tools-skills-tutorial/) — best overview of how tools and skills interact
- [Exec Tool Docs](https://docs.openclaw.ai/tools/exec) — official exec tool reference
- [OpenClaw + Google Workspace (Medium)](https://capodieci.medium.com/ai-agents-006-openclaw-google-workspace-build-an-agent-that-manages-your-gmail-and-drive-2a345a2ce7fe) — Gmail/Calendar integration walkthrough
- [Configuration Reference](https://docs.openclaw.ai/gateway/configuration-reference) — full config schema
- [Skills Truncation Issue #46623](https://github.com/openclaw/openclaw/issues/46623) — known issue with skills being silently dropped
