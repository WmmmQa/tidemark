///|
/// Reproducible example of maximizing product contribution under shared
/// labor and material limits. All monetary values are integer fen.
fn main {
  let plan : @portfolio.CapacityPlan = {
    resources: [
      { id: "labor", capacity: 12L, },
      { id: "material", capacity: 10L, },
    ],
    items: [
      {
        product: {
          id: "meal",
          selling_price_fen: 8000L,
          variable_cost_fen: 4800L,
        },
        max_units: 5L,
        resource_uses: [
          { resource_id: "labor", units_per_decision: 2L, },
          { resource_id: "material", units_per_decision: 1L, },
        ],
      },
      {
        product: {
          id: "drink",
          selling_price_fen: 5000L,
          variable_cost_fen: 3000L,
        },
        max_units: 5L,
        resource_uses: [
          { resource_id: "labor", units_per_decision: 1L, },
          { resource_id: "material", units_per_decision: 2L, },
        ],
      },
      {
        product: {
          id: "dessert",
          selling_price_fen: 7000L,
          variable_cost_fen: 2500L,
        },
        max_units: 4L,
        resource_uses: [
          { resource_id: "labor", units_per_decision: 3L, },
          { resource_id: "material", units_per_decision: 1L, },
        ],
      },
    ],
    fixed_cost_fen: 3000L,
  }
  match @portfolio.optimize_capacity_plan(plan, 10000L) {
    Ok(result) => {
      println("Hypothetical product plan (money: fen)")
      println(
        "Optimal quantities (meal,drink,dessert): \{result.products[0].units},\{result.products[1].units},\{result.products[2].units}",
      )
      println("Revenue: \{result.revenue_fen}")
      println("Variable cost: \{result.variable_cost_fen}")
      println("Contribution: \{result.contribution_fen}")
      println("Shared fixed cost: \{result.fixed_cost_fen}")
      println("Operating profit: \{result.operating_profit_fen}")
      println(
        "Resource use (labor,material): \{result.resources[0].used}/\{result.resources[0].capacity},\{result.resources[1].used}/\{result.resources[1].capacity}",
      )
      println("Search nodes: \{result.explored_nodes}")
    }
    Err(error) => println(@debug.to_string(error))
  }
}
