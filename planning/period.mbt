///|
/// Evaluate recorded or planned sales without imposing a positive-contribution
/// assumption. A loss-making period is valid; each amount/quantity input is
/// 0..1,000,000,000 and every derived operation must fit signed Int64.
pub fn evaluate_period(plan : PeriodPlan) -> Result[PeriodResult, PlanError] {
  if !valid_id(plan.id) {
    return Err(InvalidPeriodId(0))
  }
  if plan.products.is_empty() {
    return Err(EmptyProducts(plan.id))
  }
  if !valid_amount(plan.fixed_cost_fen) {
    return Err(FixedCostOutOfRange(plan.id))
  }
  if !valid_amount(plan.target_profit_fen) {
    return Err(TargetProfitOutOfRange(plan.id))
  }
  let seen : Map[String, Bool] = Map([])
  let products : Array[@portfolio.ProductSales] = []
  let mut revenue = 0L
  let mut variable_cost = 0L
  for index, line in plan.products {
    let product = line.product
    if !valid_id(product.id) {
      return Err(InvalidProductId(plan.id, index))
    }
    if seen.contains(product.id) {
      return Err(DuplicateProductId(plan.id, product.id))
    }
    seen[product.id] = true
    if !valid_amount(product.selling_price_fen) {
      return Err(PriceOutOfRange(plan.id, product.id))
    }
    if !valid_amount(product.variable_cost_fen) {
      return Err(VariableCostOutOfRange(plan.id, product.id))
    }
    if line.units < 0 || line.units > @portfolio.MAX_INPUT_QUANTITY {
      return Err(UnitsOutOfRange(plan.id, product.id))
    }
    let context = plan.id + "/" + product.id
    let line_revenue = match
      checked_mul(product.selling_price_fen, line.units, "revenue: " + context) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let line_cost = match
      checked_mul(
        product.variable_cost_fen,
        line.units,
        "variable cost: " + context,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    revenue = match
      checked_add(revenue, line_revenue, "period revenue: " + plan.id) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variable_cost = match
      checked_add(variable_cost, line_cost, "period variable cost: " + plan.id) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let contribution = match
      checked_sub(line_revenue, line_cost, "product contribution: " + context) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    products.push({
      product,
      units: line.units,
      revenue_fen: line_revenue,
      variable_cost_fen: line_cost,
      contribution_fen: contribution,
    })
  }
  let contribution = match
    checked_sub(revenue, variable_cost, "period contribution: " + plan.id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let profit = match
    checked_sub(contribution, plan.fixed_cost_fen, "period profit: " + plan.id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let gap = match
    checked_sub(plan.target_profit_fen, profit, "period target gap: " + plan.id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    id: plan.id,
    products,
    fixed_cost_fen: plan.fixed_cost_fen,
    target_profit_fen: plan.target_profit_fen,
    revenue_fen: revenue,
    variable_cost_fen: variable_cost,
    contribution_fen: contribution,
    operating_profit_fen: profit,
    target_gap_fen: gap,
  })
}

///|
fn period_totals(period : PeriodResult) -> PlanTotals {
  {
    fixed_cost_fen: period.fixed_cost_fen,
    target_profit_fen: period.target_profit_fen,
    revenue_fen: period.revenue_fen,
    variable_cost_fen: period.variable_cost_fen,
    contribution_fen: period.contribution_fen,
    operating_profit_fen: period.operating_profit_fen,
    target_gap_fen: period.target_gap_fen,
  }
}

///|
fn zero_totals() -> PlanTotals {
  {
    fixed_cost_fen: 0L,
    target_profit_fen: 0L,
    revenue_fen: 0L,
    variable_cost_fen: 0L,
    contribution_fen: 0L,
    operating_profit_fen: 0L,
    target_gap_fen: 0L,
  }
}

///|
/// Add every field explicitly, including the signed profit and gap. Even when
/// some fields cancel, unrepresentable intermediate totals return an error.
fn add_totals(
  a : PlanTotals,
  b : PlanTotals,
  id : String,
) -> Result[PlanTotals, PlanError] {
  let fixed = match
    checked_add(
      a.fixed_cost_fen,
      b.fixed_cost_fen,
      "cumulative fixed cost: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let target = match
    checked_add(
      a.target_profit_fen,
      b.target_profit_fen,
      "cumulative target: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let revenue = match
    checked_add(a.revenue_fen, b.revenue_fen, "cumulative revenue: " + id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let variable_cost = match
    checked_add(
      a.variable_cost_fen,
      b.variable_cost_fen,
      "cumulative variable cost: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contribution = match
    checked_add(
      a.contribution_fen,
      b.contribution_fen,
      "cumulative contribution: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let profit = match
    checked_add(
      a.operating_profit_fen,
      b.operating_profit_fen,
      "cumulative profit: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let gap = match
    checked_add(
      a.target_gap_fen,
      b.target_gap_fen,
      "cumulative target gap: " + id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    fixed_cost_fen: fixed,
    target_profit_fen: target,
    revenue_fen: revenue,
    variable_cost_fen: variable_cost,
    contribution_fen: contribution,
    operating_profit_fen: profit,
    target_gap_fen: gap,
  })
}

///|
/// Evaluate all periods and cumulative amounts in caller-supplied order.
/// Products may change between periods; comparison requires matching ID sets
/// within each budget/actual pair instead of inventing missing observations.
pub fn evaluate_plan(
  plans : Array[PeriodPlan],
) -> Result[PlanResult, PlanError] {
  if plans.is_empty() {
    return Err(EmptyPlan)
  }
  let seen : Map[String, Bool] = Map([])
  let periods : Array[PeriodResult] = []
  let cumulative : Array[PeriodCumulative] = []
  let mut totals = zero_totals()
  for index, plan in plans {
    if !valid_id(plan.id) {
      return Err(InvalidPeriodId(index))
    }
    if seen.contains(plan.id) {
      return Err(DuplicatePeriodId(plan.id))
    }
    seen[plan.id] = true
    let period = match evaluate_period(plan) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    totals = match add_totals(totals, period_totals(period), plan.id) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    periods.push(period)
    cumulative.push({ id: plan.id, totals, })
  }
  Ok({ periods, cumulative, totals, })
}
