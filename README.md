# Tidemark

**A MoonBit library for cost-volume-profit and product-mix decisions.**

Tidemark turns explicit operating assumptions into reproducible profit calculations. It supports single-product CVP and multi-product sales mixes with shared fixed costs, whole-bundle target plans and product-level results. It is intended for management accounting tools, small-business planning and teaching applications built with MoonBit.

## Packages and current scope

| Import | Reusable functionality |
| --- | --- |
| `WmmmQa/tidemark/domain` | Single-product assumptions, validation and unit contribution |
| `WmmmQa/tidemark/engine` | Contribution ratio, break-even, target-profit volume/revenue, profit, safety margin, named scenarios and sensitivity |
| `WmmmQa/tidemark/portfolio` | Normalized multi-product sales mixes, shared fixed costs, product quantities, whole-bundle targets and financial comparisons |

Each evaluation covers one operating period. Multi-period aggregation and budget-versus-actual attribution are not implemented yet. The model does not forecast demand, account for tax, handle inventory or capacity constraints, or decide whether a business plan is viable. Operating profit is not cash flow.

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

## Development and verification

Requires the MoonBit toolchain. CI pins compiler `0.10.15+943464bfa`.

```sh
moon fmt
moon info
moon check --target native --deny-warn
moon test --target native --deny-warn
moon run cmd/main --target js
moon run cmd/mix --target js
```

On Windows without MSVC, use `moon test --target js`; native execution requires a C toolchain. GitHub Actions on Ubuntu checks formatting and generated interfaces, native compilation, tests, built-in/custom single-product inputs and the portfolio example. Tests cover equivalent ratios, target minimality, loss-leading products, invalid rows, aggregate overflow, signed arithmetic boundaries and compatibility with the single-product API.

The commands consume the libraries; business calculations live in `domain/`, `engine/` and `portfolio/`. Three complete usage scenarios and design choices are in [`fieldbook/project-brief.md`](fieldbook/project-brief.md). Mooncakes publishing has not been performed; see [`fieldbook/release-checklist.md`](fieldbook/release-checklist.md) when preparing a release.

## License

Apache-2.0
