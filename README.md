# TNSN-DESK-

Operational repo for the TNSN local-first workstation and control surface.

## Current Node-RED scope

This repo now includes a versioned Node-RED control-layer bundle for the TNSN system:

- `node-red/flows/tnsn-telegram-control.json` — Telegram control/alert flow export.
- `node-red/config/env.example` — environment variable template for Node-RED runtime configuration.
- `scripts/install-node-red-telegram.sh` — installs the Telegram node into the active Node-RED user directory.
- `scripts/import-node-red-flow.sh` — imports the versioned flow into a running local Node-RED instance via the admin API.

## Flow intent

The included flow focuses on the currently identified blocker: the Telegram output and command layer.
It provides:

- `/status` command handling.
- `/signals` command handling by tailing recent signal history.
- a `link in` entry point for Signal Engine alerts.
- a shared Telegram sender node to centralize outbound delivery.

## Runtime variables

Copy `node-red/config/env.example` into your Node-RED environment management path or export these before launch:

- `TNSN_TELEGRAM_BOT_NAME`
- `TNSN_TELEGRAM_POLL_INTERVAL`
- `TNSN_SIGNAL_HISTORY_PATH`
- `TNSN_ALLOWED_COMMANDS`
- `TNSN_NODE_RED_API`

> Note: the Telegram bot token/chat configuration still needs to be set inside the Node-RED Telegram config node after the contrib package is installed, unless you already manage those credentials separately.
