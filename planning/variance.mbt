///|
fn compare_product(
  budget : @portfolio.ProductSales,
  actual : @portfolio.ProductSales,
  id : String,
) -> Result[ProductVariance, PlanError] {
  let context = id + "/" + budget.product.id
  let units_delta = match
    checked_sub(actual.units, budget.units, "volume change: " + context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let unit_contribution = match
    checked_sub(
      budget.product.selling_price_fen,
      budget.product.variable_cost_fen,
      "budget unit contribution: " + context,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let volume = match
    checked_mul(units_delta, unit_contribution, "volume effect: " + context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let price_delta = match
    checked_sub(
      actual.product.selling_price_fen,
      budget.product.selling_price_fen,
      "price change: " + context,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let price = match
    checked_mul(price_delta, actual.units, "price effect: " + context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let cost_reduction = match
    checked_sub(
      budget.product.variable_cost_fen,
      actual.product.variable_cost_fen,
      "unit cost reduction: " + context,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let variable_cost = match
    checked_mul(
      cost_reduction,
      actual.units,
      "variable cost effect: " + context,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let profit_delta = match
    checked_sub(
      actual.contribution_fen,
      budget.contribution_fen,
      "product profit change: " + context,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let partial = match
    checked_add(volume, price, "product bridge subtotal: " + context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bridge = match
    checked_add(partial, variable_cost, "product bridge total: " + context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if bridge != profit_delta {
    return Err(ReconciliationFailed(context))
  }
  Ok({
    product_id: budget.product.id,
    volume_effect_fen: volume,
    price_effect_fen: price,
    variable_cost_effect_fen: variable_cost,
    profit_delta_fen: profit_delta,
  })
}

///|
fn compare_period(
  budget : PeriodResult,
  actual : PeriodResult,
) -> Result[PeriodVariance, PlanError] {
  let actual_products : Map[String, @portfolio.ProductSales] = Map([])
  let budget_ids : Map[String, Bool] = Map([])
  for product in actual.products {
    actual_products[product.product.id] = product
  }
  for product in budget.products {
    budget_ids[product.product.id] = true
    if !actual_products.contains(product.product.id) {
      return Err(MissingProduct(budget.id, product.product.id))
    }
  }
  for product in actual.products {
    if !budget_ids.contains(product.product.id) {
      return Err(UnexpectedProduct(budget.id, product.product.id))
    }
  }
  let products : Array[ProductVariance] = []
  let mut volume = 0L
  let mut price = 0L
  let mut variable_cost = 0L
  for product in budget.products {
    let counterpart = match actual_products.get(product.product.id) {
      Some(value) => value
      None => return Err(MissingProduct(budget.id, product.product.id))
    }
    let variance = match compare_product(product, counterpart, budget.id) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    volume = match
      checked_add(
        volume,
        variance.volume_effect_fen,
        "period volume effect: " + budget.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    price = match
      checked_add(
        price,
        variance.price_effect_fen,
        "period price effect: " + budget.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variable_cost = match
      checked_add(
        variable_cost,
        variance.variable_cost_effect_fen,
        "period variable cost effect: " + budget.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    products.push(variance)
  }
  let fixed = match
    checked_sub(
      budget.fixed_cost_fen,
      actual.fixed_cost_fen,
      "fixed cost effect: " + budget.id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delta = match
    checked_sub(
      actual.operating_profit_fen,
      budget.operating_profit_fen,
      "period profit change: " + budget.id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bridge = match
    sum_bridge(
      volume,
      price,
      variable_cost,
      fixed,
      "period bridge: " + budget.id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if bridge != delta {
    return Err(ReconciliationFailed(budget.id))
  }
  Ok({
    id: budget.id,
    budget,
    actual,
    products,
    volume_effect_fen: volume,
    price_effect_fen: price,
    variable_cost_effect_fen: variable_cost,
    fixed_cost_effect_fen: fixed,
    profit_delta_fen: delta,
  })
}

///|
fn sum_bridge(
  volume : Int64,
  price : Int64,
  variable_cost : Int64,
  fixed : Int64,
  context : String,
) -> Result[Int64, PlanError] {
  let subtotal = match checked_add(volume, price, context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let subtotal = match checked_add(subtotal, variable_cost, context) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  checked_add(subtotal, fixed, context)
}

///|
/// Reconcile actual minus budget operating profit using exact ID alignment.
/// The bridge first replaces quantities at budget unit contribution, then
/// selling prices at actual quantities, then variable unit costs, then fixed
/// costs. Different replacement orders allocate interaction effects differently.
pub fn compare_plans(
  budget : Array[PeriodPlan],
  actual : Array[PeriodPlan],
) -> Result[PlanComparison, PlanError] {
  let budget = match evaluate_plan(budget) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if actual.is_empty() {
    return Err(EmptyPlan)
  }
  let actual_inputs : Map[String, PeriodPlan] = Map([])
  let budget_ids : Map[String, Bool] = Map([])
  for index, period in actual {
    if !valid_id(period.id) {
      return Err(InvalidPeriodId(index))
    }
    if actual_inputs.contains(period.id) {
      return Err(DuplicatePeriodId(period.id))
    }
    match evaluate_period(period) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    actual_inputs[period.id] = period
  }
  for period in budget.periods {
    budget_ids[period.id] = true
    if !actual_inputs.contains(period.id) {
      return Err(MissingPeriod(period.id))
    }
  }
  for period in actual {
    if !budget_ids.contains(period.id) {
      return Err(UnexpectedPeriod(period.id))
    }
  }
  // Budget order is the chronology for both sides of the comparison, including
  // their cumulative results. ID matching never relies on array positions.
  let ordered_actual : Array[PeriodPlan] = []
  for period in budget.periods {
    match actual_inputs.get(period.id) {
      Some(value) => ordered_actual.push(value)
      None => return Err(MissingPeriod(period.id))
    }
  }
  let actual = match evaluate_plan(ordered_actual) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let actual_periods : Map[String, PeriodResult] = Map([])
  for period in actual.periods {
    actual_periods[period.id] = period
  }
  let periods : Array[PeriodVariance] = []
  let mut volume = 0L
  let mut price = 0L
  let mut variable_cost = 0L
  let mut fixed = 0L
  for period in budget.periods {
    let counterpart = match actual_periods.get(period.id) {
      Some(value) => value
      None => return Err(MissingPeriod(period.id))
    }
    let variance = match compare_period(period, counterpart) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    volume = match
      checked_add(volume, variance.volume_effect_fen, "plan volume effect") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    price = match
      checked_add(price, variance.price_effect_fen, "plan price effect") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variable_cost = match
      checked_add(
        variable_cost,
        variance.variable_cost_effect_fen,
        "plan variable cost effect",
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    fixed = match
      checked_add(
        fixed,
        variance.fixed_cost_effect_fen,
        "plan fixed cost effect",
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    periods.push(variance)
  }
  let delta = match
    checked_sub(
      actual.totals.operating_profit_fen,
      budget.totals.operating_profit_fen,
      "plan profit change",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bridge = match
    sum_bridge(volume, price, variable_cost, fixed, "plan bridge") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if bridge != delta {
    return Err(ReconciliationFailed("plan"))
  }
  Ok({
    budget,
    actual,
    periods,
    volume_effect_fen: volume,
    price_effect_fen: price,
    variable_cost_effect_fen: variable_cost,
    fixed_cost_effect_fen: fixed,
    profit_delta_fen: delta,
  })
}
