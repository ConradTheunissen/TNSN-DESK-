#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_RED_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
NODE_RED_API="${TNSN_NODE_RED_API:-http://127.0.0.1:1880}"
SIGNAL_PATH="${TNSN_SIGNAL_HISTORY_PATH:-/opt/tnsn/logs/signal-history.jsonl}"
AUDIT_PATH="${TNSN_AUDIT_LOG_PATH:-/opt/tnsn/logs/audit.jsonl}"
FETCH_URL="${TNSN_SIGNAL_FETCH_URL:-${TNSN_C2_URL:-http://127.0.0.1:1880/api/c2}}"
STRICT=0
FAILURES=0
WARNINGS=0

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

pass() {
  printf 'PASS  %s\n' "$1"
}

warn() {
  printf 'WARN  %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

note() {
  printf 'NOTE  %s\n' "$1"
}

section() {
  printf '\n[%s]\n' "$1"
}

check_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label: $path"
  else
    fail "$label missing: $path"
  fi
}

check_dir() {
  local path="$1"
  local label="$2"
  if [[ -d "$path" ]]; then
    pass "$label: $path"
  else
    fail "$label missing: $path"
  fi
}

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$label: $(command -v "$cmd")"
  else
    fail "$label missing from PATH: $cmd"
  fi
}

check_runtime_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label: $path"
  else
    warn "$label missing: $path"
  fi
}

check_url() {
  local url="$1"
  local label="$2"
  if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 3 -o /dev/null "$url"; then
    pass "$label reachable: $url"
  else
    warn "$label not reachable: $url"
  fi
}

check_env_value() {
  local name="$1"
  local description="$2"
  local requirement="${3:-optional}"
  local value="${!name:-}"

  if [[ -n "$value" ]]; then
    pass "$name set for $description"
    return
  fi

  if [[ "$requirement" == "required" ]]; then
    fail "$name missing: $description"
  else
    warn "$name not set: $description"
  fi
}

check_secret_readiness() {
  local active_secret="${TNSN_NODE_RED_CREDENTIAL_SECRET:-}"
  local settings_file="$NODE_RED_DIR/settings.js"

  if [[ -n "$active_secret" && "$active_secret" != 'change-me-before-production' ]]; then
    pass 'TNSN_NODE_RED_CREDENTIAL_SECRET is set to a non-placeholder value'
  elif [[ -n "$active_secret" ]]; then
    warn 'TNSN_NODE_RED_CREDENTIAL_SECRET is still using the placeholder value'
  else
    warn 'TNSN_NODE_RED_CREDENTIAL_SECRET is not exported in this shell'
  fi

  if [[ -f "$settings_file" ]]; then
    if rg -n "credentialSecret\s*:" "$settings_file" >/dev/null 2>&1; then
      pass "Node-RED settings.js declares credentialSecret: $settings_file"
    else
      warn "Node-RED settings.js does not declare credentialSecret: $settings_file"
    fi
  else
    warn "Node-RED settings.js unavailable for credentialSecret verification: $settings_file"
  fi

  if [[ -f "$NODE_RED_DIR/flows_cred.json" ]]; then
    if [[ -z "$active_secret" ]]; then
      warn 'Credential store exists but no active TNSN_NODE_RED_CREDENTIAL_SECRET is exported; decrypt failures are likely after restart'
    fi
    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));" "$NODE_RED_DIR/flows_cred.json" >/dev/null 2>&1; then
      pass "Node-RED credential store is valid JSON: $NODE_RED_DIR/flows_cred.json"
    else
      warn "Node-RED credential store is not valid JSON; run scripts/repair-node-red-credentials.sh: $NODE_RED_DIR/flows_cred.json"
    fi
  fi
}

