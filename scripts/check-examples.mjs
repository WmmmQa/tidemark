import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const target = process.argv[2] ?? 'js';
assert.ok(['js', 'native'].includes(target), 'target must be js or native');

function runFile(name, status = 0) {
  const child = spawnSync(process.execPath, ['scripts/analyze.mjs', name, '--target', target], {
    cwd: root, encoding: 'utf8', windowsHide: true, maxBuffer: 16 * 1024 * 1024,
  });
  assert.equal(child.error, undefined);
  assert.equal(child.status, status, child.stderr || child.stdout);
  const envelope = JSON.parse(child.stdout);
  assert.equal(envelope.schema_version, 1);
  assert.equal(envelope.ok, status === 0);
  return envelope;
}

function checkPrecision(value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    if (key.endsWith('_fen') || ['units', 'weight', 'planned_bundles'].includes(key)) {
      assert.equal(typeof child, 'string', `${key} must preserve integer precision`);
      assert.match(child, /^(0|-?[1-9][0-9]*)$/);
    }
    checkPrecision(child);
  }
}

const plan = runFile('examples/operating-plan.json').result;
assert.equal(plan.kind, 'plan');
assert.equal(plan.periods[0].operating_profit_fen, '500000');
assert.equal(plan.periods[1].operating_profit_fen, '-100000');
assert.equal(plan.totals.revenue_fen, '9750000');
assert.equal(plan.totals.variable_cost_fen, '5950000');
assert.equal(plan.totals.fixed_cost_fen, '3400000');
assert.equal(plan.totals.operating_profit_fen, '400000');
assert.equal(plan.totals.target_gap_fen, '800000');
assert.deepEqual(plan.cumulative.at(-1).totals, plan.totals);
checkPrecision(plan);

const comparison = runFile('examples/budget-actual.json').result;
assert.equal(comparison.kind, 'comparison');
assert.deepEqual(comparison.actual.periods.map(row => row.id), ['2026-10', '2026-11']);
assert.equal(comparison.actual.cumulative[0].totals.operating_profit_fen, '366000');
assert.equal(comparison.budget.totals.operating_profit_fen, '1420000');
assert.equal(comparison.actual.totals.operating_profit_fen, '466000');
assert.equal(comparison.volume_effect_fen, '-116000');
assert.equal(comparison.price_effect_fen, '-304000');
assert.equal(comparison.variable_cost_effect_fen, '-284000');
assert.equal(comparison.fixed_cost_effect_fen, '-250000');
assert.equal(comparison.profit_delta_fen, '-954000');
const effects = ['volume_effect_fen', 'price_effect_fen', 'variable_cost_effect_fen', 'fixed_cost_effect_fen'];
for (const result of [comparison, ...comparison.periods]) {
  assert.equal(effects.reduce((sum, key) => sum + BigInt(result[key]), 0n), BigInt(result.profit_delta_fen));
}
for (const period of comparison.periods) {
  for (const product of period.products) {
    assert.equal(effects.slice(0, 3).reduce((sum, key) => sum + BigInt(product[key]), 0n), BigInt(product.profit_delta_fen));
  }
}
checkPrecision(comparison);

const mix = runFile('examples/product-mix.json').result;
assert.equal(mix.kind, 'mix');
assert.equal(mix.break_even.required.planned_bundles, '191');
assert.equal(mix.target.required.planned_bundles, '286');
assert.equal(mix.target.required.revenue_fen, '6006000');
assert.equal(mix.target.rounding_surplus_fen, '2400');
checkPrecision(mix);

const capacity = runFile('examples/capacity-plan.json').result;
assert.equal(capacity.kind, 'capacity');
assert.deepEqual(capacity.products.map(row => row.units), ['3', '3', '1']);
assert.equal(capacity.revenue_fen, '46000');
assert.equal(capacity.variable_cost_fen, '25900');
assert.equal(capacity.contribution_fen, '20100');
assert.equal(capacity.fixed_cost_fen, '3000');
assert.equal(capacity.operating_profit_fen, '17100');
assert.deepEqual(capacity.resources.map(row => [row.id, row.used, row.capacity]), [
  ['labor', '12', '12'],
  ['material', '10', '10'],
]);
assert.equal(Number(capacity.explored_nodes) > 0, true);
checkPrecision(capacity);

assert.equal(runFile('examples/invalid-units.json', 2).error.kind, 'analysis');
assert.equal(runFile('examples/invalid-schema.json', 2).error.kind, 'decode');
assert.equal(runFile('examples/missing-input-file.json', 2).error.kind, 'io');

for (const source of [undefined, '{', '--help']) {
  const arguments_ = ['run', '--quiet', '--target', target, 'cmd/report', '--'];
  if (source !== undefined) arguments_.push(source);
  const child = spawnSync('moon', arguments_, { cwd: root, encoding: 'utf8', windowsHide: true });
  assert.equal(child.error, undefined);
  assert.equal(child.status, 0, child.stderr);
  const envelope = JSON.parse(child.stdout);
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error.kind, source === undefined ? 'usage' : 'decode');
}

const capacityPlan = spawnSync(
  'moon',
  ['run', '--quiet', '--target', target, 'cmd/capacity'],
  { cwd: root, encoding: 'utf8', windowsHide: true },
);
assert.equal(capacityPlan.error, undefined);
assert.equal(capacityPlan.status, 0, capacityPlan.stderr);
assert.equal(
  capacityPlan.stdout.trimEnd(),
  [
    'Hypothetical product plan (money: fen)',
    'Optimal quantities (meal,drink,dessert): 3,3,1',
    'Revenue: 46000',
    'Variable cost: 25900',
    'Contribution: 20100',
    'Shared fixed cost: 3000',
    'Operating profit: 17100',
    'Resource use (labor,material): 12/12,10/10',
    'Search nodes: 34',
  ].join('\n'),
);

console.log('Structured examples and CLI checks passed (' + target + ').');
