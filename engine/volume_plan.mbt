///|
/// Operating profit for a non-negative planned unit volume.
pub fn operating_profit_fen(case : @domain.CvpCase, units : Int64) -> Int64? {
  if units < 0 || case.issues().length() > 0 {
    return None
  }
  Some(units * case.contribution_fen() - case.fixed_cost_fen)
}

///|
/// Planned units above or below break-even; negative values indicate a gap.
pub fn safety_margin_units(case : @domain.CvpCase, planned_units : Int64) -> Int64? {
  if planned_units < 0 {
    return None
  }
  match break_even_units(case) {
    Some(threshold) => Some(planned_units - threshold)
    None => None
  }
}
