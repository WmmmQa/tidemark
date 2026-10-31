# JSON interface — schema version 1

`interchange` converts structured requests to pure fixed-mix, capacity-planning, discrete resource-sensitivity and multi-period APIs. `cmd/report` accepts exactly one JSON string argument and prints one JSON response. Capacity requests call the exact optimizer through `portfolio`; the sensitivity request calls `portfolio.capacity_resource_sensitivity`. The Node wrapper only reads the user file and transports its text; decoding, optimization and finance calculations run in MoonBit:

```sh
node scripts/analyze.mjs examples/operating-plan.json
node scripts/analyze.mjs examples/budget-actual.json --target js
node scripts/analyze.mjs examples/product-mix.json --target native
node scripts/analyze.mjs examples/capacity-plan.json
node scripts/analyze.mjs examples/resource-value.json
```

Copy an example and edit it. Run from the repository root. The default target is JS; native requires a C toolchain. Node 22 is used in CI. No dependencies need to be installed with npm.

## Input fields

Every object rejects unknown fields and requires all fields shown below. `schema_version` is the JSON number `1`. Amounts, quantities and weights are **canonical decimal strings**, never JSON numbers. Examples: `"0"`, `"8000"`, `"1000000000"`. Leading/trailing whitespace, `+1`, `01`, `-0`, fractions and exponent notation are rejected. Parsing first checks signed Int64 representation, then the analysis API checks its domain bounds.

Send `schema_version` as the integer literal `1`. Version dispatch compares the standard JSON parser's binary64 numeric value: a near-one decimal such as `1.0000000000000001` rounds to `1` and is accepted by the current parser, while `1.0000000000000002` remains a different value and is rejected. The decoder does not validate the original version-number spelling. Financial amounts, quantities and weights use the separate exact string parser described above; these remain exact decimal strings even when their values exceed JavaScript's safe-integer range.

| Object | Required fields |
| --- | --- |
| Plan request | `schema_version`, `kind: "plan"`, `periods: Period[]` |
| Comparison request | `schema_version`, `kind: "comparison"`, `budget: Period[]`, `actual: Period[]` |
| Mix request | `schema_version`, `kind: "mix"`, `items: MixItem[]`, `fixed_cost_fen`, `planned_bundles`, `target_profit_fen` |
| Capacity request | `schema_version`, `kind: "capacity"`, `resources: Resource[]`, `items: CapacityItem[]`, `fixed_cost_fen`, `max_nodes` |
| Capacity sensitivity request | `schema_version`, `kind: "capacity_sensitivity"`, same capacity fields, `resource_id`, `max_nodes` |
| Period | `id`, `products: SalesLine[]`, `fixed_cost_fen`, `target_profit_fen` |
| SalesLine | `product: Product`, `units` |
| Product | `id`, `selling_price_fen`, `variable_cost_fen` |
| MixItem | `product: Product`, `weight` |
| Resource | `id`, `capacity` |
| CapacityItem | `product`, `max_units`, `resource_uses: ResourceUse[]` |
| ResourceUse | `resource_id`, `units_per_decision` |

A minimal operating-plan request:

```json
{
  "schema_version": 1,
  "kind": "plan",
  "periods": [{
    "id": "2026-10",
    "products": [{
      "product": { "id": "meal", "selling_price_fen": "8000", "variable_cost_fen": "4800" },
      "units": "500"
    }],
    "fixed_cost_fen": "1600000",
    "target_profit_fen": "800000"
  }]
}
```

Amounts are fen in one common currency and cost basis; quantities are whole units of the identified product. For operating plans, every amount, target and product quantity is 0–1,000,000,000. A mix additionally requires positive selling prices, positive raw weights at most 1,000,000,000, and positive combined contribution. Planned mix volume is 0–1,000,000,000 **normalized bundles**. See the README for GCD normalization and whole-bundle target assumptions.

For capacity plans, price must be positive; variable cost, fixed cost, resource capacity/use, and product maximum quantity are 0–1,000,000,000. `max_nodes` is a positive decimal string up to 250,000. Each item's `resource_uses` must contain exactly one nonnegative row per declared resource; resource and product IDs must be unique. The optimizer maximizes total product contribution subject to all resource capacities and product upper bounds, then subtracts shared fixed cost once. A product with nonpositive contribution is selected at zero because minimum quantities are not modeled. Search exhaustion is an analysis error; no unproven incumbent is returned. See [`examples/capacity-plan.json`](../examples/capacity-plan.json) for the editable three-product scenario.

A capacity-sensitivity request uses the same model plus the exact `resource_id` to increase by one. The resource must exist exactly once and its base capacity must be below 1,000,000,000. MoonBit solves the original and increased-capacity plans independently, each with the requested `max_nodes`; the total node budget is therefore `2 * max_nodes` and actual explored nodes are returned. Both searches must prove optimality. The result reports each plan, contribution/profit differences and per-product quantity changes. The delta is before any cost to obtain the extra resource; compare it with that cost before acting. It is a discrete one-unit difference for the supplied plan, not a continuous shadow price or causal forecast. [`examples/resource-value.json`](../examples/resource-value.json) contains the complete editable scenario: increasing labor from 12 to 13 changes the solution from 3/3/1 to 2/3/2 and raises profit by 1,300 fen.

