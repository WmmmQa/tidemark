///|
test "valid contribution uses integer fen" {
  let case_ = @domain.CvpCase::{
    selling_price_fen: 8000L,
    variable_cost_fen: 4800L,
    fixed_cost_fen: 1600000L,
  }
  assert_eq(case_.contribution_fen(), Some(3200L))
  assert_eq(case_.issues().length(), 0)
}

///|
test "invalid extreme values are rejected without subtraction overflow" {
  let case_ = @domain.CvpCase::{
    selling_price_fen: 9223372036854775807L,
    variable_cost_fen: -9223372036854775808L,
    fixed_cost_fen: 0L,
  }
  assert_eq(case_.contribution_fen(), None)
  assert_eq(case_.issues().length(), 2)
}

///|
test "supported amount boundary is accepted and next fen is rejected" {
  let accepted = @domain.CvpCase::{
    selling_price_fen: @domain.MAX_SUPPORTED_AMOUNT_FEN,
    variable_cost_fen: 0L,
    fixed_cost_fen: 0L,
  }
  let rejected = {
    ..accepted,
    selling_price_fen: @domain.MAX_SUPPORTED_AMOUNT_FEN + 1L,
  }
  assert_eq(accepted.issues().length(), 0)
  assert_eq(rejected.contribution_fen(), None)
}
