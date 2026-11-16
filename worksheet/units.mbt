///|
/// A named unit factor. A fee in fen per item uses fen^1 and item^-1.
pub(all) struct UnitFactor {
  symbol : String
  exponent : Int64
}

///|
type UnitProduct = Map[String, Int64]

///|
fn combine_units(
  left : UnitProduct,
  right : UnitProduct,
  sign : Int64,
  at : Position,
) -> UnitProduct raise Fault {
  let result = Map([])
  for symbol, power in left {
    result[symbol] = power
  }
  for symbol, power in right {
    let next = result.get(symbol).unwrap_or(0L) + sign * power
    if next < -1024L || next > 1024L {
      raise Fault(at, Limit, "unit exponent must be between -1024 and 1024")
    }
    if next == 0L {
      result.remove(symbol)
    } else {
      result[symbol] = next
    }
  }
  result
}

///|
fn same_units(left : UnitProduct, right : UnitProduct) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for symbol, power in left {
    if right.get(symbol) != Some(power) {
      return false
    }
  }
  true
}

///|
fn format_units(units : UnitProduct) -> String {
  let symbols = units.keys().collect()
  symbols.sort_by((a, b) => a.compare(b))
  if symbols.is_empty() {
    return "1"
  }
  symbols.map(symbol => "\{symbol}^\{units[symbol]}").join(" ")
}

///|
fn infer_row(
  row : Row[Int32],
  units : Array[UnitProduct],
) -> UnitProduct raise Fault {
  let stack : Array[UnitProduct] = []
  for instruction in row.instructions {
    match instruction {
      Number(_) => stack.push(Map([]))
      Read(slot, _) => stack.push(units[slot])
      Apply(Negate, _) => ()
      Apply(operator, at) => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        let value = match operator {
          Multiply => combine_units(left, right, 1L, at)
          Divide => combine_units(left, right, -1L, at)
          Add | Subtract | AssertEqual => {
            if !same_units(left, right) {
              raise Fault(
                at,
                UnitMismatch,
                "\{format_units(left)} vs \{format_units(right)}",
              )
            }
            left
          }
          Negate => panic()
        }
        stack.push(value)
      }
    }
  }
  stack.pop().unwrap()
}

///|
/// Check the units of every formula and equality without evaluating integers.
/// Each input needs a declaration. An empty factor array means dimensionless.
/// Unit symbols are opaque and must use a consistent scale.
/// ```mbt check
/// test {
///   let program = @worksheet.compile("input x\nlet doubled = x * 2")
///   program.check_units({ "x": [{ symbol: "Wh", exponent: 1L, }] })
/// }
/// ```
pub fn Program::check_units(
  self : Program,
  declarations : Map[String, Array[UnitFactor]],
) -> Unit raise Fault {
  let units : Array[UnitProduct] = Array::makei(self.rows.length(), _ => Map([]))
  for name, factors in declarations {
    let slot = self.input_slot(name)
    let at = self.rows[slot].at
    for factor in factors {
      let { symbol, exponent, } = factor
      if symbol == "" ||
        exponent == 0L ||
        exponent < -1024L ||
        exponent > 1024L ||
        units[slot].contains(symbol) {
        raise Fault(
          at,
          InvalidBinding,
          "invalid or repeated unit factor for \{name}",
        )
      }
      units[slot][symbol] = exponent
    }
  }
  for slot in self.order {
    let row = self.rows[slot]
    if row.kind is Input(name) {
      if !declarations.contains(name) {
        raise Fault(row.at, MissingInput, name)
      }
    } else {
      units[slot] = infer_row(row, units)
    }
  }
}
