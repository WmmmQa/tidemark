///|
fn expect_fault(
  action : () -> Unit raise @worksheet.Fault,
  code : @worksheet.Code,
  line : Int32,
  column : Int32,
  detail : String,
) -> Unit raise {
  try action() catch {
    @worksheet.Fault(at, actual, message) =>
      @debug.assert_eq(
        (at.line, at.column, actual, message),
        (line, column, code, detail),
      )
  } noraise {
    _ => fail("expected a worksheet fault")
  }
}

///|
test "forward references, precedence, associativity and source order" {
  let source =
    #|check total == 13
    #|let total = base + 2 * (4 - 1) + 8 / 4 / 2
    #|let opposite = -(total - 5)
    #|input base
  let snapshot = @worksheet.compile(source).evaluate({ "base": 6L })
  @debug.assert_eq(snapshot.entries(), [
    ("total", 13L),
    ("opposite", -8L),
    ("base", 6L),
  ])
  @debug.assert_eq(snapshot.value("unknown"), None)
  @debug.assert_eq(snapshot.evaluated_count(), 3)
}

///|
test "name and syntax diagnostics point into the source" {
  expect_fault(
    () => ignore(@worksheet.compile("input a\r\nlet a = 2")),
    Duplicate,
    2,
    1,
    "a",
  )
  expect_fault(
    () => ignore(@worksheet.compile("let total = missing + 1")),
    Unknown,
    1,
    13,
    "missing",
  )
  expect_fault(
    () => ignore(@worksheet.compile("check 1 = 2")),
    Syntax,
    1,
    9,
    "expected '=='",
  )
  expect_fault(
    () => ignore(@worksheet.compile("let a = (2")),
    Syntax,
    1,
    11,
    "expected ')'",
  )
}

///|
test "cycle includes the actual loop and omits downstream names" {
  expect_fault(
    () => ignore(@worksheet.compile("let out = a\nlet a = b + b\nlet b = a")),
    Cycle,
    2,
    1,
    "a -> b -> a",
  )
  expect_fault(
    () => ignore(@worksheet.compile("let x = x")),
    Cycle,
    1,
    1,
    "x -> x",
  )
}

///|
test "bindings require all inputs and do not override formulas" {
  let program = @worksheet.compile("input value\nlet total = value")
  expect_fault(
    () => ignore(program.evaluate(Map([]))),
    MissingInput,
    1,
    1,
    "value",
  )
  expect_fault(
    () => ignore(program.evaluate({ "extra": 2L })),
    InvalidBinding,
    0,
    0,
    "extra",
  )
  let snapshot = program.evaluate({ "value": 2L })
  expect_fault(
    () => ignore(snapshot.update({ "total": 3L })),
    InvalidBinding,
    2,
    1,
    "total",
  )
  @debug.assert_eq(snapshot.value("total"), Some(2L))
}

///|
test "batch update compares against a fresh run across a grid" {
  let source =
    #|let sink = left + right + left
    #|let left = x * 2
    #|let right = (x + y) * 3
    #|let separate = z * z
    #|check sink == x * 4 + (x + y) * 3
    #|input x
    #|input y
    #|input z
  let program = @worksheet.compile(source)
  let baseline = program.evaluate({ "x": 0L, "y": 0L, "z": 5L })
  for x in -3..<4 {
    for y in -3..<4 {
      let updated = baseline.update({ "x": x.to_int64(), "y": y.to_int64() })
      let fresh = program.evaluate({
        "x": x.to_int64(),
        "y": y.to_int64(),
        "z": 5L,
      })
      @debug.assert_eq(updated.entries(), fresh.entries())
      assert_true(updated.evaluated_count() < fresh.evaluated_count())
    }
  }
  @debug.assert_eq(baseline.value("sink"), Some(0L))
}

///|
test "unchanged values stop propagation and no-op updates do zero work" {
  let program = @worksheet.compile(
    "input x\nlet zero = x - x\nlet result = zero + 3\ncheck result == 3",
  )
  let baseline = program.evaluate({ "x": 1L })
  let updated = baseline.update({ "x": 2L })
  @debug.assert_eq(updated.evaluated_count(), 1)
  @debug.assert_eq(updated.update({ "x": 2L }).evaluated_count(), 0)
  @debug.assert_eq(updated.value("result"), Some(3L))
}

