///|
fn row(
  id : String,
  price : Int64,
  cost : Int64,
  units : Int64,
) -> @planning.SalesLine {
  {
    product: { id, selling_price_fen: price, variable_cost_fen: cost, },
    units,
  }
}

///|
fn period(
  id : String,
  products : Array[@planning.SalesLine],
  fixed : Int64,
  target : Int64,
) -> @planning.PeriodPlan {
  { id, products, fixed_cost_fen: fixed, target_profit_fen: target, }
}

///|
fn[T] must(result : Result[T, @planning.PlanError]) -> T {
  match result {
    Ok(value) => value
    Err(error) => abort(@debug.to_string(error))
  }
}

///|
test "period detail reconciles revenue variable cost profit and signed target gap" {
  let result = must(
    @planning.evaluate_period(
      period(
        "Oct",
        [row("meal", 8000L, 4800L, 500L), row("drink", 5000L, 3000L, 250L)],
        1600000L,
        400000L,
      ),
    ),
  )
  @debug.assert_eq(result.revenue_fen, 5250000L)
  @debug.assert_eq(result.variable_cost_fen, 3150000L)
  @debug.assert_eq(result.contribution_fen, 2100000L)
  @debug.assert_eq(result.operating_profit_fen, 500000L)
  @debug.assert_eq(result.target_gap_fen, -100000L)
  @debug.assert_eq(
    result.products[0].contribution_fen + result.products[1].contribution_fen,
    result.contribution_fen,
  )
}

///|
test "zero price zero volume and negative contribution are valid observations" {
  let loss = must(
    @planning.evaluate_period(
      period(
        "loss",
        [row("giveaway", 0L, 100L, 5L), row("closed", 800L, 100L, 0L)],
        200L,
        1000L,
      ),
    ),
  )
  @debug.assert_eq(loss.revenue_fen, 0L)
  @debug.assert_eq(loss.variable_cost_fen, 500L)
  @debug.assert_eq(loss.contribution_fen, -500L)
  @debug.assert_eq(loss.operating_profit_fen, -700L)
  @debug.assert_eq(loss.target_gap_fen, 1700L)
  let closed = must(
    @planning.evaluate_period(
      period("closed", [row("a", 0L, 0L, 0L)], 100L, 0L),
    ),
  )
  @debug.assert_eq(closed.operating_profit_fen, -100L)
}

///|
test "cumulative amounts follow explicit input order and reconcile each prefix" {
  let first = period("2026-10", [row("old", 100L, 40L, 10L)], 100L, 400L)
  let second = period("2026-11", [row("new", 200L, 120L, 5L)], 200L, 400L)
  let result = must(@planning.evaluate_plan([first, second]))
  @debug.assert_eq(result.periods[0], must(@planning.evaluate_period(first)))
  @debug.assert_eq(result.periods[1], must(@planning.evaluate_period(second)))
  @debug.assert_eq(result.cumulative[0].id, "2026-10")
  @debug.assert_eq(result.cumulative[0].totals.operating_profit_fen, 500L)
  @debug.assert_eq(result.cumulative[0].totals.target_gap_fen, -100L)
  @debug.assert_eq(result.cumulative[1].totals, result.totals)
  @debug.assert_eq(result.totals.revenue_fen, 2000L)
  @debug.assert_eq(result.totals.variable_cost_fen, 1000L)
  @debug.assert_eq(result.totals.fixed_cost_fen, 300L)
  @debug.assert_eq(result.totals.contribution_fen, 1000L)
  @debug.assert_eq(result.totals.operating_profit_fen, 700L)
  @debug.assert_eq(result.totals.target_profit_fen, 800L)
  @debug.assert_eq(result.totals.target_gap_fen, 100L)
}

