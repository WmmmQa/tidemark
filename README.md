# Tidemark

**A MoonBit bounded integer resource optimizer with management-accounting applications.**

Tidemark solves bounded integer allocation problems under scarce-resource limits, then provides management-accounting APIs for explaining the resulting plans. The optimizer is a reusable algorithmic core for production mix, project selection and other finite resource-allocation problems; the other packages cover contribution analysis, multi-period plans and budget-to-actual profit bridges. All calculation APIs are pure MoonBit and can be used without the command-line wrappers.

MoonBit also has broader LP/MIP tooling such as [moonopt](https://mooncakes.io/docs/Freon793/moonopt@0.4.0), which supports standard model formats and general integer-programming workflows. Tidemark focuses on a bounded resource model with a finance-facing API: product prices, variable costs, shared capacities and fixed costs produce whole-unit allocations and reconciled contribution/profit details.

## Packages and current scope

| Import | Reusable functionality |
| --- | --- |
| `WmmmQa/tidemark/domain` | Single-product assumptions, validation and unit contribution |
| `WmmmQa/tidemark/engine` | Contribution ratio, break-even, target-profit volume/revenue, profit, safety margin, named scenarios and sensitivity |
| `WmmmQa/tidemark/portfolio` | Fixed-mix targets and comparisons, contribution-maximizing resource plans and exact one-unit resource sensitivity |
| `WmmmQa/tidemark/planning` | Multi-period product sales, cumulative amounts, target gaps and ID-aligned budget/actual profit decomposition |
| `WmmmQa/tidemark/interchange` | Reusable versioned JSON for capacity optimization, discrete resource sensitivity and financial analysis |
| `WmmmQa/tidemark/optimizer` | Exact bounded integer optimization under multiple resource-capacity constraints |

Portfolio break-even still assumes a fixed sales mix within one period. `portfolio.optimize_capacity_plan` uses the separate `optimizer` package to select product quantities without a fixed ratio, then reconciles revenue, variable cost, contribution and shared fixed cost. `portfolio.capacity_resource_sensitivity` resolves the plan twice to compare the current capacity with one additional unit; it reports a discrete plan-specific difference before any cost to obtain extra capacity, not a continuous shadow price. Operating plans can vary products and costs by period. The library does not forecast demand, manage inventory, calculate tax or accounting statements, or treat operating profit as cash flow.

To call these packages from another MoonBit project, follow the [local workspace integration guide](fieldbook/using-as-a-library.md). It imports all six packages and runs a separate consumer against the local source, before any Mooncakes release.

## Run the core capacity optimizer

Run a three-product example that calls `portfolio.optimize_capacity_plan`, backed by the bounded integer solver:

```sh
moon run cmd/capacity --target js
```

The hypothetical plan uses labor and material capacities of 12 and 10. It selects 3 meals, 3 drinks and 1 dessert, using both resources fully. The result reports revenue of 46,000 fen, variable cost of 25,900 fen, contribution of 20,100 fen and operating profit of 17,100 fen after 3,000 fen of shared fixed cost. All values are calculated by the MoonBit API; the command does not print a preset answer. See [`cmd/capacity/main.mbt`](cmd/capacity/main.mbt) for the complete input.

## Start with an editable JSON file

Requires MoonBit and Node.js (CI uses Node 22). From the repository directory:

```sh
node scripts/analyze.mjs examples/product-mix.json
node scripts/analyze.mjs examples/operating-plan.json
node scripts/analyze.mjs examples/budget-actual.json
node scripts/analyze.mjs examples/capacity-plan.json
node scripts/analyze.mjs examples/resource-value.json
```

Copy an example, edit the decimal strings and rerun the command. Money uses integer **fen** (¥80 = `"8000"`); quantities use whole units. The wrapper loads the file and passes it to the MoonBit CLI. All business calculations, schema decoding and financial result construction are MoonBit code. The result on stdout is one JSON document, suitable for another program to consume. Amounts and quantities remain strings even when results exceed JavaScript's exact integer range.

| File | Reproducible result |
| --- | --- |
| `product-mix.json` | 2:1 mix; break-even 191 normalized bundles; ¥8,000 target requires 286 bundles |
| `operating-plan.json` | October profit ¥5,000; November loss ¥1,000; total profit ¥4,000 and target gap ¥8,000 |
| `budget-actual.json` | Two-period budget profit ¥14,200 versus actual ¥4,660; difference −¥9,540 |
| `capacity-plan.json` | Three products, two scarce resources; exact whole-unit plan and reconciled operating profit |
| `resource-value.json` | Raising labor capacity from 12 to 13 changes the optimal mix and increases contribution/profit by ¥13 |

These are separate hypothetical operating scenarios. Input fields, output structure, integer limits and errors are specified in [`fieldbook/json-interface.md`](fieldbook/json-interface.md); [`schema/request.schema.json`](schema/request.schema.json) supports editor validation. Native execution is available with `--target native` when a C toolchain is installed. The default target is JS.

The capacity request is editable as JSON. It sends product price, variable cost and quantity cap together with resource capacities, per-product resource use, shared fixed cost and a search-node limit to the MoonBit API. `node scripts/analyze.mjs examples/capacity-plan.json` returns exact optimized quantities and reconciled finance/resource totals. `examples/resource-value.json` uses the same input model plus `resource_id`; MoonBit solves the base and +1 capacity cases independently, then reports the profit/contribution delta and product quantity changes. Each solve receives the requested node budget, so total node budget is twice that value. If either solve cannot prove its optimum, no comparison is returned. The delta excludes any cost to obtain extra capacity; compare it with that cost before making an operating decision. It is a discrete scenario result, not a continuous shadow price or a causal forecast. Financial values and quantities remain decimal strings.

## Bounded integer resource optimization

`optimizer.optimize(problem, max_nodes)` maximizes the sum of nonnegative per-unit values while respecting each resource capacity and each decision's finite quantity bound. The solver uses deterministic branch-and-bound with a safe per-resource value-density upper bound. A result is returned only after the search proves optimality; if the node budget is exhausted, it returns a typed error instead of an unproven incumbent.

For example, with 10 labor units and 8 material units, a panel decision worth 8 uses 5 labor and 3 material, while a kit worth 9 uses 2 labor and 4 material. The exact optimum is 2 kits, value 18. A complete importable MoonBit example is in [`fieldbook/using-as-a-library.md`](fieldbook/using-as-a-library.md).

The bounded model supports up to 32 decisions and 16 resources. Per-unit values, resource capacities, resource use and decision bounds are nonnegative and at most 1,000,000,000; the search budget is at most 250,000 nodes. Constraints are resource upper bounds and decision upper bounds; minimum quantities, equality constraints, nonlinear objectives and decision interactions are outside this solver's scope. Larger or harder cases may return `SearchLimitExceeded` and require a higher-level planning method.

## Single-product pricing

At a selling price of ¥80, unit variable cost of ¥48 and fixed operating cost of ¥16,000, contribution is ¥32 per item. Break-even is 500 whole units; an ¥8,000 profit target requires 750 units and ¥60,000 revenue.

At 700 planned units the profit is ¥6,400 and safety margin 200 units. Lowering only the price to ¥75 yields ¥2,900 profit, break-even 593 units and safety margin 107 units. The sensitivity result reports changes of −¥3,500 profit, +93 break-even units and −93 safety-margin units.

Run the built-in example or pass your own eight integers:

```sh
moon run cmd/main --target js
moon run cmd/main --target js 8000 4800 1600000 700 7500 4800 1600000 700
```

Input order: baseline selling price, unit variable cost, fixed cost, planned units; then the same four alternative inputs. Money is **integer fen** (¥80 = `8000`), volume is whole units. With no arguments the command uses the example above. Invalid integer syntax prints usage; invalid financial assumptions produce correction messages and unavailable metrics.

For the built-in baseline, try these alternatives:

| Question | Alternative price, variable cost, fixed cost, units |
| --- | --- |
| Lower selling price | `7500 4800 1600000 700` |
| Higher unit variable cost | `8000 5200 1600000 700` |
| Higher rent/fixed cost | `8000 4800 1800000 700` |
| Lower planned volume | `8000 4800 1600000 600` |

The single-product API is unchanged. `CvpCase::issues()` reports input problems; derived calculations return `None` for invalid inputs. `compare_scenarios` preserves invalid rows with their issues. `sensitivity_analysis` reports signed changes; change one driver at a time when interpreting an individual effect. Single-product ordinary CVP requires a positive unit contribution.

## Multi-product sales mixes

Add the portfolio import to your package's `moon.pkg`:

```text
import {
  "WmmmQa/tidemark/portfolio",
}
```

Construct a plan and handle the typed `Result`:

```moonbit
let plan : @portfolio.MixPlan = {
  items: [
    {
      product: { id: "meal", selling_price_fen: 8000L, variable_cost_fen: 4800L },
      weight: 2L,
    },
    {
      product: { id: "drink", selling_price_fen: 5000L, variable_cost_fen: 3000L },
      weight: 1L,
    },
  ],
  fixed_cost_fen: 1600000L,
}
match @portfolio.mix_target(plan, 800000L) {
  Ok(target) => println(target.required.revenue_fen)
  Err(_) => println("Check product inputs, contribution and numeric range.")
}
```

One normalized bundle contains two meals and one drink. Revenue is 21,000 fen, variable cost 12,600 fen and contribution 8,400 fen. Contributions are summed by product quantities; individual margin percentages are not simply averaged.

| Question | API | Result for this plan |
| --- | --- | --- |
| What is one bundle? | `describe_mix(plan)` | Weights 2:1; contribution 8,400 fen |
| What happens at 250 bundles? | `evaluate_mix(plan, 250L)` | 500 meals, 250 drinks; profit 500,000 fen |
| What covers shared fixed costs? | `mix_break_even(plan)` | 191 bundles: 382 meals, 191 drinks; revenue 4,011,000 fen |
| What reaches 800,000 fen profit? | `mix_target(plan, 800000L)` | 286 bundles: 572 meals, 286 drinks; revenue 6,006,000 fen; profit 802,400 fen |
| What if the mix becomes 1:2? | `compare_mixes(plan, 250L, alternative, 250L)` | Profit falls by 300,000 fen; product quantities differ |

Break-even rounds up to a **complete bundle**: 190 bundles still lose 4,000 fen, while 191 earn 4,400 fen. Target results include the rounding surplus. Weights are divided by their greatest common divisor, so 4:2 and 2:1 give identical bundle definitions and results. Planned volume is in **normalized bundles**, not bundles of the original unnormalized ratio.

Run the complete example, a separate package importing the portfolio API:

```sh
moon run cmd/mix --target js
```

### Assumptions and validation

- Product IDs are unique, case-sensitive, nonblank and have no leading/trailing whitespace. Each product has its own whole-unit quantity. The ratio is an assumed sales composition, not an inventory recipe or demand forecast.
- Price must be positive, unit variable cost and shared fixed cost nonnegative. A product may have zero or negative contribution; the combined bundle must contribute positively. Shared fixed cost is deducted once, without inventing an allocation of fixed costs to products.
- All products and costs use one currency, cost basis and period. Price and variable cost per unit stay constant over the modeled range. All products must sell in the specified mix; whole-bundle targets can be conservative when arbitrary quantities are feasible.
- `MixError` distinguishes empty mixes, invalid/duplicate IDs, price/cost/weight/fixed-cost/target/volume bounds, nonpositive bundle contribution and arithmetic overflow. The first detected error is returned; there is no partial numeric result. Error types and fields are in [`portfolio/model.mbt`](portfolio/model.mbt) and the generated package interface.
- `compare_mixes` returns alternative-minus-baseline financial changes and both product breakdowns. Different bundles are not a common physical unit; the API deliberately does not subtract bundle counts or imply equal bundle counts mean equal volume.

### Numeric limits

All calculation APIs use signed `Int64` integer fen and whole quantities, with upward rounding for required sales.

| Input | Single product | Portfolio |
| --- | --- | --- |
| Each price/cost/fixed cost and target profit | At most 1,000,000,000 fen (¥10,000,000) | Same |
| Planned input | 0–1,000,000,000 units | 0–1,000,000,000 normalized bundles |
| Raw mix weight | Not applicable | 1–1,000,000,000; normalized by GCD |

Derived quantities and monetary totals may exceed these input limits but must fit signed `Int64`. Portfolio additions, volume multiplications and signed comparisons are checked; an unrepresentable result returns `Err(Overflow(context))`. Valid individual rows do not guarantee a representable portfolio total. Target-derived bundle counts may exceed the planned-input limit. The original single-product bounds keep its intermediates representable; invalid inputs return `None`.

## Multi-period plans and budget execution

Import `WmmmQa/tidemark/planning` for pure typed APIs:

- `evaluate_period(PeriodPlan)` returns product detail, period amounts and a signed target gap.
- `evaluate_plan(Array[PeriodPlan])` returns period results, cumulative amounts after each period and totals. Array order defines chronology; IDs are opaque labels, not parsed calendar dates.
- `compare_plans(budget, actual)` aligns periods and products by ID and returns product-contribution effects and period/whole-plan profit effects. Actual periods and cumulative totals follow budget chronology, even if actual input rows arrive in another order. Product effect rows follow budget order; product detail retains each side's input order, so consumers should join by ID.

After adding the planning import to `moon.pkg`, this complete `main.mbt` example prints a target gap of `160000` fen:

```moonbit
fn main {
  let period : @planning.PeriodPlan = {
    id: "October",
    products: [{
      product: { id: "meal", selling_price_fen: 8000L, variable_cost_fen: 4800L },
      units: 700L,
    }],
    fixed_cost_fen: 1600000L,
    target_profit_fen: 800000L,
  }
  match @planning.evaluate_plan([period]) {
    Ok(result) => println(result.totals.target_gap_fen)
    Err(_) => println("Check period inputs and numeric bounds.")
  }
}
```

`PeriodPlan` contains `id`, product/quantity rows, shared fixed cost and target profit. Every period and product list must be nonempty, with unique, already-trimmed, nonblank IDs. Products can change between periods, but budget and actual must have exactly matching product sets within each matched period and exactly matching period sets. A new or discontinued product must be explicitly represented on both sides, using zero quantity where appropriate and documented price/cost assumptions; the library never invents those observations.

Unlike break-even analysis, operating records allow zero selling price, zero volume and nonpositive product or period contribution. Every price, cost, fixed-cost and target input is from 0 to 1,000,000,000 fen; each product's period quantity is from 0 to 1,000,000,000 units. Currency, cost basis and each product's unit must be consistent across compared periods. `target_gap_fen = target_profit_fen - operating_profit_fen`: positive is an unmet target, negative is an excess. Cumulative fields are sums of operating amounts; break-even quantities for different mixes are not summed.

The bridge replaces product quantities, then selling prices, then unit variable costs, then shared fixed cost. With B = budget and A = actual:

```text
volume effect   = sum((A.units - B.units) * (B.price - B.variable_cost))
price effect    = sum((A.price - B.price) * A.units)
variable effect = sum((B.variable_cost - A.variable_cost) * A.units)
fixed effect    = B.fixed_cost - A.fixed_cost
sum of effects  = A.operating_profit - B.operating_profit
```

Positive effects improve actual profit relative to budget. Product-volume effects include sales composition changes; this is not a separate pure total-volume versus mix decomposition. The substitution order allocates interaction effects and is an accounting explanation, not causal evidence. Every signed intermediate, cumulative total and reconciliation is checked; an unrepresentable intermediate returns a typed `PlanError`, even if later cancellation could make a final number fit.

For `budget-actual.json`, total effects are −116,000 fen for product quantities, −304,000 for selling prices, −284,000 for unit variable costs and −250,000 for fixed costs. Their sum is −954,000 fen, exactly 466,000 actual profit minus 1,420,000 budget profit. The example deliberately reverses actual period/product row order to exercise ID alignment.

## Development and verification

Requires the MoonBit toolchain. CI pins compiler `0.10.15+943464bfa`.

```sh
moon fmt
moon info
moon check --target native --deny-warn
moon test --target native --deny-warn
moon run cmd/main --target js
moon run cmd/mix --target js
node scripts/check-examples.mjs js
node scripts/check-library-consumer.mjs js
```

On Windows without MSVC, run the JS test and execution commands locally; `moon check --target native --deny-warn` still checks native packages, while native execution requires a C toolchain. GitHub Actions on Ubuntu checks formatting, generated interfaces, native compilation and tests, financial examples, structured file workflows, and a two-module consumer importing all six public packages on native and JS targets. Tests cover allocation optima against exhaustive small grids, multiple resource limits, deterministic ties, search exhaustion and overflow, alongside CVP, portfolio, multi-period, reconciliation and JSON boundaries. The example checker also verifies CLI output, error codes and profit bridges using `BigInt`.

The commands consume the libraries; optimization code lives in `optimizer/`, management-accounting calculations in `domain/`, `engine/`, `portfolio/` and `planning/`, and financial JSON handling in `interchange/`. Scenarios, algorithm limits and design choices are in [`fieldbook/project-brief.md`](fieldbook/project-brief.md). Mooncakes publishing has not been performed; see [`fieldbook/release-checklist.md`](fieldbook/release-checklist.md) when preparing a release.

## License

Apache-2.0
