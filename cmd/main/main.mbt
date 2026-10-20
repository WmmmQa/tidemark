///|
fn main {
  let baseline = @domain.CvpScenario::{
    label: "Baseline",
    case: @domain.CvpCase::{
      selling_price_fen: 8000L,
      variable_cost_fen: 4800L,
      fixed_cost_fen: 1600000L,
    },
    planned_units: 700L,
  }
  let promotion = @domain.CvpScenario::{
    label: "Promotion price",
    case: @domain.CvpCase::{
      selling_price_fen: 7500L,
      variable_cost_fen: 4800L,
      fixed_cost_fen: 1600000L,
    },
    planned_units: 700L,
  }

  println("Tidemark · CVP pricing walkthrough")
  println("Money inputs are fen; quantity inputs are whole units.")
  println("")
  for result in @engine.compare_scenarios([baseline, promotion]) {
    print_scenario(result)
  }

  println("Sensitivity from baseline to promotion price")
  for result in @engine.sensitivity_analysis(baseline, [promotion]) {
    print_delta(
      "Operating profit change (fen)",
      result.operating_profit_delta_fen,
    )
    print_delta("Break-even change (units)", result.break_even_delta_units)
    print_delta(
      "Safety-margin change (units)",
      result.safety_margin_delta_units,
    )
  }
}

///|
fn print_scenario(result : @engine.ScenarioResult) -> Unit {
  println("Scenario: \{result.label}")
  print_metric("Break-even units", result.break_even_units)
  print_metric("Operating profit (fen)", result.operating_profit_fen)
  print_metric("Safety-margin units", result.safety_margin_units)
  if result.issues.length() > 0 {
    println("Invalid input issue count: \{result.issues.length()}")
  }
  println("")
}

///|
fn print_metric(label : String, value : Int64?) -> Unit {
  match value {
    Some(amount) => println("\{label}: \{amount}")
    None => println("\{label}: unavailable")
  }
}

///|
fn print_delta(label : String, value : Int64?) -> Unit {
  match value {
    Some(amount) => println("\{label}: \{amount}")
    None => println("\{label}: unavailable")
  }
}
