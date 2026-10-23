#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

function fail(kind, detail, status = 2) {
  process.stdout.write(`${JSON.stringify({ schema_version: 1, ok: false, error: { kind, detail } })}\n`);
  process.exitCode = status;
}

const args = process.argv.slice(2);
const validArgs = args.length === 1 ||
  (args.length === 3 && args[1] === '--target' && ['js', 'native'].includes(args[2]));
if (!validArgs) {
  fail('usage', 'Usage: node scripts/analyze.mjs INPUT.json [--target js|native]');
} else {
  let source;
  try {
    source = readFileSync(resolve(args[0]), 'utf8').replace(/^\uFEFF/, '');
  } catch {
    fail('io', 'Cannot read input file.');
  }
  if (source !== undefined) {
    if (source.length > 16000) {
      fail('decode', 'Input exceeds 16000 UTF-16 code units.');
    } else {
      const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
      const target = args.length === 3 ? args[2] : 'js';
      const child = spawnSync('moon', ['run', '--quiet', '--target', target, 'cmd/report', '--', source], {
        cwd: repo,
        encoding: 'utf8',
        windowsHide: true,
        maxBuffer: 16 * 1024 * 1024,
      });
      if (child.error || child.status !== 0) {
        if (child.stderr) process.stderr.write(child.stderr);
        fail('runner', 'MoonBit execution failed; check the toolchain diagnostics on stderr.', 1);
      } else {
        try {
          const envelope = JSON.parse(child.stdout);
          if (envelope.schema_version !== 1 || typeof envelope.ok !== 'boolean') {
            throw new Error('Invalid result envelope');
          }
          process.stdout.write(`${JSON.stringify(envelope)}\n`);
          process.exitCode = envelope.ok ? 0 : 2;
        } catch {
          fail('runner', 'MoonBit did not return a valid analysis envelope.', 1);
        }
      }
    }
  }
}
