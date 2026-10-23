///|
const MAX_I64 : Int64 = 9223372036854775807L

///|
const MIN_I64 : Int64 = -9223372036854775808L

///|
fn checked_add(
  a : Int64,
  b : Int64,
  context : String,
) -> Result[Int64, MixError] {
  if (b > 0 && a > MAX_I64 - b) || (b < 0 && a < MIN_I64 - b) {
    Err(Overflow(context))
  } else {
    Ok(a + b)
  }
}

///|
fn checked_sub(
  a : Int64,
  b : Int64,
  context : String,
) -> Result[Int64, MixError] {
  if (b > 0 && a < MIN_I64 + b) || (b < 0 && a > MAX_I64 + b) {
    Err(Overflow(context))
  } else {
    Ok(a - b)
  }
}

///|
/// This helper only accepts already validated nonnegative operands.
fn checked_product(
  a : Int64,
  b : Int64,
  context : String,
) -> Result[Int64, MixError] {
  if a != 0 && b > MAX_I64 / a {
    Err(Overflow(context))
  } else {
    Ok(a * b)
  }
}

///|
fn gcd(a : Int64, b : Int64) -> Int64 {
  let mut left = a
  let mut right = b
  while right != 0 {
    let remainder = left % right
    left = right
    right = remainder
  }
  left
}

///|
/// Nonnegative numerator and strictly positive denominator; no a+b-1 overflow.
fn ceil_div(amount : Int64, contribution : Int64) -> Int64 {
  let quotient = amount / contribution
  if amount % contribution == 0 {
    quotient
  } else {
    quotient + 1L
  }
}
