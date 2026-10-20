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

The public calculation surface currently covers input diagnostics, unit contribution, contribution margin in basis points, break-even units, target-profit units and revenue, operating profit, and safety margin. Invalid cases return `None` from derived calculations; `CvpCase::issues()` reports the input reasons. To keep every intermediate result representable as `Int64`, each monetary input and target profit is limited to ¥10,000,000 (1,000,000,000 fen), and each planned volume is limited to 1,000,000,000 units. `CvpCase::contribution_fen()` also returns `None` for invalid inputs.

## Compare a pricing change

At 700 planned units, a baseline assumption of ¥80 selling price, ¥48 variable cost, and ¥16,000 fixed cost produces ¥6,400 operating profit, a 500-unit break-even point, and 200 units of safety margin. Reducing price to ¥75 while keeping the other assumptions unchanged produces ¥2,900 profit, a 593-unit break-even point, and 107 units of safety margin. The sensitivity result reports the changes from baseline: −¥3,500 profit, +93 break-even units, and −93 safety-margin units.

Use `compare_scenarios` to evaluate several named assumption sets side by side. Use `sensitivity_analysis` to compare a baseline with alternatives; change one input driver per alternative so the effect remains interpretable. Invalid scenarios remain in the result list with their issue reasons and no derived metrics, so one bad row does not hide the others. Multi-product sales mix, demand forecasting, tax, and accounting-standard judgments remain outside the model.

## Project proposal

The one-page scope, three intended usage scenarios, and boundary decisions are recorded in [`fieldbook/project-brief.md`](fieldbook/project-brief.md).

## Development

Requires the MoonBit toolchain. The runnable pricing walkthrough compares a baseline with a promotion-price scenario and prints the signed changes.

```sh
moon fmt
moon info
moon check --target native
moon test --target native
moon run cmd/main --target js
```

To compare your own baseline with an alternative, pass eight integer inputs in this order: baseline price (fen), baseline variable cost per unit (fen), baseline fixed cost (fen), baseline planned units, then the same four values for the alternative. Keep the other seven values unchanged when you want to isolate one driver.

```sh
moon run cmd/main --target js 8000 4800 1600000 700 7500 4800 1600000 700
```

This compares ¥80 / ¥48 / ¥16,000 at 700 units against ¥75 / ¥48 / ¥16,000 at 700 units. It reports operating profit, break-even units, safety margin, and the signed changes. Use fen for money inputs (for example, ¥80 is `8000`) and whole units for volume. With no arguments, the command runs the built-in example. Invalid integer syntax prints the input form; values outside the supported range or with no positive unit contribution have unavailable metrics and a specific correction message.

For the built-in baseline of `8000 4800 1600000 700`, use these alternative inputs to explore common operating questions:

| Decision question | Alternative price, unit variable cost, fixed cost, units |
| --- | --- |
| What if a promotion lowers the selling price? | `7500 4800 1600000 700` |
| What if unit variable cost rises? | `8000 5200 1600000 700` |
| What if rent or other fixed costs increase? | `8000 4800 1800000 700` |
| What if planned volume falls? | `8000 4800 1600000 600` |

The built-in walkthrough uses ¥80/¥48/¥16,000 as its baseline and changes only the selling price to ¥75 in the promotion scenario. It reports 500 vs. 593 break-even units, 640,000 vs. 290,000 fen of operating profit, and the signed differences. The executable is in [`cmd/main/main.mbt`](cmd/main/main.mbt). The GitHub Actions workflow pins the MoonBit compiler and runs both the built-in walkthrough and a custom-input scenario on the native target.

```text
Baseline: break-even 500 units, operating profit 640000 fen, safety margin 200 units
Promotion price: break-even 593 units, operating profit 290000 fen, safety margin 107 units
Change: profit -350000 fen, break-even +93 units, safety margin -93 units
```

The core is split between `domain/` (operating assumptions and their validity) and `engine/` (derived quantities and scenario comparisons). The examples are deliberately small enough to verify by hand.

The GitHub Actions workflow checks formatting, generated package interfaces, native compilation, CVP boundary tests, and the walkthrough. Mooncakes publishing has not been performed; see [`fieldbook/release-checklist.md`](fieldbook/release-checklist.md) before preparing a release.

## License

Apache-2.0
