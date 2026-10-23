///|
/// Evaluate a whole number of normalized bundles, with per-product detail.
/// Zero sales are allowed and produce a loss equal to shared fixed cost.
pub fn evaluate_mix(
  plan : MixPlan,
  planned_bundles : Int64,
) -> Result[MixEvaluation, MixError] {
  if planned_bundles < 0 || planned_bundles > MAX_INPUT_QUANTITY {
    return Err(PlannedBundlesOutOfRange)
  }
  match describe_mix(plan) {
    Ok(profile) => evaluate_profile(profile, planned_bundles)
    Err(error) => Err(error)
  }
}

///|
fn evaluate_profile(
  profile : MixProfile,
  bundles : Int64,
) -> Result[MixEvaluation, MixError] {
  let revenue = match
    checked_product(profile.bundle_revenue_fen, bundles, "planned revenue") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let variable_cost = match
    checked_product(
      profile.bundle_variable_cost_fen,
      bundles,
      "planned variable cost",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contribution = revenue - variable_cost
  let profit = match
    checked_sub(contribution, profile.fixed_cost_fen, "operating profit") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let products : Array[ProductSales] = []
  for item in profile.items {
    let units = match
      checked_product(item.weight, bundles, "product quantity") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let line_revenue = match
      checked_product(
        units,
        item.product.selling_price_fen,
        "product revenue: " + item.product.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let line_cost = match
      checked_product(
        units,
        item.product.variable_cost_fen,
        "product cost: " + item.product.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    products.push({
      product: item.product,
      units,
      revenue_fen: line_revenue,
      variable_cost_fen: line_cost,
      contribution_fen: line_revenue - line_cost,
    })
  }
  Ok({
    profile,
    planned_bundles: bundles,
    products,
    revenue_fen: revenue,
    variable_cost_fen: variable_cost,
    contribution_fen: contribution,
    operating_profit_fen: profit,
  })
}

///|
/// Smallest number of complete normalized bundles covering shared fixed costs.
pub fn mix_break_even(plan : MixPlan) -> Result[MixTarget, MixError] {
  mix_target(plan, 0L)
}

///|
/// Whole-bundle target plan. Required quantities can exceed planned-input limits;
/// unrepresentable revenue, cost or quantity returns Overflow rather than wrapping.
pub fn mix_target(
  plan : MixPlan,
  target_profit_fen : Int64,
) -> Result[MixTarget, MixError] {
  if target_profit_fen < 0 || target_profit_fen > MAX_INPUT_AMOUNT_FEN {
    return Err(TargetProfitOutOfRange)
  }
  let profile = match describe_mix(plan) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let required_contribution = match
    checked_add(
      profile.fixed_cost_fen,
      target_profit_fen,
      "target contribution",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bundles = ceil_div(required_contribution, profile.bundle_contribution_fen)
  let required = match evaluate_profile(profile, bundles) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let surplus = match
    checked_sub(
      required.operating_profit_fen,
      target_profit_fen,
      "rounding surplus",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ target_profit_fen, required, rounding_surplus_fen: surplus, })
}