///|
test "all four drivers have explicit signs and reconcile actual minus budget" {
  let budget = period("Oct", [row("a", 100L, 40L, 10L)], 100L, 0L)
  let actual = period("Oct", [row("a", 110L, 45L, 12L)], 130L, 0L)
  let result = must(@planning.compare_plans([budget], [actual]))
  @debug.assert_eq(result.volume_effect_fen, 120L)
  @debug.assert_eq(result.price_effect_fen, 120L)
  @debug.assert_eq(result.variable_cost_effect_fen, -60L)
  @debug.assert_eq(result.fixed_cost_effect_fen, -30L)
  @debug.assert_eq(result.profit_delta_fen, 150L)
  @debug.assert_eq(result.periods[0].products[0].profit_delta_fen, 180L)
  @debug.assert_eq(
    result.profit_delta_fen,
    result.actual.totals.operating_profit_fen -
    result.budget.totals.operating_profit_fen,
  )
}

///|
test "period and product permutations align by ID and use budget chronology" {
  let b1 = period(
    "first",
    [row("a", 100L, 40L, 10L), row("b", 80L, 30L, 5L)],
    100L,
    0L,
  )
  let b2 = period("second", [row("c", 20L, 50L, 2L)], 20L, 0L)
  let a1 = period(
    "first",
    [row("a", 110L, 40L, 12L), row("b", 80L, 35L, 4L)],
    130L,
    0L,
  )
  let a2 = period("second", [row("c", 0L, 20L, 0L)], 0L, 0L)
  let reversed_products : @planning.PeriodPlan = {
    ..a1,
    products: [a1.products[1], a1.products[0]],
  }
  let ordered = must(@planning.compare_plans([b1, b2], [a1, a2]))
  let permuted = must(
    @planning.compare_plans([b1, b2], [a2, reversed_products]),
  )
  @debug.assert_eq(permuted.actual.cumulative, ordered.actual.cumulative)
  @debug.assert_eq(permuted.actual.periods[0].id, "first")
  @debug.assert_eq(permuted.periods[0].products, ordered.periods[0].products)
  @debug.assert_eq(permuted.profit_delta_fen, ordered.profit_delta_fen)
  @debug.assert_eq(permuted.volume_effect_fen, ordered.volume_effect_fen)
  @debug.assert_eq(permuted.periods[1].id, "second")
}

///|
test "bridge identity covers 216 changes including zero sales and loss periods" {
  for budget_quantity in [0L, 2L, 7L] {
    for actual_quantity in [0L, 1L, 9L] {
      for actual_price in [0L, 70L, 110L, 200L] {
        for actual_cost in [0L, 45L, 150L] {
          for fixed in [0L, 50L] {
            let budget = period(
              "p",
              [row("a", 100L, 40L, budget_quantity)],
              30L,
              0L,
            )
            let actual = period(
              "p",
              [row("a", actual_price, actual_cost, actual_quantity)],
              fixed,
              0L,
            )
            let result = must(@planning.compare_plans([budget], [actual]))
            @debug.assert_eq(
              result.volume_effect_fen +
              result.price_effect_fen +
              result.variable_cost_effect_fen +
              result.fixed_cost_effect_fen,
              result.profit_delta_fen,
            )
            @debug.assert_eq(
              result.profit_delta_fen,
              result.actual.totals.operating_profit_fen -
              result.budget.totals.operating_profit_fen,
            )
          }
        }
      }
    }
  }
}

///|
test "unchanged plan has a zero bridge and does not mutate caller arrays" {
  let plan = [period("p", [row("a", 100L, 40L, 10L)], 10L, 10L)]
  let result = must(@planning.compare_plans(plan, plan))
  @debug.assert_eq(result.volume_effect_fen, 0L)
  @debug.assert_eq(result.price_effect_fen, 0L)
  @debug.assert_eq(result.variable_cost_effect_fen, 0L)
  @debug.assert_eq(result.fixed_cost_effect_fen, 0L)
  @debug.assert_eq(result.profit_delta_fen, 0L)
  @debug.assert_eq(plan[0].products[0].units, 10L)
}

