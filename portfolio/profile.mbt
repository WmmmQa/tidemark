///|
/// Validate raw inputs before arithmetic and normalize equivalent ratios.
/// The first error is returned deterministically in input order.
pub fn describe_mix(plan : MixPlan) -> Result[MixProfile, MixError] {
  if plan.items.is_empty() {
    return Err(EmptyMix)
  }
  if plan.fixed_cost_fen < 0 || plan.fixed_cost_fen > MAX_INPUT_AMOUNT_FEN {
    return Err(FixedCostOutOfRange)
  }
  let seen : Map[String, Bool] = Map([])
  let mut divisor = 0L
  for index, item in plan.items {
    let product = item.product
    if product.id.trim().is_empty() ||
      product.id != product.id.trim().to_owned() {
      return Err(InvalidProductId(index))
    }
    if seen.contains(product.id) {
      return Err(DuplicateProductId(product.id))
    }
    seen[product.id] = true
    if product.selling_price_fen <= 0 ||
      product.selling_price_fen > MAX_INPUT_AMOUNT_FEN {
      return Err(PriceOutOfRange(product.id))
    }
    if product.variable_cost_fen < 0 ||
      product.variable_cost_fen > MAX_INPUT_AMOUNT_FEN {
      return Err(VariableCostOutOfRange(product.id))
    }
    if item.weight <= 0 || item.weight > MAX_INPUT_QUANTITY {
      return Err(WeightOutOfRange(product.id))
    }
    divisor = gcd(divisor, item.weight)
  }
  let normalized : Array[MixItem] = []
  let mut revenue = 0L
  let mut variable_cost = 0L
  for item in plan.items {
    let weight = item.weight / divisor
    let product = item.product
    let line_revenue = match
      checked_product(
        product.selling_price_fen,
        weight,
        "bundle revenue: " + product.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let line_cost = match
      checked_product(
        product.variable_cost_fen,
        weight,
        "bundle variable cost: " + product.id,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    revenue = match checked_add(revenue, line_revenue, "bundle revenue total") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variable_cost = match
      checked_add(variable_cost, line_cost, "bundle cost total") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    normalized.push({ product, weight, })
  }
  // Both totals are nonnegative Int64, so this difference is representable.
  let contribution = revenue - variable_cost
  if contribution <= 0 {
    return Err(NonPositiveMixContribution)
  }
  Ok({
    items: normalized,
    fixed_cost_fen: plan.fixed_cost_fen,
    bundle_revenue_fen: revenue,
    bundle_variable_cost_fen: variable_cost,
    bundle_contribution_fen: contribution,
  })
}
