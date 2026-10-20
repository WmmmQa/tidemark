///|
/// Why a scenario cannot produce ordinary CVP metrics.
pub(all) enum ScenarioIssue {
  InvalidCase(@domain.CaseIssue)
  NegativePlannedUnits
  PlannedUnitsOutOfRange
}

///|
/// CVP indicators for one named operating scenario.
/// Metrics are absent when the scenario inputs are invalid.
pub(all) struct ScenarioResult {
  label : String
  break_even_units : Int64?
  operating_profit_fen : Int64?
  safety_margin_units : Int64?
  issues : Array[ScenarioIssue]
}

///|
/// Evaluate one named scenario and keep input issues beside the result.
pub fn evaluate_scenario(scenario : @domain.CvpScenario) -> ScenarioResult {
  let issues : Array[ScenarioIssue] = []
  for issue in scenario.case.issues() {
    issues.push(InvalidCase(issue))
  }
  if scenario.planned_units < 0 {
    issues.push(NegativePlannedUnits)
  }
  if scenario.planned_units > @domain.MAX_SUPPORTED_UNITS {
    issues.push(PlannedUnitsOutOfRange)
  }
  if issues.length() > 0 {
    return {
      label: scenario.label,
      break_even_units: None,
      operating_profit_fen: None,
      safety_margin_units: None,
      issues,
    }
  }
  {
    label: scenario.label,
    break_even_units: break_even_units(scenario.case),
    operating_profit_fen: operating_profit_fen(
      scenario.case,
      scenario.planned_units,
    ),
    safety_margin_units: safety_margin_units(
      scenario.case,
      scenario.planned_units,
    ),
    issues,
  }
}

///|
/// Evaluate a set of named scenarios independently, preserving invalid rows.
pub fn compare_scenarios(
  scenarios : Array[@domain.CvpScenario],
) -> Array[ScenarioResult] {
  let results : Array[ScenarioResult] = []
  for scenario in scenarios {
    results.push(evaluate_scenario(scenario))
  }
  results
}

///|
/// Baseline and alternative metrics, with signed changes where both are valid.
pub(all) struct SensitivityResult {
  baseline : ScenarioResult
  changed : ScenarioResult
  operating_profit_delta_fen : Int64?
  break_even_delta_units : Int64?
  safety_margin_delta_units : Int64?
}

///|
/// Compare each alternative with one baseline.
/// Use one changed input driver per alternative to make each effect interpretable.
pub fn sensitivity_analysis(
  baseline : @domain.CvpScenario,
  alternatives : Array[@domain.CvpScenario],
) -> Array[SensitivityResult] {
  let base_result = evaluate_scenario(baseline)
  let results : Array[SensitivityResult] = []
  for alternative in alternatives {
    let changed = evaluate_scenario(alternative)
    results.push({
      baseline: base_result,
      changed,
      operating_profit_delta_fen: signed_delta(
        changed.operating_profit_fen,
        base_result.operating_profit_fen,
      ),
      break_even_delta_units: signed_delta(
        changed.break_even_units,
        base_result.break_even_units,
      ),
      safety_margin_delta_units: signed_delta(
        changed.safety_margin_units,
        base_result.safety_margin_units,
      ),
    })
  }
  results
}

///|
/// Signed change from a baseline; unavailable if either side is invalid.
fn signed_delta(after : Int64?, before : Int64?) -> Int64? {
  match (after, before) {
    (Some(after_value), Some(before_value)) => Some(after_value - before_value)
    _ => None
  }
}