IDs are nonblank, already trimmed and case-sensitive. A period has at least one product; plans and mixes are nonempty. Period IDs are unique within a plan and product IDs within a period/mix. The caller defines period chronology through array order. Comparison uses budget chronology and matches exact ID sets on both sides; it does not match rows by position or infer missing data. Product sets may change between periods. To represent a newly introduced/discontinued product in a comparison, supply it on both sides with zero quantity where appropriate and explicit, meaningful price/cost assumptions.

[`schema/request.schema.json`](../schema/request.schema.json) describes the structure and per-input bounds for JSON Schema editors. Cross-row uniqueness, matching sets, positive mix contribution and safe arithmetic are checked by MoonBit, not by the schema file alone.

### Transport and JSON parser behavior

The JSON entry point accepts at most **16,000 UTF-16 code units**, including whitespace. This is a transport limit for passing the document as one command argument on Windows, not a limit on the pure calculation API's collection size. The wrapper removes one leading UTF-8 BOM before checking the limit. Use compact JSON or call the typed MoonBit APIs directly for larger datasets.

The standard MoonBit JSON parser accepts duplicate object keys with **the last value taking effect**. The decoder cannot recover overwritten values and is not a duplicate-key detector. Provide unique object keys; use a linter that detects duplicate keys when preparing files. This is separate from duplicate product/period IDs, which the analysis APIs reject.

## Output fields

All responses have numeric `schema_version: 1` and Boolean `ok`. On success, `result.kind` matches the request kind. All fen amounts, units, weights and bundle counts are decimal **strings**, including values above JavaScript's exact integer range and negative profit/effect values.

- **plan:** `periods`, `cumulative` and `totals`. Each period includes product detail, revenue, variable/fixed costs, contribution, operating profit, target profit and `target_gap_fen`. Each cumulative row has `id` and `totals`. The last cumulative totals equal whole-plan totals.
- **comparison:** full evaluated `budget` and `actual` plans, `periods` containing matched results and product bridges, and aggregate `volume_effect_fen`, `price_effect_fen`, `variable_cost_effect_fen`, `fixed_cost_effect_fen`, `profit_delta_fen`. Actual period/cumulative order follows budget; detailed product arrays retain their own input order, while product effect rows follow budget order.
- **mix:** `planned`, `break_even`, `target`. Evaluations include the normalized `profile`, per-product sales and totals. Target results include `required` and `rounding_surplus_fen`.
- **capacity:** `products` with product identity, selected `units`, revenue, variable cost and contribution; `resources` with used/capacity totals; whole-plan revenue, variable cost, contribution, fixed cost, operating profit and explored node count.
- **capacity_sensitivity:** `baseline` and `increased_capacity` exact results, the selected resource's before/after capacities, contribution/profit deltas, product quantity changes and search budget/effort. `metric` identifies a discrete one-unit capacity difference; it is not a continuous shadow price.

`target_gap_fen` is target minus profit: positive is shortfall, negative is excess. Profit effects are actual minus budget: positive improves profit. The declared product-quantity → price → unit variable cost → fixed cost replacement order determines interaction allocation. Quantity effects include composition changes; they do not isolate a separate pure mix effect. The bridge is an accounting decomposition, not causal proof. Profit is not cash flow.

Within a product bridge, `profit_delta_fen` is that product's contribution change **before shared fixed cost**. It is not an allocated product operating profit. Shared fixed cost appears only in the period/plan bridge.

Every aggregate, signed difference and bridge intermediate must fit signed Int64. Overflow returns an error, even when later cancellation could make the final total fit. No partial financial result is emitted after a failure.

## Errors and exit status

```json
{"schema_version":1,"ok":false,"error":{"kind":"analysis","detail":"UnitsOutOfRange(\"2026-10\", \"meal\")"}}
```

| Error kind | Meaning |
| --- | --- |
| `decode` | Invalid JSON, schema/type/field/integer error, or transport limit |
| `analysis` | Typed financial validation, ID-pairing, overflow or reconciliation error |
| `usage` | Wrong command arguments |
| `io` | Wrapper could not read the input file |
| `runner` | Missing/failing toolchain or invalid runner output |

`detail` is diagnostic text, not a stable machine-parsing interface. MoonBit callers that need specific error branches should use `parse_request` and the typed analysis APIs. The wrapper exits **0** on success, **2** for input/analysis errors, **1** for runner failures. Toolchain diagnostics use stderr; stdout remains one response document. Direct `moon run cmd/report` reports errors through `ok:false` and may still exit 0; callers must inspect the envelope or use the wrapper.

Run `node scripts/check-examples.mjs js` (or `native`) to execute the five editable examples, verify optimized product quantities, the one-unit resource comparison, financial reconciliation, budget bridge, decimal-string precision and error behavior. Unit tests additionally cover missing/unknown fields, integer boundaries, invalid pairs, losses, zero volume, optimization bounds, incomplete sensitivity searches and overflow.
