///|
fn capacity_product(
  id : String,
  price : Int64,
  variable_cost : Int64,
) -> @portfolio.Product {
  { id, selling_price_fen: price, variable_cost_fen: variable_cost, }
}

///|
fn capacity_item(
  product : @portfolio.Product,
  max_units : Int64,
  resource_uses : Array[@optimizer.ResourceUse],
) -> @portfolio.CapacityItem {
  { product, max_units, resource_uses, }
}

///|
fn capacity_resource_use(id : String, units : Int64) -> @optimizer.ResourceUse {
  { resource_id: id, units_per_decision: units, }
}

///|
test "capacity plan maximizes contribution and reconciles shared fixed cost" {
  let plan : @portfolio.CapacityPlan = {
    resources: [
      { id: "labor", capacity: 5L, },
      { id: "material", capacity: 4L, },
    ],
    items: [
      capacity_item(capacity_product("meal", 8000L, 4800L), 5L, [
        capacity_resource_use("labor", 2L),
        capacity_resource_use("material", 1L),
      ]),
      capacity_item(capacity_product("drink", 5000L, 3000L), 5L, [
        capacity_resource_use("labor", 1L),
        capacity_resource_use("material", 2L),
      ]),
    ],
    fixed_cost_fen: 3000L,
  }
  let result = match @portfolio.optimize_capacity_plan(plan, 100L) {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
  @debug.assert_eq(result.products[0].units, 2L)
  @debug.assert_eq(result.products[1].units, 1L)
  @debug.assert_eq(result.resources[0].used, 5L)
  @debug.assert_eq(result.resources[1].used, 4L)
  @debug.assert_eq(result.revenue_fen, 21000L)
  @debug.assert_eq(result.variable_cost_fen, 12600L)
  @debug.assert_eq(result.contribution_fen, 8400L)
  @debug.assert_eq(result.fixed_cost_fen, 3000L)
  @debug.assert_eq(result.operating_profit_fen, 5400L)
}

///|
test "nonpositive contribution products are excluded without hiding a loss" {
  let plan : @portfolio.CapacityPlan = {
    resources: [],
    items: [
      capacity_item(capacity_product("loss", 100L, 150L), 3L, []),
      capacity_item(capacity_product("idle", 200L, 100L), 0L, []),
    ],
    fixed_cost_fen: 100L,
  }
  let result = match @portfolio.optimize_capacity_plan(plan, 100L) {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
  @debug.assert_eq(result.products[0].units, 0L)
  @debug.assert_eq(result.products[1].units, 0L)
  @debug.assert_eq(result.contribution_fen, 0L)
  @debug.assert_eq(result.operating_profit_fen, -100L)
}

///|
test "capacity plan rejects duplicate products and preserves optimizer errors" {
  let duplicate : @portfolio.CapacityPlan = {
    resources: [],
    items: [
      capacity_item(capacity_product("same", 2L, 1L), 1L, []),
      capacity_item(capacity_product("same", 2L, 1L), 1L, []),
    ],
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.optimize_capacity_plan(duplicate, 100L),
    Err(@portfolio.DuplicateCapacityProductId("same")),
  )

  let invalid_resource : @portfolio.CapacityPlan = {
    resources: [{ id: "labor", capacity: 10L, }],
    items: [
      capacity_item(capacity_product("meal", 2L, 1L), 1L, [
        capacity_resource_use("unknown", 1L),
      ]),
    ],
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.optimize_capacity_plan(invalid_resource, 100L),
    Err(
      @portfolio.AllocationFailure(
        @optimizer.UnknownResource("meal", "unknown"),
      ),
    ),
  )
}

///|
test "capacity financial totals return a typed error before aggregate overflow" {
  let items : Array[@portfolio.CapacityItem] = []
  for _ in 0..<10 {
    items.push(
      capacity_item(
        capacity_product("p\{items.length()}", 1_000_000_000L, 999_999_999L),
        1_000_000_000L,
        [],
      ),
    )
  }
  let plan : @portfolio.CapacityPlan = {
    resources: [],
    items,
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.optimize_capacity_plan(plan, 1L),
    Err(@portfolio.CapacityOverflow("capacity revenue total")),
  )
}
