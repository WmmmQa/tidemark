///|
test "static units propagate through forward references and cancel rates" {
  let sheet = @worksheet.compile(
    "check charge == recorded\nlet charge = rate * items\nlet recovered = charge / rate\ncheck recovered == items\ninput rate\ninput items\ninput recorded",
  )
  let formulas = sheet.formula_units({
    "rate": [
      { symbol: "fen", exponent: 1L, },
      { symbol: "item", exponent: -1L, },
    ],
    "items": [{ symbol: "item", exponent: 1L, }],
    "recorded": [{ symbol: "fen", exponent: 1L, }],
  })
  guard formulas["charge"] is [{ symbol: "fen", exponent: 1L, }] else {
    fail("charge must be in fen")
  }
  guard formulas["recovered"] is [{ symbol: "item", exponent: 1L, }] else {
    fail("recovered quantity must be in items")
  }
  assert_eq(formulas.length(), 2)
}

///|
test "same numeric result can mask a unit mismatch" {
  let sheet = @worksheet.compile("input cost\ninput stock\ncheck cost == stock")
  ignore(sheet.evaluate({ "cost": 5L, "stock": 5L }))
  let result = Ok(
    sheet.check_units({
      "cost": [{ symbol: "fen", exponent: 1L, }],
      "stock": [{ symbol: "item", exponent: 1L, }],
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(
    result
    is Err(Fault({ line: 3, column: 12, }, UnitMismatch, "fen^1 vs item^1")),
  )
}

///|
test "meter subtraction preserves units and locates a mismatched operand" {
  let sheet = @worksheet.compile(
    "input total\ninput loss\ninput branch\ncheck total - loss == branch",
  )
  let units : Map[String, Array[@worksheet.UnitFactor]] = {
    "total": [{ symbol: "Wh", exponent: 1L, }],
    "loss": [{ symbol: "Wh", exponent: 1L, }],
    "branch": [{ symbol: "Wh", exponent: 1L, }],
  }
  sheet.check_units(units)
  units["loss"] = [{ symbol: "fen", exponent: 1L, }]
  let result = Ok(sheet.check_units(units)) catch { error => Err(error) }
  assert_true(
    result
    is Err(Fault({ line: 4, column: 13, }, UnitMismatch, "Wh^1 vs fen^1")),
  )
}

///|
test "dimensionless literals, missing declarations and exponent bounds" {
  let sheet = @worksheet.compile("input x\nlet squared = x * x")
  let missing = Ok(sheet.check_units(Map([]))) catch { error => Err(error) }
  assert_true(missing is Err(Fault(_, MissingInput, "x")))
  let large = Ok(
    sheet.check_units({ "x": [{ symbol: "Wh", exponent: 1024L, }] }),
  ) catch {
    error => Err(error)
  }
  assert_true(large is Err(Fault(_, Limit, _)))
  let scalar = @worksheet.compile("input x\ncheck x == -2")
  scalar.check_units({ "x": [] })
}
