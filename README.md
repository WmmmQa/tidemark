# Tidemark

**A small MoonBit engine for cost-volume-profit decisions.**

Tidemark turns a few operating assumptions into a transparent break-even calculation: selling price, variable cost per unit, and fixed operating cost. It is aimed at management accounting exercises and early-stage pricing decisions where people need to see how the result follows from the inputs.

## Current scope

The model focuses on one product and one operating period. It provides the reusable calculation model, core break-even and target-profit quantities, named scenario comparison, and one-driver-at-a-time sensitivity analysis. Scenario results include break-even units, operating profit at planned volume, and safety margin.

Tidemark does not estimate demand, forecast sales, account for tax, or decide whether a business plan is viable. Results depend on the assumptions entered by the user.

## A quick example

Suppose a shop sells an item for ¥80, has ¥48 of variable cost per item, and incurs ¥16,000 of fixed cost for the period:

- Contribution per item: ¥80 − ¥48 = ¥32
- Break-even quantity: ¥16,000 ÷ ¥32 = 500 items
- For a target operating profit of ¥8,000: (¥16,000 + ¥8,000) ÷ ¥32 = 750 items

All money values in the calculation API use integer fen. The equations use whole units and round required quantities up, so a target is not understated by a fractional unit.

The public calculation surface currently covers input diagnostics, unit contribution, contribution margin in basis points, break-even units, target-profit units and revenue, operating profit, and safety margin. Invalid cases return `None` from derived calculations; `CvpCase::issues()` reports the input reasons.

## Compare a pricing change

At 700 planned units, a baseline assumption of ¥80 selling price, ¥48 variable cost, and ¥16,000 fixed cost produces ¥6,400 operating profit, a 500-unit break-even point, and 200 units of safety margin. Reducing price to ¥75 while keeping the other assumptions unchanged produces ¥2,900 profit, a 593-unit break-even point, and 107 units of safety margin. The sensitivity result reports the changes from baseline: −¥3,500 profit, +93 break-even units, and −93 safety-margin units.

Use `compare_scenarios` to evaluate several named assumption sets side by side. Use `sensitivity_analysis` to compare a baseline with alternatives; change one input driver per alternative so the effect remains interpretable. Invalid scenarios remain in the result list with their issue reasons and no derived metrics, so one bad row does not hide the others. Multi-product sales mix, demand forecasting, tax, and accounting-standard judgments remain outside the model.

## Project proposal

The one-page scope, three intended usage scenarios, and boundary decisions are recorded in [`fieldbook/project-brief.md`](fieldbook/project-brief.md).

## Development

Requires the MoonBit toolchain.

```sh
moon check --target native
```

The core is split between `domain/` (operating assumptions and their validity) and `engine/` (derived quantities and scenario comparisons). The examples are deliberately small enough to verify by hand.

## License

Apache-2.0
