///|
const MAX_I64 : Int64 = 9223372036854775807L

///|
const MIN_I64 : Int64 = -9223372036854775808L

///|
fn checked_add(
  a : Int64,
  b : Int64,
  context : String,
) -> Result[Int64, PlanError] {
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
) -> Result[Int64, PlanError] {
  if (b > 0 && a < MIN_I64 + b) || (b < 0 && a > MAX_I64 + b) {
    Err(Overflow(context))
  } else {
    Ok(a - b)
  }
}

///|
/// Check before multiplying; no abs(MIN_I64) or MIN_I64 / -1 is evaluated.
fn checked_mul(
  a : Int64,
  b : Int64,
  context : String,
) -> Result[Int64, PlanError] {
  if a == 0 || b == 0 {
    return Ok(0L)
  }
  let overflow = if a > 0 {
    if b > 0 {
      a > MAX_I64 / b
    } else {
      b < MIN_I64 / a
    }
  } else if b > 0 {
    a < MIN_I64 / b
  } else {
    a < MAX_I64 / b
  }
  if overflow {
    Err(Overflow(context))
  } else {
    Ok(a * b)
  }
}

///|
fn valid_id(id : String) -> Bool {
  !id.trim().is_empty() && id == id.trim().to_owned()
}

///|
fn valid_amount(value : Int64) -> Bool {
  value >= 0 && value <= @portfolio.MAX_INPUT_AMOUNT_FEN
}