///|
test "empty duplicate and whitespace period IDs produce typed errors" {
  @debug.assert_eq(@planning.evaluate_plan([]), Err(@planning.EmptyPlan))
  let good = period("p", [row("a", 1L, 0L, 0L)], 0L, 0L)
  @debug.assert_eq(
    @planning.evaluate_plan([good, good]),
    Err(@planning.DuplicatePeriodId("p")),
  )
  for id in ["", " ", " p", "p "] {
    @debug.assert_eq(
      @planning.evaluate_plan([good, { ..good, id, }]),
      Err(@planning.InvalidPeriodId(1)),
    )
  }
  @debug.assert_eq(
    @planning.evaluate_period({ ..good, products: [], }),
    Err(@planning.EmptyProducts("p")),
  )
}

///|
test "product IDs are unique nonblank and already trimmed" {
  let good = period("p", [row("a", 1L, 0L, 0L)], 0L, 0L)
  @debug.assert_eq(
    @planning.evaluate_period({
      ..good,
      products: [good.products[0], good.products[0]],
    }),
    Err(@planning.DuplicateProductId("p", "a")),
  )
  for id in ["", "\t", " a", "a "] {
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, products: [row(id, 1L, 0L, 0L)], }),
      Err(@planning.InvalidProductId("p", 0)),
    )
  }
}

///|
test "all input amounts and quantities enforce nonnegative billion bounds" {
  let good = period("p", [row("a", 1L, 0L, 0L)], 0L, 0L)
  for value in [-9223372036854775808L, -1L, 1000000001L, 9223372036854775807L] {
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, products: [row("a", value, 0L, 0L)], }),
      Err(@planning.PriceOutOfRange("p", "a")),
    )
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, products: [row("a", 1L, value, 0L)], }),
      Err(@planning.VariableCostOutOfRange("p", "a")),
    )
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, products: [row("a", 1L, 0L, value)], }),
      Err(@planning.UnitsOutOfRange("p", "a")),
    )
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, fixed_cost_fen: value, }),
      Err(@planning.FixedCostOutOfRange("p")),
    )
    @debug.assert_eq(
      @planning.evaluate_period({ ..good, target_profit_fen: value, }),
      Err(@planning.TargetProfitOutOfRange("p")),
    )
  }
  let upper = must(
    @planning.evaluate_period(
      period(
        "max",
        [row("a", 1000000000L, 1000000000L, 1000000000L)],
        1000000000L,
        1000000000L,
      ),
    ),
  )
  @debug.assert_eq(upper.revenue_fen, 1000000000000000000L)
  @debug.assert_eq(upper.target_gap_fen, 2000000000L)
}

///|
test "missing and unexpected period IDs cannot silently pair by position" {
  let p = period("p", [row("a", 1L, 0L, 0L)], 0L, 0L)
  let q : @planning.PeriodPlan = { ..p, id: "q", }
  @debug.assert_eq(
    @planning.compare_plans([p, q], [p]),
    Err(@planning.MissingPeriod("q")),
  )
  @debug.assert_eq(
    @planning.compare_plans([p], [p, q]),
    Err(@planning.UnexpectedPeriod("q")),
  )
  @debug.assert_eq(
    @planning.compare_plans([p], [q]),
    Err(@planning.MissingPeriod("p")),
  )
  @debug.assert_eq(
    @planning.compare_plans([p], [p, p]),
    Err(@planning.DuplicatePeriodId("p")),
  )
}

