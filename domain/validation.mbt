///|
/// Reasons an operating case cannot be used for ordinary break-even analysis.
pub(all) enum CaseIssue {
  NonPositiveSellingPrice
  NegativeVariableCost
  NegativeFixedCost
  NoPositiveContribution
}

///|
/// Return all input issues so a caller can fix several fields at once.
pub fn CvpCase::issues(self : CvpCase) -> Array[CaseIssue] {
  let found = []
  if self.selling_price_fen <= 0 {
    found.push(NonPositiveSellingPrice)
  }
  if self.variable_cost_fen < 0 {
    found.push(NegativeVariableCost)
  }
  if self.fixed_cost_fen < 0 {
    found.push(NegativeFixedCost)
  }
  if self.selling_price_fen - self.variable_cost_fen <= 0 {
    found.push(NoPositiveContribution)
  }
  found
}
