///|
test "CVP core calculations use ceiling whole units" {
  let case_ = @domain.CvpCase::{
    selling_price_fen: 8000L,
    variable_cost_fen: 4800L,
    fixed_cost_fen: 1600000L,
  }
  assert_eq(@engine.contribution_ratio_bps(case_), Some(4000L))
  assert_eq(@engine.break_even_units(case_), Some(500L))
  assert_eq(@engine.units_for_target_profit(case_, 800000L), Some(750L))
  assert_eq(@engine.revenue_for_target_profit(case_, 800000L), Some(6000000L))
  assert_eq(@engine.operating_profit_fen(case_, 700L), Some(640000L))
  assert_eq(@engine.safety_margin_units(case_, 700L), Some(200L))
}

///|
test "amount and volume limits keep public results representable" {
  let case_ = @domain.CvpCase::{
    selling_price_fen: 2L,
    variable_cost_fen: 1L,
    fixed_cost_fen: 0L,
  }
  assert_eq(
    @engine.units_for_target_profit(
      case_,
      @domain.MAX_SUPPORTED_AMOUNT_FEN + 1L,
    ),
    None,
  )
  assert_eq(
    @engine.operating_profit_fen(case_, @domain.MAX_SUPPORTED_UNITS + 1L),
    None,
  )
  let edge_case = @domain.CvpCase::{
    selling_price_fen: @domain.MAX_SUPPORTED_AMOUNT_FEN,
    variable_cost_fen: @domain.MAX_SUPPORTED_AMOUNT_FEN - 1L,
    fixed_cost_fen: @domain.MAX_SUPPORTED_AMOUNT_FEN,
  }
  assert_eq(
    @engine.revenue_for_target_profit(
      edge_case,
      @domain.MAX_SUPPORTED_AMOUNT_FEN,
    ),
    Some(2000000000000000000L),
  )
}

///|
test "sensitivity differences preserve signs and invalid rows" {
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
    label: "Promotion",
    case: @domain.CvpCase::{
      selling_price_fen: 7500L,
      variable_cost_fen: 4800L,
      fixed_cost_fen: 1600000L,
    },
    planned_units: 700L,
  }
  let result = @engine.sensitivity_analysis(baseline, [promotion])[0]
  assert_eq(result.operating_profit_delta_fen, Some(-350000L))
  assert_eq(result.break_even_delta_units, Some(93L))
  assert_eq(result.safety_margin_delta_units, Some(-93L))
}
