///|
/// The smallest whole-unit volume that covers fixed operating cost.
/// Returns None when the case is invalid or has no positive contribution.
pub fn break_even_units(case : @domain.CvpCase) -> Int64? {
  if case.issues().length() > 0 {
    return None
  }
  if case.fixed_cost_fen == 0 {
    return Some(0L)
  }
  let contribution = case.contribution_fen()
  Some(ceil_div(case.fixed_cost_fen, contribution))
}

///|
/// Integer ceiling division for non-negative amounts and a positive divisor.
fn ceil_div(amount : Int64, unit_margin : Int64) -> Int64 {
  let whole = amount / unit_margin
  if amount % unit_margin == 0 {
    whole
  } else {
    whole + 1L
  }
}
