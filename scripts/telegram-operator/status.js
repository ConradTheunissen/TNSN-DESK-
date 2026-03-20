#!/usr/bin/env node
const {
  env,
  readJsonl,
  detectTimestamp,
  getMemorySnapshot,
  httpJson,
  os,
  safeExec,
  fileExists,
  runJsonMain
} = require('./lib');

runJsonMain(async () => {
  const signalPath = env('TNSN_SIGNAL_HISTORY_PATH', '/opt/tnsn/logs/signal-history.jsonl');
  const nodeRedApi = env('TNSN_NODE_RED_API', 'http://127.0.0.1:1880');
  const signalHistoryExists = fileExists(signalPath);
  const latestSignal = signalHistoryExists ? (readJsonl(signalPath, 1).pop() || {}) : {};
  const memory = getMemorySnapshot();
  let nodeRed = { available: false, status: 0, statusText: 'unreachable' };

  try {
    const response = await httpJson(nodeRedApi, { timeoutMs: 4000 });
    nodeRed = {
      available: response.ok,
      status: response.status,
      statusText: response.statusText || (response.ok ? 'ok' : 'error')
    };
  } catch (error) {
    nodeRed = { available: false, status: 0, statusText: error.message };
  }

  return {
    ok: true,
    degraded: !signalHistoryExists,
    generatedAt: new Date().toISOString(),
    nodeRed,
    signalHistoryExists,
    lastSignalFetch: signalHistoryExists ? detectTimestamp(latestSignal) : 'unavailable',
    uptime: safeExec('uptime -p') || `${Math.round(os.uptime() / 60)} minutes`,
    memory,
    hostname: os.hostname(),
    platform: `${os.platform()} ${os.release()}`
  };
});
