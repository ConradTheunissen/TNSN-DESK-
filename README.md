# TNSN-DESK-

Operational repo for the TNSN local-first workstation and control surface.

## Current Node-RED scope

This repo includes a demo-ready Telegram operator control bundle for the TNSN system:

- `node-red/flows/tnsn-telegram-control.json` — Telegram control/alert flow export with a full inline operator UI.
- `node-red/config/env.example` — environment variable template for Node-RED runtime configuration.
- `scripts/install-node-red-telegram.sh` — installs the Telegram node into the active Node-RED user directory.
- `scripts/import-node-red-flow.sh` — imports the versioned flow into a running local Node-RED instance via the admin API.
- `scripts/repair-node-red-credentials.sh` — inspects, backs up, and optionally resets broken Node-RED credential files.
- `scripts/test-node-red-flow.js` — validates the exported Node-RED flow structure, routes, and key Telegram operator behaviors.
- `scripts/preflight-telegram-operator.sh` — checks repo scaffold, local Node-RED runtime readiness, required helper files, log paths, and endpoint reachability before demo use.
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

Use `./scripts/preflight-telegram-operator.sh` to verify the local machine has the repo scaffold, helper scripts, Node-RED runtime files, environment variable coverage, credential-secret readiness, expected log paths, and reachable endpoints required for the Telegram operator phase. The script now prints an explicit READY/BLOCKED/DEGRADED operator summary so demo operators can tell whether they are safe to continue. Add `--strict` to fail on warnings as well.


## Import and Telegram node setup

1. Run `./scripts/preflight-telegram-operator.sh` and resolve hard failures first.
2. Install the Telegram contrib with `./scripts/install-node-red-telegram.sh` if it is not already present.
3. Import `node-red/flows/tnsn-telegram-control.json` with `./scripts/import-node-red-flow.sh node-red/flows/tnsn-telegram-control.json`.
4. In Node-RED, open the Telegram bot config node and set the real bot token/chat configuration.
5. Deploy the flow and verify `/start` in Telegram.

## Validation and demo checks

Run these before a demo:

- `node scripts/test-node-red-flow.js`
- `./scripts/test-telegram-operator-helpers.sh`
- `./scripts/preflight-telegram-operator.sh --strict`

Recommended demo checklist:

1. Confirm the preflight summary ends in `READY`. If it reports `DEGRADED`, call out the exact fallback behavior before the demo starts.
2. If the preflight warns about credential readiness, run `scripts/repair-node-red-credentials.sh --secret "$TNSN_NODE_RED_CREDENTIAL_SECRET"` and re-enter the Telegram bot token/chat settings in the Node-RED config node.
3. If the preflight warns that signal or audit logs are missing, expect `/signals`, `/audit`, and parts of `/status` or `/system` to show fallback/degraded output instead of historical data.
4. Verify `/start`, `/menu`, `/help`, `/status`, `/signals`, `/fetch`, `/audit`, and `/system`.
5. Verify inline button navigation works end-to-end without typing, especially Status, Signals, Fetch Signals, Audit, System Info, Help, and Home.
