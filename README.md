# TNSN-DESK-

Operational repo for the TNSN local-first workstation and control surface.

## Current Node-RED scope

This repo includes a demo-ready Telegram operator control bundle for the TNSN system:

- `node-red/flows/tnsn-telegram-control.json` — Telegram control/alert flow export with a full inline operator UI.
This repo now includes a versioned Node-RED Telegram control bundle for the TNSN system:

- `node-red/flows/tnsn-telegram-control.json` — Telegram control/alert flow export with inline UI.
- `node-red/config/env.example` — environment variable template for Node-RED runtime configuration.
- `scripts/install-node-red-telegram.sh` — installs the Telegram node into the active Node-RED user directory.
- `scripts/import-node-red-flow.sh` — imports the versioned flow into a running local Node-RED instance via the admin API.
- `scripts/repair-node-red-credentials.sh` — inspects, backs up, and optionally resets broken Node-RED credential files.
- `scripts/test-node-red-flow.js` — validates the exported Node-RED flow structure, routes, and key Telegram operator behaviors.
- `scripts/telegram-operator/*.js` — local helper scripts used by Node-RED exec nodes to load status, signals, audit history, system info, and manual fetch results.

## Operator UI capabilities

The Telegram flow is designed for operator use without typing after `/start`.
It provides:

- `/start`, `/menu`, `/help`, `/status`, `/signals`, `/fetch`, `/audit`, and `/system` command handling.
- inline-button navigation for `ui:menu`, `ui:status`, `ui:signals`, `ui:fetch`, `ui:audit`, `ui:system`, and `ui:help`.
- system status with Node-RED availability, last signal fetch time, uptime, memory, and host info.
- latest signals from `signal-history.jsonl` with severity, summary, source, time, and link.
- latest audit entries from `audit.jsonl`.
- manual fetch triggering through the existing control endpoint.
- signal alert delivery into the same Telegram control surface.
- `scripts/test-node-red-flow.js` — validates the exported Node-RED flow structure, routes, and key Telegram UI behavior.

## Flow intent

The included flow focuses on the current control-layer requirement: a lightweight Telegram UI for command and alert handling.
It provides:

- `/start`, `/menu`, `/help`, `/status`, and `/signals` command handling.
- an inline keyboard UI for status, signals, help, and menu refresh actions.
- a `telegram event` callback handler for inline button presses.
- a `link in` entry point for Signal Engine alerts.
- a shared Telegram sender node to centralize outbound delivery.
- inline keyboard actions attached to system responses and alert messages.
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
- `TNSN_TELEGRAM_UI_MODE`
- `TNSN_NODE_RED_CREDENTIAL_SECRET`
- `TNSN_REPO_ROOT`
- `TNSN_SIGNAL_HISTORY_PATH`
- `TNSN_AUDIT_LOG_PATH`
- `TNSN_C2_URL`
- `TNSN_SIGNAL_FETCH_URL`
- `TNSN_NODE_RED_API`
- `TNSN_ALLOWED_COMMANDS`
- `TNSN_SIGNAL_HISTORY_PATH`
- `TNSN_ALLOWED_COMMANDS`
- `TNSN_NODE_RED_API`

> Note: the Telegram bot token/chat configuration still needs to be set inside the Node-RED Telegram config node after the contrib package is installed, unless you already manage those credentials separately.

## Credential error recovery

If Node-RED reports errors like:

- `Error loading credentials: SyntaxError: Unexpected token ! in JSON at position 0`
- `Error loading flows: Error: Failed to decrypt credentials`

then the runtime credential store is broken or encrypted with a different secret than the one currently configured.

Recommended recovery path:

1. Stop Node-RED.
2. Set a persistent `TNSN_NODE_RED_CREDENTIAL_SECRET` value.
3. Run `scripts/repair-node-red-credentials.sh --secret "$TNSN_NODE_RED_CREDENTIAL_SECRET"` to back up the runtime files and persist the secret into `settings.js`.
4. If the credential file is malformed or still undecryptable, run `scripts/repair-node-red-credentials.sh --secret "$TNSN_NODE_RED_CREDENTIAL_SECRET" --force-reset`.
5. Restart Node-RED and re-enter credentials such as the Telegram bot token.

The `--force-reset` path is intentionally explicit because it removes the existing encrypted credential file from active use and requires manual credential re-entry.

## Flow validation

Run `node scripts/test-node-red-flow.js` to validate the exported Telegram flow before importing it into Node-RED. The validator checks JSON shape, unique node IDs, valid wire targets, required Telegram nodes, command routes, callback routes, and the operator UI actions required for the demo.
Run `node scripts/test-node-red-flow.js` to validate the exported Telegram flow before importing it into Node-RED. The validator checks JSON shape, unique node IDs, valid wire targets, required Telegram nodes, command routes, callback routes, and key inline UI behaviors.
