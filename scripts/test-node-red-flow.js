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

function asSet(values) {
  return new Set(values.filter((value) => value !== undefined));
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
assert(tabIds.size >= 1, 'expected at least one tab node');

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
  n_build_menu: 'function',
  n_build_help: 'function',
  n_build_status: 'function',
  n_read_signals: 'exec',
  n_format_signals: 'function',
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
const commandValues = asSet(commandRules.map((rule) => rule.v));
for (const command of ['/start', '/menu', '/help', '/status', '/signals']) {
  assert(commandValues.has(command), `command router missing route for ${command}`);
}
assert(commandRules.some((rule) => rule.t === 'else'), 'command router must include an else route');
assert(commandRouter.outputs === 6, 'command router must expose 6 outputs');

const callbackRouter = nodesById.get('n_callback_router');
const callbackRules = callbackRouter.rules || [];
const callbackValues = asSet(callbackRules.map((rule) => rule.v));
for (const action of ['ui:menu', 'ui:help', 'ui:status', 'ui:signals']) {
  assert(callbackValues.has(action), `callback router missing action for ${action}`);
}
assert(callbackRules.some((rule) => rule.t === 'else'), 'callback router must include an else route');
assert(callbackRouter.outputs === 5, 'callback router must expose 5 outputs');

const menuBuilder = nodesById.get('n_build_menu');
assert(menuBuilder.func.includes('inline_keyboard'), 'main menu builder must create an inline keyboard');
assert(menuBuilder.func.includes('ui:status'), 'main menu builder must expose a status button');
assert(menuBuilder.func.includes('ui:signals'), 'main menu builder must expose a signals button');

const helpBuilder = nodesById.get('n_build_help');
assert(helpBuilder.func.includes('/menu - open the inline control surface'), 'help builder must describe /menu');

const statusBuilder = nodesById.get('n_build_status');
assert(statusBuilder.func.includes('signal_history'), 'status builder must expose the signal history path');
assert(statusBuilder.func.includes('audit_log'), 'status builder must expose the audit log path');

const signalExec = nodesById.get('n_read_signals');
assert(signalExec.command.includes('tail -n 5'), 'signal reader must tail the latest signals');
assert(signalExec.command.includes('TNSN_SIGNAL_HISTORY_PATH'), 'signal reader must use the signal history env var');

const signalFormatter = nodesById.get('n_format_signals');
assert(signalFormatter.func.includes('Recent signals:'), 'signals formatter must label recent signals');
assert(signalFormatter.func.includes('ui:signals'), 'signals formatter must include a refresh action');

const alertBuilder = nodesById.get('n_build_alert');
assert(alertBuilder.func.includes('🚨 TNSN Signal Alert'), 'alert builder must label Telegram alerts');
assert(alertBuilder.func.includes('ui:menu'), 'alert builder must include a menu action');

const sender = nodesById.get('n_telegram_sender');
assert(Array.isArray(sender.wires), 'telegram sender must expose wires array');

console.log(`PASS: validated ${flow.length} flow nodes in ${flowPath}`);
