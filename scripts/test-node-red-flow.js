#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const flowPath = process.argv[2] || path.join('node-red', 'flows', 'tnsn-telegram-control.json');

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function collectEnvReferences(node) {
  const values = [];
  for (const value of Object.values(node)) {
    if (typeof value === 'string') values.push(value);
  }
  return values.join('\n');
}

const raw = fs.readFileSync(flowPath, 'utf8');
let flow;
try {
  flow = JSON.parse(raw);
} catch (error) {
  fail(`flow is not valid JSON: ${error.message}`);
}

assert(Array.isArray(flow), 'flow export must be a JSON array');
assert(flow.length > 0, 'flow export must not be empty');

const ids = new Set();
const nodesById = new Map();
for (const node of flow) {
  assert(node && typeof node === 'object', 'every flow entry must be an object');
  assert(typeof node.id === 'string' && node.id.length > 0, 'every node must have a non-empty string id');
  assert(!ids.has(node.id), `duplicate node id detected: ${node.id}`);
  ids.add(node.id);
  nodesById.set(node.id, node);
}

const tabIds = new Set(flow.filter((node) => node.type === 'tab').map((node) => node.id));
assert(tabIds.size === 1, 'expected exactly one tab node');

for (const node of flow) {
  if (node.type !== 'tab' && node.type !== 'telegram bot') {
    assert(typeof node.z === 'string' && tabIds.has(node.z), `node ${node.id} must belong to a valid tab`);
  }

  if (Array.isArray(node.wires)) {
    for (const output of node.wires) {
      assert(Array.isArray(output), `node ${node.id} has a non-array wires output`);
      for (const targetId of output) {
        assert(ids.has(targetId), `node ${node.id} wires to missing node ${targetId}`);
      }
    }
  }
}

const telegramBotConfigs = flow.filter((node) => node.type === 'telegram bot');
assert(telegramBotConfigs.length === 1, 'expected exactly one telegram bot config node');

const requiredNodes = {
  n_telegram_receiver: 'telegram receiver',
  n_telegram_callback: 'telegram event',
  n_cmd_router: 'switch',
  n_callback_router: 'switch',
  n_overview_exec: 'exec',
  n_format_overview: 'function',
  n_status_exec: 'exec',
  n_format_status: 'function',
  n_signals_exec: 'exec',
  n_format_signals: 'function',
  n_fetch_exec: 'exec',
  n_format_fetch: 'function',
  n_audit_exec: 'exec',
  n_format_audit: 'function',
  n_system_exec: 'exec',
  n_format_system: 'function',
  n_build_help: 'function',
  n_signal_alert_in: 'link in',
  n_build_alert: 'function',
  n_telegram_sender: 'telegram sender'
};

for (const [id, expectedType] of Object.entries(requiredNodes)) {
  const node = nodesById.get(id);
  assert(node, `missing required node ${id}`);
  assert(node.type === expectedType, `node ${id} should be type ${expectedType}, got ${node.type}`);
}

const commandRouter = nodesById.get('n_cmd_router');
const commandRules = commandRouter.rules || [];
const commandValues = new Set(commandRules.map((rule) => rule.v).filter(Boolean));
for (const command of ['/start', '/menu', '/help', '/status', '/signals', '/fetch', '/audit', '/system']) {
  assert(commandValues.has(command), `command router missing route for ${command}`);
}
assert(commandRules.some((rule) => rule.t === 'else'), 'command router must include an else route');
assert(commandRouter.outputs === 9, 'command router must expose 9 outputs');

const callbackRouter = nodesById.get('n_callback_router');
const callbackRules = callbackRouter.rules || [];
const callbackValues = new Set(callbackRules.map((rule) => rule.v).filter(Boolean));
for (const action of ['ui:menu', 'ui:status', 'ui:signals', 'ui:fetch', 'ui:audit', 'ui:system', 'ui:help']) {
  assert(callbackValues.has(action), `callback router missing action for ${action}`);
}
assert(callbackRules.some((rule) => rule.t === 'else'), 'callback router must include an else route');
assert(callbackRouter.outputs === 8, 'callback router must expose 8 outputs');

for (const formatterId of ['n_format_overview', 'n_format_status', 'n_format_signals', 'n_format_fetch', 'n_format_audit', 'n_format_system', 'n_build_help', 'n_unknown_help', 'n_build_alert']) {
  const node = nodesById.get(formatterId);
  assert(node.func.includes("callback_data: 'ui:status'"), `${formatterId} must include a Status button`);
  assert(node.func.includes("callback_data: 'ui:signals'"), `${formatterId} must include a Signals button`);
  assert(node.func.includes("callback_data: 'ui:fetch'"), `${formatterId} must include a Fetch Signals button`);
  assert(node.func.includes("callback_data: 'ui:audit'"), `${formatterId} must include an Audit button`);
  assert(node.func.includes("callback_data: 'ui:system'"), `${formatterId} must include a System Info button`);
  assert(node.func.includes("callback_data: 'ui:help'"), `${formatterId} must include a Help button`);
  assert(node.func.includes("callback_data: 'ui:menu'"), `${formatterId} must include a Home button`);
}

const execTargets = {
  n_overview_exec: 'status.js',
  n_status_exec: 'status.js',
  n_signals_exec: 'signals.js',
  n_fetch_exec: 'fetch.js',
  n_audit_exec: 'audit.js',
  n_system_exec: 'system.js'
};
for (const [id, scriptName] of Object.entries(execTargets)) {
  const node = nodesById.get(id);
  assert(node.command.includes('${TNSN_REPO_ROOT'), `${id} must use TNSN_REPO_ROOT`);
  assert(node.command.includes(scriptName), `${id} must execute ${scriptName}`);
}

const signalsFormatter = nodesById.get('n_format_signals');
assert(signalsFormatter.func.includes('Signals'), 'signals formatter must title the response');
assert(signalsFormatter.func.includes('severityIcon'), 'signals formatter must render severity visually');

const fetchFormatter = nodesById.get('n_format_fetch');
assert(fetchFormatter.func.includes('result:'), 'fetch formatter must report success/failure');
assert(fetchFormatter.func.includes('count:'), 'fetch formatter must report a count');

const auditFormatter = nodesById.get('n_format_audit');
assert(auditFormatter.func.includes('Audit History'), 'audit formatter must title the response');

const statusFormatter = nodesById.get('n_format_status');
assert(statusFormatter.func.includes('last signal fetch'), 'status formatter must show the last signal fetch');
assert(statusFormatter.func.includes('memory:'), 'status formatter must show memory');

const helperScripts = [
  'scripts/telegram-operator/status.js',
  'scripts/telegram-operator/system.js',
  'scripts/telegram-operator/signals.js',
  'scripts/telegram-operator/audit.js',
  'scripts/telegram-operator/fetch.js'
].map((file) => fs.readFileSync(file, 'utf8')).join('\n');
const envReferences = flow.map(collectEnvReferences).join('\n') + '\n' + helperScripts;
for (const envName of ['TNSN_REPO_ROOT', 'TNSN_SIGNAL_HISTORY_PATH', 'TNSN_AUDIT_LOG_PATH', 'TNSN_C2_URL', 'TNSN_SIGNAL_FETCH_URL', 'TNSN_NODE_RED_API']) {
  assert(envReferences.includes(envName), `operator UI must reference ${envName}`);
}

console.log(`PASS: validated ${flow.length} flow nodes in ${flowPath}`);
