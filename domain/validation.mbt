///|
/// Reasons an operating case cannot be used for ordinary break-even analysis.
pub(all) enum CaseIssue {
  NonPositiveSellingPrice
  NegativeVariableCost
  NegativeFixedCost
  MonetaryAmountOutOfRange
  NoPositiveContribution
}

///|
/// Maximum supported monetary input: 1,000,000,000 fen (¥10,000,000).
/// This bound keeps all documented CVP intermediate calculations in Int64.
pub const MAX_SUPPORTED_AMOUNT_FEN : Int64 = 1_000_000_000L

///|
/// Maximum supported planned volume: 1,000,000,000 whole units.
pub const MAX_SUPPORTED_UNITS : Int64 = 1_000_000_000L

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
  if self.selling_price_fen > MAX_SUPPORTED_AMOUNT_FEN ||
    self.variable_cost_fen > MAX_SUPPORTED_AMOUNT_FEN ||
    self.fixed_cost_fen > MAX_SUPPORTED_AMOUNT_FEN {
    found.push(MonetaryAmountOutOfRange)
  }
  if self.selling_price_fen > 0 &&
    self.variable_cost_fen >= 0 &&
    self.selling_price_fen <= MAX_SUPPORTED_AMOUNT_FEN &&
    self.variable_cost_fen <= MAX_SUPPORTED_AMOUNT_FEN &&
    self.selling_price_fen <= self.variable_cost_fen {
    found.push(NoPositiveContribution)
  }
  found
}
