import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cp, mkdtemp, mkdir, readFile, readdir, realpath, rm, writeFile } from 'node:fs/promises';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const targets = process.argv.slice(2);
if (targets.length === 0) targets.push('js');
assert.ok(targets.every(target => ['native', 'js'].includes(target)), 'targets must be native and/or js');
assert.equal(new Set(targets).size, targets.length, 'targets must be unique');

const guide = await readFile(resolve(root, 'fieldbook/using-as-a-library.md'), 'utf8');

function documentedBlockAfter(label) {
  const marker = guide.indexOf(label);
  assert.notEqual(marker, -1, `missing library guide section: ${label}`);
  const match = guide.slice(marker + label.length).match(/\r?\n```[^\r\n]*\r?\n([\s\S]*?)\r?\n```/);
  assert.ok(match, `missing code block after: ${label}`);
  return `${match[1].replaceAll('\r\n', '\n')}\n`;
}

const workspaceManifest = documentedBlockAfter('Create `moon.work` in the workspace directory:');
const consumerModule = documentedBlockAfter('Create `consumer/moon.mod`:');
const consumerPackage = documentedBlockAfter('Create `consumer/moon.pkg`:');
const consumerSource = documentedBlockAfter('Create `consumer/main.mbt`:');
const expectedOutput = documentedBlockAfter('Expected stdout:').trimEnd();
for (const packageName of ['domain', 'engine', 'portfolio', 'planning', 'interchange', 'optimizer']) {
  assert.ok(consumerPackage.includes(`"WmmmQa/tidemark/${packageName}"`), `consumer must import ${packageName}`);
}

function runMoon(args, cwd) {
  const command = process.platform === 'win32' ? 'moon.exe' : 'moon';
  const child = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    windowsHide: true,
    timeout: 180_000,
    maxBuffer: 8 * 1024 * 1024,
  });
  assert.equal(child.error, undefined, `${command} ${args.join(' ')}: ${child.error ?? ''}`);
  assert.equal(child.status, 0, `${command} ${args.join(' ')} failed\n${child.stdout}\n${child.stderr}`);
  return child.stdout.trimEnd();
}

function isChildPath(parent, candidate) {
  const path = relative(parent, candidate);
  return path !== '' && path !== '..' && !path.startsWith(`..${sep}`) && !isAbsolute(path);
}

let workspace;
try {
  const temporaryRoot = await realpath(tmpdir());
  workspace = await mkdtemp(join(temporaryRoot, 'tidemark-library-consumer-'));
  const safeWorkspace = await realpath(workspace);
  assert.ok(
    isChildPath(temporaryRoot, safeWorkspace) && basename(safeWorkspace).startsWith('tidemark-library-consumer-'),
    'temporary workspace escaped its dedicated OS temp directory',
  );

  const moduleRoot = join(workspace, 'tidemark');
  const consumerRoot = join(workspace, 'consumer');
  await mkdir(moduleRoot, { recursive: true });
  await mkdir(consumerRoot, { recursive: true });
  await cp(resolve(root, 'moon.mod'), join(moduleRoot, 'moon.mod'));
  await cp(resolve(root, 'moon.pkg'), join(moduleRoot, 'moon.pkg'));

  for (const packageName of ['domain', 'engine', 'portfolio', 'planning', 'interchange', 'optimizer']) {
    const sourcePackage = resolve(root, packageName);
    const targetPackage = join(moduleRoot, packageName);
    await mkdir(targetPackage);
    for (const entry of await readdir(sourcePackage, { withFileTypes: true })) {
      if (!entry.isFile()) continue;
      const isPackageManifest = entry.name === 'moon.pkg';
      const isGeneratedInterface = entry.name === 'pkg.generated.mbti';
      const isProductionSource = entry.name.endsWith('.mbt') && !/(?:_test|_wbtest)\.mbt$/.test(entry.name);
      if (isPackageManifest) {
        const manifest = await readFile(join(sourcePackage, entry.name), 'utf8');
        // The isolated copy omits *_test.mbt files, so drop their test-only imports too.
        const productionManifest = manifest
          .replace(/\r?\nimport\s*\{[\s\S]*?\}\s*for\s*"test"\s*/g, '\n')
          .trimEnd();
        await writeFile(join(targetPackage, entry.name), `${productionManifest}\n`, 'utf8');
      } else if (isGeneratedInterface || isProductionSource) {
        await cp(join(sourcePackage, entry.name), join(targetPackage, entry.name));
      }
    }
  }

  await writeFile(join(workspace, 'moon.work'), workspaceManifest, 'utf8');
  await writeFile(join(consumerRoot, 'moon.mod'), consumerModule, 'utf8');
  await writeFile(join(consumerRoot, 'moon.pkg'), consumerPackage, 'utf8');
  await writeFile(join(consumerRoot, 'main.mbt'), consumerSource, 'utf8');

  runMoon(['check', '--target', 'native', '--deny-warn'], consumerRoot);
  for (const target of targets) {
    const output = runMoon(['run', '--target', target, '.'], consumerRoot);
    assert.equal(output, expectedOutput, `external consumer output differs for ${target}`);
  }
} finally {
  if (workspace) {
    const temporaryRoot = await realpath(tmpdir());
    const safeWorkspace = await realpath(workspace);
    assert.ok(
      isChildPath(temporaryRoot, safeWorkspace) && basename(safeWorkspace).startsWith('tidemark-library-consumer-'),
      'refusing to remove a path outside the dedicated OS temp directory',
    );
    await rm(safeWorkspace, { recursive: true, force: true });
  }
}

console.log(`Separate MoonBit consumer passed for: ${targets.join(', ')}.`);
