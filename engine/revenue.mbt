///|
/// Required sales revenue for a valid target-profit volume.
pub fn revenue_for_target_profit(
  case : @domain.CvpCase,
  target_profit_fen : Int64,
) -> Int64? {
  match units_for_target_profit(case, target_profit_fen) {
    Some(units) => Some(units * case.selling_price_fen)
    None => None
  }
}
