///|
fn parse_unit_factor(raw : StringView) -> @worksheet.UnitFactor raise Usage {
  guard raw.split("^").collect() is [symbol, exponent] && !symbol.is_empty() else {
    raise Usage("expected a unit factor SYMBOL^EXPONENT")
  }
  let exponent = @string.parse_int64(exponent.to_owned()) catch {
    _ => raise Usage("invalid unit exponent in '\{raw}'")
  }
  { symbol: symbol.to_owned(), exponent, }
}

///|
fn run_unit_check(arguments : ArrayView[String]) -> Json raise {
  guard arguments is [source, .. bindings] else {
    raise Usage(
      "pass --check-units SOURCE followed by name=SYMBOL^EXPONENT or name=1",
    )
  }
  let declarations : Map[String, Array[@worksheet.UnitFactor]] = Map([])
  for binding in bindings {
    guard binding.split("=").collect() is [name, raw] && !name.is_empty() else {
      raise Usage("expected name=unit, got '\{binding}'")
    }
    let name = name.to_owned()
    if declarations.contains(name) {
      raise Usage("duplicate unit declaration for '\{name}'")
    }
    let factors = []
    if raw != "1" {
      for factor in raw.split(",") {
        factors.push(parse_unit_factor(factor))
      }
    }
    declarations[name] = factors
  }
  let inferred = @worksheet.compile(source).formula_units(declarations)
  let formulas : Map[String, Json] = Map([])
  for name, factors in inferred {
    formulas[name] = Json::array(
      factors.map(factor => {
        "symbol": Json::string(factor.symbol),
        "exponent": Json::number(factor.exponent.to_double()),
      }),
    )
  }
  { "formulas": Json::object(formulas) }
}
