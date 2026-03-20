#!/usr/bin/env node
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

function env(name, fallback = '') {
  return process.env[name] || fallback;
}

function safeExec(command) {
  try {
    return execSync(command, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return '';
  }
}

function readJsonl(filePath, limit = 0) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const lines = raw.split(/\r?\n/).filter(Boolean);
    const sliced = limit > 0 ? lines.slice(-limit) : lines;
    return sliced.map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return { _raw: line, _invalid: true };
      }
    });
  } catch {
    return [];
  }
}

function detectTimestamp(entry = {}) {
  return entry.timestamp || entry.ts || entry.time || entry.created_at || entry.fetched_at || entry.date || entry.published || entry.publishedAt || 'n/a';
}

function detectSummary(entry = {}) {
  return entry.summary || entry.title || entry.headline || entry.description || entry.text || entry._raw || 'No summary available';
}

function detectSource(entry = {}) {
  return entry.source || entry.feed || entry.domain || entry.provider || entry.origin || 'unknown';
}

function detectLink(entry = {}) {
  return entry.link || entry.url || entry.source_url || entry.article_url || entry.href || '';
}

function detectSeverity(entry = {}) {
  if (typeof entry.severity === 'string' && entry.severity.trim()) {
    return entry.severity.trim().toLowerCase();
  }

  const score = Number(entry.score ?? entry.severity_score ?? entry.rank ?? entry.priority ?? NaN);
  if (!Number.isNaN(score)) {
    if (score >= 80) return 'high';
    if (score >= 50) return 'medium';
    return 'low';
  }

  if (typeof entry.classification === 'string' && entry.classification.trim()) {
    return entry.classification.trim().toLowerCase();
  }

  return 'unknown';
}

function statusEmoji(severity) {
  switch ((severity || '').toLowerCase()) {
    case 'high': return '🔴';
    case 'medium': return '🟠';
    case 'low': return '🟢';
    default: return '⚪';
  }
}

function bytesToMb(bytes) {
  return Math.round(bytes / 1024 / 1024);
}

function getMemorySnapshot() {
  const totalMb = bytesToMb(os.totalmem());
  const freeMb = bytesToMb(os.freemem());
  return {
    totalMb,
    freeMb,
    usedMb: Math.max(totalMb - freeMb, 0)
  };
}

async function httpJson(url, options = {}) {
  const controller = new AbortController();
  const timeoutMs = options.timeoutMs || 8000;
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: options.method || 'GET',
      headers: options.headers || {},
      body: options.body,
      signal: controller.signal
    });
    const text = await response.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    return {
      ok: response.ok,
      status: response.status,
      statusText: response.statusText,
      text,
      json
    };
  } finally {
    clearTimeout(timer);
  }
}

function printJson(data) {
  process.stdout.write(JSON.stringify(data));
}

module.exports = {
  env,
  safeExec,
  readJsonl,
  detectTimestamp,
  detectSummary,
  detectSource,
  detectLink,
  detectSeverity,
  statusEmoji,
  getMemorySnapshot,
  httpJson,
  printJson,
  os,
  path,
  fs
};
