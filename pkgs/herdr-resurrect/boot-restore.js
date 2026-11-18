#!/usr/bin/env node
'use strict';
// Startup hook: once per server boot, when autoRestore is on, relaunch what the last
// snapshot's panes ran, after the first client attaches and herdr resumes its agents.
const fs = require('fs');
const path = require('path');
const settings = require('../lib/settings').load();
const boot = require('../lib/boot');
const herdr = require('../lib/herdr');
const notify = require('../lib/notify');
const { loadModel, restore } = require('../lib/restore');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// herdr staggers resumes (startup_per_agent_delay_ms); a reference it can't resume never gets an agent.
const RESUME_TIMEOUT_MS = 20000;
const POLL_MS = 500;
// Events autosave once the restore is done: the relaunched programs need this long to replace their shells.
const RELAUNCH_SETTLE_MS = 5000;

// herdr has no attach event, and resumes agents only once a client attaches; its
// server log records that client after this boot's start line.
function attachWatcher() {
  const log = path.join(path.dirname(boot.socketPath()), 'herdr-server.log');
  let offset = 0;
  try {
    const text = fs.readFileSync(log, 'utf8');
    offset = Buffer.byteLength(text.slice(0, Math.max(0, text.lastIndexOf('herdr server started'))));
  } catch { /* no log yet: read it from the start */ }
  return () => {
    try {
      const fd = fs.openSync(log, 'r');
      try {
        const size = fs.fstatSync(fd).size;
        if (size < offset) offset = 0;
        const buf = Buffer.alloc(size - offset);
        fs.readSync(fd, buf, 0, buf.length, offset);
        return buf.toString('utf8').includes('client connected');
      } finally { fs.closeSync(fd); }
    } catch { return false; }
  };
}

// A pane herdr will resume keeps its agent and session reference from the saved
// layout, so it reads as resumed only once its shell runs something; herdr unreachable counts as still resuming.
function resuming() {
  try {
    return herdr.paneList().some((p) => {
      if (!p.agent_session) return false;
      const info = herdr.processInfo(p.pane_id);
      return !info || !(info.foreground_processes || []).some((f) => f.pid !== info.shell_pid);
    });
  } catch { return true; }
}

async function main() {
  if (!settings.autoRestore) return;
  const token = boot.token();
  // Claimed before any event, so on-event.js (which then waits for `done`) can't
  // autosave the post-boot bare shells over the snapshot this restores from.
  if (!token || boot.claim(token) !== 'claimed') return;
  const live = () => boot.token() === token;
  try {
    let model;
    try { model = loadModel(); } catch { return; }
    const attached = attachWatcher();
    while (!attached()) {
      if (!live()) return;
      await sleep(POLL_MS);
    }
    const deadline = Date.now() + RESUME_TIMEOUT_MS;
    while (resuming() && Date.now() < deadline) await sleep(POLL_MS);
    await sleep(settings.autoRestoreSettleMs);
    if (!live()) return;
    const res = restore(model, { mode: 'rehydrate', log: (l) => console.log('[boot-restore] ' + l) });
    console.log(`herdr-resurrect: boot restore ran ${res.actions.length} action(s)`);
    notify.restored(res, { auto: true });
    await sleep(RELAUNCH_SETTLE_MS);
  } catch (e) {
    console.error('herdr-resurrect boot restore failed:', e.message);
    notify.restoreFailed(e, { auto: true });
  } finally {
    if (live()) boot.markDone(token);
  }
}

main();
