///|
fn main {
  let raw_args = @env.args()
  let offset = if raw_args.length() > 0 && raw_args[0].contains("node") {
    2
  } else if raw_args.length() > 0 {
    1
  } else {
    0
  }
  let inputs : Array[String] = []
  for index in offset..<raw_args.length() {
    inputs.push(raw_args[index])
  }
  if inputs.length() == 0 {
    print_walkthrough()
  } else if inputs.length() == 8 {
    run_custom_comparison(inputs)
  } else {
    print_usage()
  }
}

///|
fn print_walkthrough() -> Unit {
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
  show_comparison(baseline, promotion)
}

///|
fn run_custom_comparison(inputs : Array[String]) -> Unit {
  let values : Array[Int64] = []
  for input in inputs {
    match parse_int64(input) {
      Some(value) => values.push(value)
      None => {
        println("Inputs must be whole-number fen amounts and units.")
        print_usage()
        return
      }
    }
  }
  let baseline = @domain.CvpScenario::{
    label: "Baseline",
    case: @domain.CvpCase::{
      selling_price_fen: values[0],
      variable_cost_fen: values[1],
      fixed_cost_fen: values[2],
    },
    planned_units: values[3],
  }
  let alternative = @domain.CvpScenario::{
    label: "Alternative",
    case: @domain.CvpCase::{
      selling_price_fen: values[4],
      variable_cost_fen: values[5],
      fixed_cost_fen: values[6],
    },
    planned_units: values[7],
  }
  println("Custom inputs: amounts are fen; volumes are whole units.")
  show_comparison(baseline, alternative)
}

///|
fn parse_int64(input : String) -> Int64? {
  Some(@string.parse_int64(input)) catch {
    _ => None
  }
}

///|
fn print_usage() -> Unit {
  println("Usage:")
  println(
    "  moon run cmd/main --target js BASE_PRICE_FEN BASE_VARIABLE_FEN BASE_FIXED_FEN BASE_UNITS ALT_PRICE_FEN ALT_VARIABLE_FEN ALT_FIXED_FEN ALT_UNITS",
  )
  println("Pass eight integer values; money is fen and volume is whole units.")
  println("Amounts and target profit must be at most 1000000000 fen.")
  println("Planned volume must be from 0 to 1000000000 units.")
}

///|
fn show_comparison(
  baseline : @domain.CvpScenario,
  alternative : @domain.CvpScenario,
) -> Unit {
  println("Tidemark · CVP scenario walkthrough")
  println("Money inputs are fen; quantity inputs are whole units.")
  println("")
  for result in @engine.compare_scenarios([baseline, alternative]) {
    print_scenario(result)
  }
  println("Sensitivity from baseline to alternative")
  for result in @engine.sensitivity_analysis(baseline, [alternative]) {
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
    for issue in result.issues {
      print_issue(issue)
    }
  }
  println("")
}

///|
fn print_issue(issue : @engine.ScenarioIssue) -> Unit {
  match issue {
    @engine.InvalidCase(case_issue) =>
      match case_issue {
        @domain.NonPositiveSellingPrice =>
          println("Selling price must be positive.")
        @domain.NegativeVariableCost =>
          println("Unit variable cost cannot be negative.")
        @domain.NegativeFixedCost => println("Fixed cost cannot be negative.")
        @domain.MonetaryAmountOutOfRange =>
          println("A money input exceeds the supported limit.")
        @domain.NoPositiveContribution =>
          println("Selling price must exceed unit variable cost.")
      }
    @engine.NegativePlannedUnits => println("Planned units cannot be negative.")
    @engine.PlannedUnitsOutOfRange =>
      println("Planned units exceed the supported limit.")
  }
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
