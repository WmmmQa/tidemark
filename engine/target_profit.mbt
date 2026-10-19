///|
/// The smallest whole-unit volume that reaches a non-negative target profit.
/// A negative target is outside the ordinary target-profit question.
pub fn units_for_target_profit(
  case : @domain.CvpCase,
  target_profit_fen : Int64,
) -> Int64? {
  if target_profit_fen < 0 || case.issues().length() > 0 {
    return None
  }
  let contribution = case.contribution_fen()
  Some(ceil_div(case.fixed_cost_fen + target_profit_fen, contribution))
}
