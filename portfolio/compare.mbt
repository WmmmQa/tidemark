///|
/// Compare two complete plans, possibly with different products and sales mixes.
/// Financial differences are alternative minus baseline; fixed costs are shared
/// within each plan. Different bundle counts are not a common unit of volume.
pub fn compare_mixes(
  baseline : MixPlan,
  baseline_bundles : Int64,
  alternative : MixPlan,
  alternative_bundles : Int64,
) -> Result[MixComparison, MixError] {
  let baseline = match evaluate_mix(baseline, baseline_bundles) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let alternative = match evaluate_mix(alternative, alternative_bundles) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let revenue_delta = match
    checked_sub(alternative.revenue_fen, baseline.revenue_fen, "revenue change") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let variable_delta = match
    checked_sub(
      alternative.variable_cost_fen,
      baseline.variable_cost_fen,
      "variable cost change",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let fixed_delta = match
    checked_sub(
      alternative.profile.fixed_cost_fen,
      baseline.profile.fixed_cost_fen,
      "fixed cost change",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contribution_delta = match
    checked_sub(
      alternative.contribution_fen,
      baseline.contribution_fen,
      "contribution change",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let profit_delta = match
    checked_sub(
      alternative.operating_profit_fen,
      baseline.operating_profit_fen,
      "profit change",
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    baseline,
    alternative,
    revenue_delta_fen: revenue_delta,
    variable_cost_delta_fen: variable_delta,
    fixed_cost_delta_fen: fixed_delta,
    contribution_delta_fen: contribution_delta,
    operating_profit_delta_fen: profit_delta,
  })
}
