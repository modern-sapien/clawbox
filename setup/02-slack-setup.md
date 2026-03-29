# OpenClaw Slack Integration Setup

## Prerequisites

- OpenClaw container running
- Access to your Slack workspace (admin or ability to install apps)

## Step 1: Create the Slack App

1. Go to https://api.slack.com/apps
2. Click **Create New App**
3. Select **From an app manifest**
4. Choose your workspace
5. Paste the contents of `slack-app-manifest.json` from this directory
6. Click **Create**

## Step 2: Generate the App-Level Token (Socket Mode)

1. In the left sidebar, go to **Basic Information**
2. Scroll down to **App-Level Tokens**
3. Click **Generate Token and Scopes**
4. Name it something like `openclaw-socket`
5. Add the scope: `connections:write`
6. Click **Generate**
7. Copy the token — it starts with `xapp-`
8. Save this somewhere safe — you'll need it for OpenClaw config

## Step 3: Install the App to Your Workspace

1. In the left sidebar, go to **Install App** (or **OAuth & Permissions**)
2. Click **Install to Workspace**
3. Review the permissions and click **Allow**
4. After installing, you'll see the **Bot User OAuth Token** — it starts with `xoxb-`
5. Copy this token — you'll need it for OpenClaw config

> **Note:** You do NOT need to configure redirect URLs, token rotation, or IP restrictions for Socket Mode. Ignore those sections.

## Step 4: Provide Tokens to OpenClaw

During OpenClaw onboarding (or after), you'll be prompted for two tokens:

- **Bot Token:** `xoxb-...` (from OAuth & Permissions, after workspace install)
- **App Token:** `xapp-...` (from Basic Information > App-Level Tokens)

If configuring manually:

```bash
docker exec -it openclaw openclaw config slack
```

## Step 5: Verify the Connection

1. Open Slack
2. Find **dr-claw** in your apps / DMs
3. Send it a message
4. It should respond via qwen3.5

If it doesn't respond:
- Check OpenClaw logs: `docker logs openclaw`
- Verify Socket Mode is enabled: left sidebar > **Socket Mode** > toggle should be ON
- Verify Event Subscriptions are enabled: left sidebar > **Event Subscriptions** > toggle should be ON

## Bot Behavior Notes

- The manifest subscribes to all channel messages (`message.channels`, `message.groups`, etc.) AND `app_mention` events
- Whether the bot responds to everything or only @mentions is controlled in **OpenClaw's config**, not the Slack manifest
- The manifest just defines what events Slack sends to the bot — OpenClaw decides what to act on
- You can tighten event subscriptions later if needed

## Tokens Summary

| Token | Prefix | Where to find it | Purpose |
|-------|--------|------------------|---------|
| Bot User OAuth Token | `xoxb-` | OAuth & Permissions (after install) | Lets the bot read/write messages |
| App-Level Token | `xapp-` | Basic Information > App-Level Tokens | Enables Socket Mode connection |
