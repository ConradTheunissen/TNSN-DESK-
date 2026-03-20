#!/usr/bin/env node
const {
  env,
  fs,
  getMemorySnapshot,
  printJson,
  os,
  safeExec
} = require('./lib');

const signalPath = env('TNSN_SIGNAL_HISTORY_PATH', '/opt/tnsn/logs/signal-history.jsonl');
const auditPath = env('TNSN_AUDIT_LOG_PATH', '/opt/tnsn/logs/audit.jsonl');
const memory = getMemorySnapshot();

printJson({
  ok: true,
  generatedAt: new Date().toISOString(),
  hostname: os.hostname(),
  platform: `${os.platform()} ${os.release()}`,
  arch: os.arch(),
  nodeVersion: process.version,
  user: safeExec('whoami') || env('USER', 'unknown'),
  currentTime: safeExec('date -Iseconds') || new Date().toISOString(),
  uptime: safeExec('uptime -p') || `${Math.round(os.uptime() / 60)} minutes`,
  loadAverage: os.loadavg(),
  memory,
  signalHistoryExists: fs.existsSync(signalPath),
  auditLogExists: fs.existsSync(auditPath),
  signalHistoryPath: signalPath,
  auditLogPath: auditPath
});
