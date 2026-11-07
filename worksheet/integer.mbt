///|
const MAX_VALUE : Int64 = 9223372036854775807L

///|
const MIN_VALUE : Int64 = -9223372036854775808L

///|
fn multiply_overflows(left : Int64, right : Int64) -> Bool {
  if left > 0 {
    right > MAX_VALUE / left || right < MIN_VALUE / left
  } else if left < 0 {
    if right > 0 {
      left < MIN_VALUE / right
    } else {
      right < MAX_VALUE / left
    }
  } else {
    false
  }
}

///|
fn apply_binary(
  operator : Operator,
  left : Int64,
  right : Int64,
  at : Position,
) -> Int64 raise Fault {
  let overflow = Fault(at, Overflow, "result exceeds Int64")
  match operator {
    Add => {
      if (right > 0 && left > MAX_VALUE - right) ||
        (right < 0 && left < MIN_VALUE - right) {
        raise overflow
      }
      left + right
    }
    Subtract => {
      if (right > 0 && left < MIN_VALUE + right) ||
        (right < 0 && left > MAX_VALUE + right) {
        raise overflow
      }
      left - right
    }
    Multiply => {
      if multiply_overflows(left, right) {
        raise overflow
      }
      left * right
    }
    Divide => {
      if right == 0 {
        raise Fault(at, ZeroDivisor, "division by zero")
      }
      if left == MIN_VALUE && right == -1L {
        raise overflow
      }
      if left % right != 0L {
        raise Fault(at, InexactDivision, "\{left} is not divisible by \{right}")
      }
      left / right
    }
    AssertEqual => {
      if left != right {
        raise Fault(at, CheckFailed, "\{left} != \{right}")
      }
      1L
    }
    Negate => panic()
  }
}