///|
test "invalid edit leaves the previous snapshot usable" {
  let program = @worksheet.compile(
    "input a\ninput b\nlet double = a * 2\ncheck double == b",
  )
  let baseline = program.evaluate({ "a": 2L, "b": 4L })
  expect_fault(
    () => ignore(baseline.update({ "a": 3L })),
    CheckFailed,
    4,
    14,
    "6 != 4",
  )
  @debug.assert_eq(baseline.value("double"), Some(4L))
  let accepted = baseline.update({ "a": 3L, "b": 6L })
  @debug.assert_eq(accepted.value("double"), Some(6L))
  @debug.assert_eq(accepted.evaluated_count(), 2)
}

///|
test "exact signed arithmetic and the smallest literal" {
  let program = @worksheet.compile(
    "let low = -9223372036854775808\nlet high = 9223372036854775807\nlet half = low / 2\nlet minus = -7 * 3\nlet both = -7 * -3\nlet zero = low * 0",
  )
  let values = program.evaluate(Map([]))
  @debug.assert_eq(values.value("low"), Some(-9223372036854775808L))
  @debug.assert_eq(values.value("high"), Some(9223372036854775807L))
  @debug.assert_eq(values.value("half"), Some(-4611686018427387904L))
  @debug.assert_eq(values.value("minus"), Some(-21L))
  @debug.assert_eq(values.value("both"), Some(21L))
  @debug.assert_eq(values.value("zero"), Some(0L))
}

///|
test "overflow, division by zero, and fractions raise located errors" {
  expect_fault(
    () => ignore(@worksheet.compile("let a = 9223372036854775808")),
    Overflow,
    1,
    9,
    "integer literal exceeds Int64",
  )
  expect_fault(
    () => ignore(@worksheet.compile("let a = -9223372036854775809")),
    Overflow,
    1,
    9,
    "integer literal exceeds Int64",
  )
  for
    expression in [
      "9223372036854775807+1", "-9223372036854775808-1", "-9223372036854775808*-1",
      "-9223372036854775808/-1", "-9223372036854775808*2", "2*-9223372036854775808",
      "9223372036854775807--1", "-(-9223372036854775808)",
    ] {
    let program = @worksheet.compile("let a = " + expression)
    try ignore(program.evaluate(Map([]))) catch {
      @worksheet.Fault(at, Overflow, _) => assert_true(at.column >= 9)
      error => fail("expected overflow, got \{@debug.to_string(error)}")
    } noraise {
      _ => fail("expected overflow for \{expression}")
    }
  }
  expect_fault(
    () => ignore(@worksheet.compile("let a = 3 / 0").evaluate(Map([]))),
    ZeroDivisor,
    1,
    11,
    "division by zero",
  )
  expect_fault(
    () => ignore(@worksheet.compile("let a = 3 / 2").evaluate(Map([]))),
    InexactDivision,
    1,
    11,
    "3 is not divisible by 2",
  )
}

///|
test "source, statement and nesting limits fail without evaluating" {
  expect_fault(
    () => ignore(@worksheet.compile("x".repeat(65537))),
    Limit,
    1,
    1,
    "source exceeds 65536 UTF-16 units",
  )
  expect_fault(
    () => ignore(@worksheet.compile("#".repeat(513))),
    Limit,
    1,
    1,
    "line exceeds 512 characters",
  )
  let rows = "check 1 == 1\n".repeat(512)
  let last = @worksheet.compile(rows).evaluate(Map([]))
  @debug.assert_eq(last.evaluated_count(), 512)
  expect_fault(
    () => ignore(@worksheet.compile(rows + "check 1 == 1")),
    Limit,
    513,
    1,
    "worksheet exceeds 512 statements",
  )
  let nested = "let a = " + "(".repeat(33) + "1" + ")".repeat(33)
  expect_fault(
    () => ignore(@worksheet.compile(nested)),
    Limit,
    1,
    42,
    "expression nesting exceeds 32",
  )
}

///|
test "reverse-declared chain reaches the statement limit and supports successive edits" {
  let lines = []
  for index = 511; index > 0; index = index - 1 {
    lines.push("let v\{index} = v\{index - 1} + 1")
  }
  lines.push("input v0")
  let program = @worksheet.compile(lines.join("\n"))
  let base = program.evaluate({ "v0": 0L })
  let next = base.update({ "v0": 10L })
  let last = next.update({ "v0": -10L })
  @debug.assert_eq(base.value("v511"), Some(511L))
  @debug.assert_eq(next.value("v511"), Some(521L))
  @debug.assert_eq(last.value("v511"), Some(501L))
  @debug.assert_eq(last.evaluated_count(), 511)
}