print_demo_guidance() {
  printf '\n[Operator guidance]\n'
  if [[ "$FAILURES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
    printf 'READY  Local checks passed cleanly. Proceed with import/deploy and live Telegram validation.\n'
    return
  fi

  if [[ "$FAILURES" -gt 0 ]]; then
    printf 'BLOCKED  Resolve FAIL items before the demo. The control surface is not ready for operator use.\n'
  else
    printf 'DEGRADED  Demo can start, but expect reduced behavior until WARN items are resolved.\n'
  fi

  if [[ ! -f "$SIGNAL_PATH" ]]; then
    printf 'DEGRADED  Missing signal history means /signals and status history fields will return fallback output.\n'
  fi
  if [[ ! -f "$AUDIT_PATH" ]]; then
    printf 'DEGRADED  Missing audit log means /audit and system log checks will return fallback output.\n'
  fi
  if ! command -v node-red >/dev/null 2>&1; then
    printf 'DEGRADED  Node-RED is not on PATH, so import/deploy tasks cannot be completed from this machine yet.\n'
  fi
  if [[ ! -d "$NODE_RED_DIR/node_modules/node-red-contrib-telegrambot" ]]; then
    printf 'DEGRADED  Telegram bot nodes are not installed; run scripts/install-node-red-telegram.sh before demo time.\n'
  fi
  if [[ -z "${TNSN_NODE_RED_CREDENTIAL_SECRET:-}" || "${TNSN_NODE_RED_CREDENTIAL_SECRET:-}" == 'change-me-before-production' ]]; then
    printf 'DEGRADED  Credential secret is unset or placeholder; Telegram credentials may fail after restart until fixed.\n'
  fi
  printf 'NEXT  Use scripts/repair-node-red-credentials.sh if Node-RED reports credential decode errors, then re-enter the Telegram bot token in the config node if needed.\n'
}

printf 'Telegram Operator Preflight\n'
printf 'repo_root=%s\n' "$REPO_ROOT"
printf 'node_red_dir=%s\n' "$NODE_RED_DIR"
printf 'node_red_api=%s\n' "$NODE_RED_API"
printf 'signal_path=%s\n' "$SIGNAL_PATH"
printf 'audit_path=%s\n' "$AUDIT_PATH"
printf 'fetch_url=%s\n' "$FETCH_URL"
printf 'strict_mode=%s\n' "$STRICT"

section 'Repo scaffold'
check_dir "$REPO_ROOT/node-red/flows" 'Node-RED flow directory'
check_dir "$REPO_ROOT/scripts/telegram-operator" 'Telegram helper script directory'
check_file "$REPO_ROOT/node-red/flows/tnsn-telegram-control.json" 'Operator flow export'
check_file "$REPO_ROOT/node-red/config/env.example" 'Operator env example'
check_file "$REPO_ROOT/scripts/test-node-red-flow.js" 'Flow validator'
check_file "$REPO_ROOT/scripts/install-node-red-telegram.sh" 'Telegram install helper'
check_file "$REPO_ROOT/scripts/import-node-red-flow.sh" 'Flow import helper'
check_file "$REPO_ROOT/scripts/repair-node-red-credentials.sh" 'Credential repair helper'
check_file "$REPO_ROOT/scripts/telegram-operator/lib.js" 'Shared helper library'
check_file "$REPO_ROOT/scripts/telegram-operator/status.js" 'Status helper'
check_file "$REPO_ROOT/scripts/telegram-operator/signals.js" 'Signals helper'
check_file "$REPO_ROOT/scripts/telegram-operator/audit.js" 'Audit helper'
check_file "$REPO_ROOT/scripts/telegram-operator/system.js" 'System helper'
check_file "$REPO_ROOT/scripts/telegram-operator/fetch.js" 'Fetch helper'

section 'Local runtime'
check_cmd node 'Node.js runtime'
check_cmd npm 'npm runtime'
if command -v node-red >/dev/null 2>&1; then
  pass "Node-RED runtime: $(command -v node-red)"
else
  warn 'Node-RED runtime missing from PATH: node-red'
fi

check_runtime_file "$NODE_RED_DIR/settings.js" 'Node-RED settings.js'
check_runtime_file "$NODE_RED_DIR/package.json" 'Node-RED package.json'
check_runtime_file "$NODE_RED_DIR/flows_cred.json" 'Node-RED credential store'
if [[ -d "$NODE_RED_DIR/node_modules/node-red-contrib-telegrambot" ]]; then
  pass "Telegram contrib installed: $NODE_RED_DIR/node_modules/node-red-contrib-telegrambot"
else
  warn "Telegram contrib missing: $NODE_RED_DIR/node_modules/node-red-contrib-telegrambot"
fi

section 'Environment and credentials'
check_env_value TNSN_REPO_ROOT 'Node-RED exec helpers should point at this repo root'
check_env_value TNSN_SIGNAL_HISTORY_PATH 'status/signals helpers should read the expected signal history path'
check_env_value TNSN_AUDIT_LOG_PATH 'audit/system helpers should read the expected audit path'
check_env_value TNSN_NODE_RED_API 'import and status checks should target the active Node-RED admin URL'
check_env_value TNSN_SIGNAL_FETCH_URL 'manual fetch action should target the active fetch endpoint'
check_env_value TNSN_ALLOWED_COMMANDS 'Telegram command allow-list should match the operator surface'
check_secret_readiness
note 'Telegram bot token/chat credentials still need a final in-Node-RED verification before a live demo'

section 'Local data and endpoints'
if [[ -f "$SIGNAL_PATH" ]]; then
  pass "Signal log present: $SIGNAL_PATH"
else
  warn "Signal log missing: $SIGNAL_PATH"
fi
if [[ -f "$AUDIT_PATH" ]]; then
  pass "Audit log present: $AUDIT_PATH"
else
  warn "Audit log missing: $AUDIT_PATH"
fi

check_url "$NODE_RED_API" 'Node-RED API'
check_url "$FETCH_URL" 'Signal fetch endpoint'

printf '\nSummary: %s failure(s), %s warning(s)\n' "$FAILURES" "$WARNINGS"
print_demo_guidance

if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
if [[ "$STRICT" -eq 1 && "$WARNINGS" -gt 0 ]]; then
  exit 2
fi
