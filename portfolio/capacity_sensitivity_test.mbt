///|
test "one additional binding resource is re-solved and may change the mix" {
  let plan : @portfolio.CapacityPlan = {
    resources: [
      { id: "labor", capacity: 12L, },
      { id: "material", capacity: 10L, },
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
      capacity_item(capacity_product("dessert", 7000L, 2500L), 4L, [
        capacity_resource_use("labor", 3L),
        capacity_resource_use("material", 1L),
      ]),
    ],
    fixed_cost_fen: 3000L,
  }
  let result = match
    @portfolio.capacity_resource_sensitivity(plan, "labor", 10000L) {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
  @debug.assert_eq(result.capacity_before, 12L)
  @debug.assert_eq(result.capacity_after, 13L)
  @debug.assert_eq(result.baseline.products.map(fn(row) { row.units }), [
    3L, 3L, 1L,
  ])
  @debug.assert_eq(
    result.increased_capacity.products.map(fn(row) { row.units }),
    [2L, 3L, 2L],
  )
  @debug.assert_eq(result.contribution_delta_fen, 1300L)
  @debug.assert_eq(result.operating_profit_delta_fen, 1300L)
  @debug.assert_eq(result.product_changes.map(fn(row) { row.units_delta }), [
    -1L, 0L, 1L,
  ])
  @debug.assert_eq(result.max_nodes_per_solve, 10000L)
  @debug.assert_eq(result.total_node_budget, 20000L)
  @debug.assert_eq(
    result.explored_nodes_total,
    result.baseline.explored_nodes + result.increased_capacity.explored_nodes,
  )
}

///|
test "nonbinding resource reports zero discrete value and no quantity change" {
  let plan : @portfolio.CapacityPlan = {
    resources: [{ id: "labor", capacity: 10L, }],
    items: [
      capacity_item(capacity_product("meal", 200L, 100L), 2L, [
        capacity_resource_use("labor", 1L),
      ]),
    ],
    fixed_cost_fen: 25L,
  }
  let result = match
    @portfolio.capacity_resource_sensitivity(plan, "labor", 10L) {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
  @debug.assert_eq(result.baseline.products[0].units, 2L)
  @debug.assert_eq(result.increased_capacity.products[0].units, 2L)
  @debug.assert_eq(result.contribution_delta_fen, 0L)
  @debug.assert_eq(result.operating_profit_delta_fen, 0L)
}

///|
test "sensitivity validates requested resource, duplicate IDs and capacity cap" {
  let plan : @portfolio.CapacityPlan = {
    resources: [{ id: "labor", capacity: 10L, }],
    items: [
      capacity_item(capacity_product("meal", 200L, 100L), 2L, [
        capacity_resource_use("labor", 1L),
      ]),
    ],
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, "material", 10L),
    Err(@portfolio.SensitivityResourceNotFound("material")),
  )
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, " labor", 10L),
    Err(@portfolio.InvalidSensitivityResourceId),
  )
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(
      {
        ..plan,
        resources: [
          { id: "labor", capacity: 2L, },
          { id: "labor", capacity: 3L, },
        ],
      },
      "labor",
      10L,
    ),
    Err(@portfolio.DuplicateSensitivityResourceId("labor")),
  )
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(
      { ..plan, resources: [{ id: "labor", capacity: 1_000_000_000L, }], },
      "labor",
      10L,
    ),
    Err(@portfolio.SensitivityCapacityAtMaximum("labor")),
  )
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, "labor", 0L),
    Err(@portfolio.SensitivitySearchBudgetOutOfRange),
  )
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, "labor", 250_001L),
    Err(@portfolio.SensitivitySearchBudgetOutOfRange),
  )
}

///|
test "incomplete increased-capacity search returns a typed stage error only" {
  let plan : @portfolio.CapacityPlan = {
    resources: [{ id: "labor", capacity: 0L, }],
    items: [
      capacity_item(capacity_product("meal", 200L, 100L), 2L, [
        capacity_resource_use("labor", 1L),
      ]),
      capacity_item(capacity_product("drink", 190L, 100L), 2L, [
        capacity_resource_use("labor", 1L),
      ]),
    ],
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, "labor", 1L),
    Err(
      @portfolio.SensitivityPlanFailure(
        @portfolio.IncreasedCapacity,
        @portfolio.AllocationFailure(@optimizer.SearchLimitExceeded(1L)),
      ),
    ),
  )
}

///|
test "financial total overflow during sensitivity is reported without a result" {
  let items : Array[@portfolio.CapacityItem] = []
  for _ in 0..<10 {
    items.push(
      capacity_item(
        capacity_product(
          "p" + items.length().to_string(),
          1_000_000_000L,
          999_999_999L,
        ),
        1_000_000_000L,
        [capacity_resource_use("labor", 0L)],
      ),
    )
  }
  let plan : @portfolio.CapacityPlan = {
    resources: [{ id: "labor", capacity: 1L, }],
    items,
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.capacity_resource_sensitivity(plan, "labor", 10L),
    Err(
      @portfolio.SensitivityPlanFailure(
        @portfolio.Baseline,
        @portfolio.CapacityOverflow("capacity revenue total"),
      ),
    ),
  )
}
