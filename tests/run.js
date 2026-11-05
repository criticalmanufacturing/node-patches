'use strict';
// Runs the CVE regression tests in tests/cve against the node binary that runs
// this script. Each tests/cve/<CVE>.js module exports
//   { id, title, component, applies?, tests: [{ name, fn, control? }] }
// where fn throws (or returns a rejected promise) when the binary misbehaves, and
// applies() returns false on Node.js versions the CVE does not affect.
// Tests marked "control" check behaviour that must work with or without the fix.
//
// Usage:
//   node tests/run.js                        every CVE must be fixed (exit 1 otherwise)
//   node tests/run.js --expect vulnerable    every CVE must reproduce: use it on the
//                                            official binary to show what the tests catch
//   node tests/run.js --cve CVE-2026-111497  run one CVE only
//   node tests/run.js --list                 list the CVEs that have tests
// Plain CommonJS that runs on Node.js 10 and later.
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
function opt(name) { const i = args.indexOf(name); return i < 0 ? null : args[i + 1]; }
const expect = opt('--expect') || 'fixed';
if (expect !== 'fixed' && expect !== 'vulnerable') {
  console.error('--expect must be "fixed" or "vulnerable"');
  process.exit(2);
}
const only = opt('--cve');
const TIMEOUT_MS = 30000;

const dir = path.join(__dirname, 'cve');
const cves = fs.readdirSync(dir).filter((f) => /\.js$/.test(f)).sort()
  .map((f) => require(path.join(dir, f)))
  .filter((c) => !only || c.id === only);

if (args.indexOf('--list') >= 0) {
  cves.forEach((c) => console.log(c.id + '  ' + c.component + ': ' + c.title));
  process.exit(0);
}
if (!cves.length) { console.error('No CVE tests found' + (only ? ' for ' + only : '')); process.exit(2); }

function runOne(fn) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(new Error('timed out after ' + TIMEOUT_MS + ' ms')), TIMEOUT_MS);
    const done = (err) => { clearTimeout(timer); resolve(err || null); };
    try { Promise.resolve(fn()).then(() => done(), done); } catch (e) { done(e); }
  });
}

async function main() {
  const listed = String((process.config.variables || {}).cm_patches || '').split(',').filter(Boolean);
  console.log('node ' + process.version + ' ' + process.platform + '-' + process.arch +
    '  cm_patches: ' + (listed.join(',') || '(none)'));
  console.log('expecting every CVE to be ' + expect + '\n');

  let met = 0;
  for (const cve of cves) {
    console.log(cve.id + '  ' + cve.component + ': ' + cve.title);
    if (cve.applies && !cve.applies()) {
      console.log('  => NOT APPLICABLE to ' + process.version + '\n');
      met++;
      continue;
    }
    let failed = 0;
    let controlFailed = 0;
    for (const t of cve.tests) {
      const err = await runOne(t.fn);
      const tag = t.control ? ' (control)' : '';
      console.log('  ' + (err ? 'FAIL' : 'ok  ') + ' ' + t.name + tag);
      if (err) {
        console.log('       ' + String(err.message || err).split('\n')[0]);
        if (t.control) controlFailed++; else failed++;
      }
    }
    const status = controlFailed ? 'BROKEN' : failed ? 'VULNERABLE' : 'FIXED';
    const ok = !controlFailed && (expect === 'fixed' ? !failed : failed > 0);
    console.log('  => ' + status + (ok ? '' : '  (expected ' + expect.toUpperCase() + ')') + '\n');
    if (ok) met++;
  }
  console.log(met + ' of ' + cves.length + ' CVE(s) ' + expect + ' as expected');
  process.exitCode = met === cves.length ? 0 : 1;
}

main();
