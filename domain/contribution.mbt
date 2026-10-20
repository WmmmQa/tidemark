///|
/// Contribution available from one unit after its variable cost.
/// Invalid or out-of-range inputs have no contribution result.
pub fn CvpCase::contribution_fen(self : CvpCase) -> Int64? {
  if self.issues().length() > 0 {
    return None
  }
  Some(self.selling_price_fen - self.variable_cost_fen)
}