///|
test "missing unexpected and duplicate products fail instead of supplying defaults" {
  let p = period("p", [row("a", 1L, 0L, 0L)], 0L, 0L)
  let both : @planning.PeriodPlan = {
    ..p,
    products: [row("a", 1L, 0L, 0L), row("b", 1L, 0L, 0L)],
  }
  @debug.assert_eq(
    @planning.compare_plans([both], [p]),
    Err(@planning.MissingProduct("p", "b")),
  )
  @debug.assert_eq(
    @planning.compare_plans([p], [both]),
    Err(@planning.UnexpectedProduct("p", "b")),
  )
  @debug.assert_eq(
    @planning.compare_plans([p], [
      { ..p, products: [p.products[0], p.products[0]], },
    ]),
    Err(@planning.DuplicateProductId("p", "a")),
  )
}

///|
test "period revenue and cost aggregation overflow is returned before wrap" {
  let revenue : Array[@planning.SalesLine] = []
  let cost : Array[@planning.SalesLine] = []
  for i in 0..<10 {
    revenue.push(row("p\{i}", 1000000000L, 0L, 1000000000L))
    cost.push(row("p\{i}", 0L, 1000000000L, 1000000000L))
  }
  @debug.assert_eq(
    @planning.evaluate_period(period("p", revenue, 0L, 0L)),
    Err(@planning.Overflow("period revenue: p")),
  )
  @debug.assert_eq(
    @planning.evaluate_period(period("p", cost, 0L, 0L)),
    Err(@planning.Overflow("period variable cost: p")),
  )
}

///|
test "cumulative revenue and cost overflow do not produce partial totals" {
  let revenue : Array[@planning.PeriodPlan] = []
  let cost : Array[@planning.PeriodPlan] = []
  for i in 0..<10 {
    revenue.push(
      period("p\{i}", [row("a", 1000000000L, 0L, 1000000000L)], 0L, 0L),
    )
    cost.push(period("p\{i}", [row("a", 0L, 1000000000L, 1000000000L)], 0L, 0L))
  }
  @debug.assert_eq(
    @planning.evaluate_plan(revenue),
    Err(@planning.Overflow("cumulative revenue: p9")),
  )
  @debug.assert_eq(
    @planning.evaluate_plan(cost),
    Err(@planning.Overflow("cumulative variable cost: p9")),
  )
}

///|
test "negative profit and positive target gap are checked near Int64 boundary" {
  let cost : Array[@planning.SalesLine] = []
  for i in 0..<9 {
    cost.push(row("p\{i}", 0L, 1000000000L, 1000000000L))
  }
  cost.push(row("tail", 0L, 223372036L, 1000000000L))
  @debug.assert_eq(
    @planning.evaluate_period(period("p", cost, 1000000000L, 0L)),
    Err(@planning.Overflow("period profit: p")),
  )
  @debug.assert_eq(
    @planning.evaluate_period(period("p", cost, 0L, 1000000000L)),
    Err(@planning.Overflow("period target gap: p")),
  )
}

///|
test "signed profit delta is checked even when both period profits fit" {
  let budget : Array[@planning.SalesLine] = []
  let actual : Array[@planning.SalesLine] = []
  for i in 0..<9 {
    budget.push(row("p\{i}", 1000000000L, 0L, 1000000000L))
    actual.push(row("p\{i}", 0L, 1000000000L, 1000000000L))
  }
  @debug.assert_eq(
    @planning.compare_plans([period("p", budget, 0L, 0L)], [
      period("p", actual, 0L, 0L),
    ]),
    Err(@planning.Overflow("period profit change: p")),
  )
}

///|
test "bridge bucket overflow is rejected even when budget actual profits are zero" {
  let budget : Array[@planning.SalesLine] = []
  let actual : Array[@planning.SalesLine] = []
  for i in 0..<10 {
    budget.push(row("p\{i}", 1000000000L, 0L, 0L))
    actual.push(row("p\{i}", 0L, 0L, 1000000000L))
  }
  @debug.assert_eq(
    @planning.compare_plans([period("p", budget, 0L, 0L)], [
      period("p", actual, 0L, 0L),
    ]),
    Err(@planning.Overflow("period volume effect: p")),
  )
}
