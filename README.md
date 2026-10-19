# Tidemark

**A small MoonBit engine for cost-volume-profit decisions.**

Tidemark turns a few operating assumptions into a transparent break-even calculation: selling price, variable cost per unit, and fixed operating cost. It is aimed at management accounting exercises and early-stage pricing decisions where people need to see how the result follows from the inputs.

## First release boundary

The first slice focuses on one product, one selling price, and one contribution margin. It provides the reusable calculation model and the core break-even and target-profit quantities. A scenario runner and multi-product sales-mix analysis are planned as later steps.

Tidemark does not estimate demand, forecast sales, account for tax, or decide whether a business plan is viable. Results depend on the assumptions entered by the user.

## A quick example

Suppose a shop sells an item for ¥80, has ¥48 of variable cost per item, and incurs ¥16,000 of fixed cost for the period:

- Contribution per item: ¥80 − ¥48 = ¥32
- Break-even quantity: ¥16,000 ÷ ¥32 = 500 items
- For a target operating profit of ¥8,000: (¥16,000 + ¥8,000) ÷ ¥32 = 750 items

All money values in the calculation API use integer fen. The equations use whole units and round required quantities up, so a target is not understated by a fractional unit.

The public calculation surface currently covers input diagnostics, unit contribution, contribution margin in basis points, break-even units, target-profit units and revenue, operating profit, and safety margin. Invalid cases return `None` from derived calculations; `CvpCase::issues()` reports the input reasons.

## Project proposal

The one-page scope, three intended usage scenarios, and boundary decisions are recorded in [`fieldbook/project-brief.md`](fieldbook/project-brief.md).

## Development

Requires the MoonBit toolchain.

```sh
moon check --target native
```

The core is split between `domain/` (operating assumptions and their validity) and `engine/` (derived quantities). The example above is deliberately small enough to verify by hand.

## License

Apache-2.0
