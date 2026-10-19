///|
/// Contribution available from one unit after its variable cost.
pub fn CvpCase::contribution_fen(self : CvpCase) -> Int64 {
  self.selling_price_fen - self.variable_cost_fen
}
