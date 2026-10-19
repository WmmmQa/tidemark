///|
/// Why a scenario cannot produce ordinary CVP metrics.
pub(all) enum ScenarioIssue {
  InvalidCase(@domain.CaseIssue)
  NegativePlannedUnits
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
