///|
fn item(
  id : String,
  price : Int64,
  cost : Int64,
  weight : Int64,
) -> @portfolio.MixItem {
  {
    product: { id, selling_price_fen: price, variable_cost_fen: cost, },
    weight,
  }
}

///|
fn shop() -> @portfolio.MixPlan {
  {
    items: [item("meal", 8000L, 4800L, 2L), item("drink", 5000L, 3000L, 1L)],
    fixed_cost_fen: 1600000L,
  }
}

///|
fn[T] must(result : Result[T, @portfolio.MixError]) -> T {
  match result {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
}

///|
test "equivalent ratios normalize to identical bundles and results" {
  let baseline = shop()
  let scaled : @portfolio.MixPlan = {
    ..baseline,
    items: [item("meal", 8000L, 4800L, 4L), item("drink", 5000L, 3000L, 2L)],
  }
  @debug.assert_eq(
    @portfolio.describe_mix(baseline),
    @portfolio.describe_mix(scaled),
  )
  @debug.assert_eq(
    @portfolio.evaluate_mix(baseline, 250L),
    @portfolio.evaluate_mix(scaled, 250L),
  )
  @debug.assert_eq(
    @portfolio.mix_target(baseline, 800000L),
    @portfolio.mix_target(scaled, 800000L),
  )
}

///|
test "bundle totals and product details reconcile at planned volume" {
  let result = must(@portfolio.evaluate_mix(shop(), 250L))
  @debug.assert_eq(result.profile.bundle_revenue_fen, 21000L)
  @debug.assert_eq(result.profile.bundle_variable_cost_fen, 12600L)
  @debug.assert_eq(result.profile.bundle_contribution_fen, 8400L)
  @debug.assert_eq(result.products[0].units, 500L)
  @debug.assert_eq(result.products[1].units, 250L)
  @debug.assert_eq(result.revenue_fen, 5250000L)
  @debug.assert_eq(result.variable_cost_fen, 3150000L)
  @debug.assert_eq(result.contribution_fen, 2100000L)
  @debug.assert_eq(result.operating_profit_fen, 500000L)
  @debug.assert_eq(
    result.products[0].revenue_fen + result.products[1].revenue_fen,
    result.revenue_fen,
  )
  @debug.assert_eq(
    result.products[0].contribution_fen + result.products[1].contribution_fen,
    result.contribution_fen,
  )
}

///|
test "nondivisible break even rounds up a whole bundle and is minimal" {
  let plan = shop()
  let result = must(@portfolio.mix_break_even(plan))
  @debug.assert_eq(result.required.planned_bundles, 191L)
  @debug.assert_eq(result.required.products[0].units, 382L)
  @debug.assert_eq(result.required.products[1].units, 191L)
  @debug.assert_eq(result.required.revenue_fen, 4011000L)
  @debug.assert_eq(result.rounding_surplus_fen, 4400L)
  @debug.assert_eq(
    must(@portfolio.evaluate_mix(plan, 190L)).operating_profit_fen,
    -4000L,
  )
}

///|
test "target profit returns quantities revenue and rounding surplus" {
  let result = must(@portfolio.mix_target(shop(), 800000L))
  @debug.assert_eq(result.required.planned_bundles, 286L)
  @debug.assert_eq(result.required.products[0].units, 572L)
  @debug.assert_eq(result.required.products[1].units, 286L)
  @debug.assert_eq(result.required.revenue_fen, 6006000L)
  @debug.assert_eq(result.required.operating_profit_fen, 802400L)
  @debug.assert_eq(result.rounding_surplus_fen, 2400L)
  assert_true(
    must(@portfolio.evaluate_mix(shop(), 285L)).operating_profit_fen < 800000L,
  )
}

///|
test "zero volume charges fixed cost once and zero fixed cost needs zero bundles" {
  @debug.assert_eq(
    must(@portfolio.evaluate_mix(shop(), 0L)).operating_profit_fen,
    -1600000L,
  )
  let plan : @portfolio.MixPlan = { ..shop(), fixed_cost_fen: 0L, }
  let target = must(@portfolio.mix_break_even(plan))
  @debug.assert_eq(target.required.planned_bundles, 0L)
  @debug.assert_eq(target.required.revenue_fen, 0L)
  @debug.assert_eq(target.rounding_surplus_fen, 0L)
}

///|
test "loss leader is valid when the whole bundle contributes positively" {
  let plan : @portfolio.MixPlan = {
    items: [item("sample", 100L, 150L, 1L), item("main", 500L, 200L, 1L)],
    fixed_cost_fen: 1001L,
  }
  let target = must(@portfolio.mix_break_even(plan))
  @debug.assert_eq(target.required.planned_bundles, 5L)
  @debug.assert_eq(target.required.products[0].contribution_fen, -250L)
  @debug.assert_eq(target.required.operating_profit_fen, 249L)
}

///|
test "zero and negative total contribution are rejected" {
  for cost in [100L, 101L] {
    let plan : @portfolio.MixPlan = {
      items: [item("a", 100L, cost, 1L)],
      fixed_cost_fen: 0L,
    }
    @debug.assert_eq(
      @portfolio.describe_mix(plan),
      Err(@portfolio.NonPositiveMixContribution),
    )
  }
}

///|
test "empty products duplicate identity and ambiguous whitespace are rejected" {
  @debug.assert_eq(
    @portfolio.describe_mix({ items: [], fixed_cost_fen: 0L, }),
    Err(@portfolio.EmptyMix),
  )
  let duplicate : @portfolio.MixPlan = {
    items: [item("a", 10L, 0L, 1L), item("a", 20L, 0L, 1L)],
    fixed_cost_fen: 0L,
  }
  @debug.assert_eq(
    @portfolio.describe_mix(duplicate),
    Err(@portfolio.DuplicateProductId("a")),
  )
  for id in ["", " ", " a", "a "] {
    @debug.assert_eq(
      @portfolio.describe_mix({
        items: [item(id, 10L, 0L, 1L)],
        fixed_cost_fen: 0L,
      }),
      Err(@portfolio.InvalidProductId(0)),
    )
  }
}

///|
test "money weight and shared fixed cost bounds have typed diagnostics" {
  for price in [-9223372036854775808L, 0L, 1000000001L] {
    @debug.assert_eq(
      @portfolio.describe_mix({
        items: [item("a", price, 0L, 1L)],
        fixed_cost_fen: 0L,
      }),
      Err(@portfolio.PriceOutOfRange("a")),
    )
  }
  for cost in [-1L, 9223372036854775807L] {
    @debug.assert_eq(
      @portfolio.describe_mix({
        items: [item("a", 10L, cost, 1L)],
        fixed_cost_fen: 0L,
      }),
      Err(@portfolio.VariableCostOutOfRange("a")),
    )
  }
  for weight in [-1L, 0L, 1000000001L] {
    @debug.assert_eq(
      @portfolio.describe_mix({
        items: [item("a", 10L, 0L, weight)],
        fixed_cost_fen: 0L,
      }),
      Err(@portfolio.WeightOutOfRange("a")),
    )
  }
  for fixed in [-1L, 1000000001L] {
    @debug.assert_eq(
      @portfolio.describe_mix({ ..shop(), fixed_cost_fen: fixed, }),
      Err(@portfolio.FixedCostOutOfRange),
    )
  }
}

///|
test "planned bundle and target inputs reject invalid or oversized values" {
  for quantity in [-1L, 1000000001L] {
    @debug.assert_eq(
      @portfolio.evaluate_mix(shop(), quantity),
      Err(@portfolio.PlannedBundlesOutOfRange),
    )
  }
  for target in [-1L, 1000000001L] {
    @debug.assert_eq(
      @portfolio.mix_target(shop(), target),
      Err(@portfolio.TargetProfitOutOfRange),
    )
  }
}

///|
test "raw maximum weights are normalized before any money multiplication" {
  let plan : @portfolio.MixPlan = {
    items: [item("a", 1000000000L, 0L, 1000000000L)],
    fixed_cost_fen: 1000000000L,
  }
  let result = must(@portfolio.evaluate_mix(plan, 1000000000L))
  @debug.assert_eq(result.profile.items[0].weight, 1L)
  @debug.assert_eq(result.revenue_fen, 1000000000000000000L)
  @debug.assert_eq(result.operating_profit_fen, 999999999000000000L)
}

///|
test "aggregation overflow is rejected for revenue and variable cost" {
  let rows : Array[@portfolio.MixItem] = []
  for index in 0..<10 {
    rows.push(
      item(
        "p\{index}",
        1000000000L,
        0L,
        if index == 9 {
          999999999L
        } else {
          1000000000L
        },
      ),
    )
  }
  @debug.assert_eq(
    @portfolio.describe_mix({ items: rows, fixed_cost_fen: 0L, }),
    Err(@portfolio.Overflow("bundle revenue total")),
  )
  let cost_rows = rows.map(fn(row) {
    {
      ..row,
      product: {
        ..row.product,
        selling_price_fen: 1L,
        variable_cost_fen: 1000000000L,
      },
    }
  })
  @debug.assert_eq(
    @portfolio.describe_mix({ items: cost_rows, fixed_cost_fen: 0L, }),
    Err(@portfolio.Overflow("bundle cost total")),
  )
}

///|
test "planned multiplication overflow never wraps into a plausible profit" {
  let plan : @portfolio.MixPlan = {
    items: [item("a", 1000000000L, 0L, 1000000000L), item("b", 1L, 0L, 1L)],
    fixed_cost_fen: 1L,
  }
  @debug.assert_eq(
    @portfolio.evaluate_mix(plan, 10L),
    Err(@portfolio.Overflow("planned revenue")),
  )
}

///|
test "target revenue overflow is returned even with a small target amount" {
  let plan : @portfolio.MixPlan = {
    items: [
      item("a", 1000000000L, 999999999L, 1000000000L),
      item("b", 1L, 1000000000L, 1L),
    ],
    fixed_cost_fen: 1000000000L,
  }
  @debug.assert_eq(
    must(@portfolio.describe_mix(plan)).bundle_contribution_fen,
    1L,
  )
  @debug.assert_eq(
    @portfolio.mix_target(plan, 1L),
    Err(@portfolio.Overflow("planned revenue")),
  )
}

///|
test "changed mix compares money and retains both product quantity definitions" {
  let changed : @portfolio.MixPlan = {
    ..shop(),
    items: [item("meal", 8000L, 4800L, 1L), item("drink", 5000L, 3000L, 2L)],
  }
  let result = must(@portfolio.compare_mixes(shop(), 250L, changed, 250L))
  @debug.assert_eq(result.revenue_delta_fen, -750000L)
  @debug.assert_eq(result.variable_cost_delta_fen, -450000L)
  @debug.assert_eq(result.fixed_cost_delta_fen, 0L)
  @debug.assert_eq(result.contribution_delta_fen, -300000L)
  @debug.assert_eq(result.operating_profit_delta_fen, -300000L)
  @debug.assert_eq(result.baseline.products[0].units, 500L)
  @debug.assert_eq(result.alternative.products[0].units, 250L)
  let rent : @portfolio.MixPlan = { ..shop(), fixed_cost_fen: 1800000L, }
  @debug.assert_eq(
    must(@portfolio.compare_mixes(shop(), 250L, rent, 250L)).operating_profit_delta_fen,
    -200000L,
  )
}

///|
test "single product portfolio agrees with existing CVP API" {
  let case_ : @domain.CvpCase = {
    selling_price_fen: 8000L,
    variable_cost_fen: 4800L,
    fixed_cost_fen: 1600000L,
  }
  let plan : @portfolio.MixPlan = {
    items: [item("only", 8000L, 4800L, 9L)],
    fixed_cost_fen: 1600000L,
  }
  @debug.assert_eq(
    Some(must(@portfolio.mix_break_even(plan)).required.planned_bundles),
    @engine.break_even_units(case_),
  )
  let target = must(@portfolio.mix_target(plan, 800000L))
  @debug.assert_eq(
    Some(target.required.planned_bundles),
    @engine.units_for_target_profit(case_, 800000L),
  )
  @debug.assert_eq(
    Some(target.required.revenue_fen),
    @engine.revenue_for_target_profit(case_, 800000L),
  )
  @debug.assert_eq(
    Some(must(@portfolio.evaluate_mix(plan, 700L)).operating_profit_fen),
    @engine.operating_profit_fen(case_, 700L),
  )
}

///|
test "exact division adds no unnecessary bundle" {
  let plan : @portfolio.MixPlan = {
    items: [item("a", 10L, 4L, 1L), item("b", 8L, 4L, 1L)],
    fixed_cost_fen: 100L,
  }
  let target = must(@portfolio.mix_target(plan, 20L))
  @debug.assert_eq(target.required.planned_bundles, 12L)
  @debug.assert_eq(target.rounding_surplus_fen, 0L)
}

///|
test "validation does not mutate caller ratios or hide an invalid alternative" {
  let plan = shop()
  let _ = must(@portfolio.describe_mix(plan))
  @debug.assert_eq(plan.items[0].weight, 2L)
  @debug.assert_eq(
    @portfolio.compare_mixes(plan, 1L, { ..plan, items: [], }, 1L),
    Err(@portfolio.EmptyMix),
  )
}

///|
test "target-derived quantity can exceed planned input limit without wrapping" {
  let plan : @portfolio.MixPlan = {
    items: [item("only", 2L, 1L, 1L)],
    fixed_cost_fen: 1000000000L,
  }
  let target = must(@portfolio.mix_target(plan, 1000000000L))
  @debug.assert_eq(target.required.planned_bundles, 2000000000L)
  @debug.assert_eq(target.required.revenue_fen, 4000000000L)
  @debug.assert_eq(target.required.operating_profit_fen, 1000000000L)
  @debug.assert_eq(
    @portfolio.evaluate_mix(plan, 2000000000L),
    Err(@portfolio.PlannedBundlesOutOfRange),
  )
}

///|
test "target minimality and ratio invariance across a grid including loss leaders" {
  for fixed in [0L, 1L, 159L, 160L, 161L, 1000L] {
    for target in [0L, 1L, 159L, 160L, 161L, 2000L] {
      let plan : @portfolio.MixPlan = {
        items: [item("main", 100L, 40L, 3L), item("leader", 70L, 80L, 2L)],
        fixed_cost_fen: fixed,
      }
      let result = must(@portfolio.mix_target(plan, target))
      assert_true(result.required.operating_profit_fen >= target)
      assert_true(
        result.rounding_surplus_fen >= 0L && result.rounding_surplus_fen < 160L,
      )
      if result.required.planned_bundles > 0 {
        assert_true(
          must(
            @portfolio.evaluate_mix(plan, result.required.planned_bundles - 1L),
          ).operating_profit_fen <
          target,
        )
      }
      let scaled : @portfolio.MixPlan = {
        ..plan,
        items: [item("main", 100L, 40L, 21L), item("leader", 70L, 80L, 14L)],
      }
      @debug.assert_eq(@portfolio.mix_target(scaled, target), Ok(result))
    }
  }
}
