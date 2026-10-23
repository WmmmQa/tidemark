///|
/// A separate package importing the reusable portfolio API, without domain internals.
fn main {
  let plan : @portfolio.MixPlan = {
    items: [
      {
        product: {
          id: "meal",
          selling_price_fen: 8000L,
          variable_cost_fen: 4800L,
        },
        weight: 2L,
      },
      {
        product: {
          id: "drink",
          selling_price_fen: 5000L,
          variable_cost_fen: 3000L,
        },
        weight: 1L,
      },
    ],
    fixed_cost_fen: 1600000L,
  }
  println("Tidemark · meal:drink = 2:1; all money is fen")
  match @portfolio.mix_break_even(plan) {
    Ok(target) => show("Break-even", target)
    Err(error) => println(@debug.to_string(error))
  }
  match @portfolio.mix_target(plan, 800000L) {
    Ok(target) => show("Target profit 800000 fen", target)
    Err(error) => println(@debug.to_string(error))
  }
  let alternative : @portfolio.MixPlan = {
    ..plan,
    items: [{ ..plan.items[0], weight: 1L, }, { ..plan.items[1], weight: 2L, }],
  }
  match @portfolio.compare_mixes(plan, 250L, alternative, 250L) {
    Ok(result) => {
      println("Compare 250 bundles at 2:1 with 250 bundles at 1:2")
      println(
        "Product quantities differ; bundle counts are not common physical units.",
      )
      println(
        "Operating profit change (fen): \{result.operating_profit_delta_fen}",
      )
    }
    Err(error) => println(@debug.to_string(error))
  }
}

///|
fn show(label : String, target : @portfolio.MixTarget) -> Unit {
  let result = target.required
  println("\{label}: \{result.planned_bundles} bundles")
  for product in result.products {
    println("  \{product.product.id}: \{product.units} units")
  }
  println("Revenue (fen): \{result.revenue_fen}")
  println("Operating profit (fen): \{result.operating_profit_fen}")
  println("Rounding surplus (fen): \{target.rounding_surplus_fen}")
}
