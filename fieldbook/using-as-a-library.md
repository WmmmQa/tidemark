# Use Tidemark from another MoonBit project

Tidemark is currently distributed as source. Use a MoonBit workspace to resolve the module locally, then import only the packages your application needs. Mooncakes publication is not needed for this workflow.

## 1. Prepare sibling modules

Create a workspace directory and clone the library into it:

```sh
mkdir tidemark-workspace
cd tidemark-workspace
git clone https://github.com/WmmmQa/tidemark.git tidemark
mkdir consumer
```

The resulting files should have this structure:

```text
tidemark-workspace/
  moon.work
  tidemark/
    moon.mod
    domain/
    engine/
    portfolio/
    planning/
    interchange/
  consumer/
    moon.mod
    moon.pkg
    main.mbt
```

Create `moon.work` in the workspace directory:

```text
members = ["tidemark", "consumer"]
```

Create `consumer/moon.mod`:

```text
name = "example/tidemark-consumer"
import {
  "WmmmQa/tidemark@0.3.0",
}
```

The workspace resolves `WmmmQa/tidemark` from its local member. Here `0.3.0` records the source module's version; it does not claim that this version is published to the registry. Local changes to that member are used by the consumer. See MoonBit's [module dependency documentation](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#dependency-management) for workspace resolution.

## 2. Import and call the packages

Create `consumer/moon.pkg`:

```text
import {
  "WmmmQa/tidemark/domain",
  "WmmmQa/tidemark/engine",
  "WmmmQa/tidemark/portfolio",
  "WmmmQa/tidemark/planning",
  "WmmmQa/tidemark/interchange",
}
pkgtype(kind: "executable")
```

Create `consumer/main.mbt`:

```moonbit
fn main {
  let product : @portfolio.Product = {
    id: "meal",
    selling_price_fen: 8000L,
    variable_cost_fen: 4800L,
  }
  let case : @domain.CvpCase = {
    selling_price_fen: product.selling_price_fen,
    variable_cost_fen: product.variable_cost_fen,
    fixed_cost_fen: 1600000L,
  }
  match @engine.break_even_units(case) {
    Some(units) => println("Single-product break-even units: \{units}")
    None => println("Invalid single-product case")
  }
  let mix : @portfolio.MixPlan = {
    items: [{ product, weight: 1L }],
    fixed_cost_fen: 1600000L,
  }
  match @portfolio.mix_break_even(mix) {
    Ok(target) => println("Portfolio break-even bundles: \{target.required.planned_bundles}")
    Err(_) => println("Invalid product mix")
  }
  let period : @planning.PeriodPlan = {
    id: "October",
    products: [{ product, units: 700L }],
    fixed_cost_fen: 1600000L,
    target_profit_fen: 800000L,
  }
  match @planning.evaluate_plan([period]) {
    Ok(result) => println("Target gap (fen): \{result.totals.target_gap_fen}")
    Err(_) => println("Invalid operating plan")
  }
  match @interchange.parse_request("{}") {
    Err(_) => println("Invalid JSON request rejected")
    Ok(_) => println("Unexpected valid request")
  }
}
```

## 3. Run the consumer

From the `consumer` directory:

```sh
moon check --target native --deny-warn
moon run --target js .
```

Expected stdout:

```text
Single-product break-even units: 500
Portfolio break-even bundles: 500
Target gap (fen): 160000
Invalid JSON request rejected
```

The native command checks the packages; executing the native target additionally requires a C toolchain. The calculation APIs take typed MoonBit values and do not require Node.js. Node.js is used for the JS backend and for the separate file wrapper described in the README.

Applications can import fewer packages and replace this illustrative error handling with their own messages. Handle `MixError`, `PlanError` and `DecodeError` explicitly when calling their corresponding APIs; input units and model limits remain those documented in the README and JSON interface.
