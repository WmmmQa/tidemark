///|
test "signed arithmetic guards both bounds without negating minimum Int64" {
  @debug.assert_eq(checked_add(MAX_I64, 1L, "add"), Err(Overflow("add")))
  @debug.assert_eq(checked_add(MIN_I64, -1L, "add"), Err(Overflow("add")))
  @debug.assert_eq(checked_add(MAX_I64, MIN_I64, "add"), Ok(-1L))
  @debug.assert_eq(checked_sub(0L, MIN_I64, "sub"), Err(Overflow("sub")))
  @debug.assert_eq(checked_sub(MAX_I64, -1L, "sub"), Err(Overflow("sub")))
  @debug.assert_eq(checked_sub(-1L, MIN_I64, "sub"), Ok(MAX_I64))
  @debug.assert_eq(checked_sub(MIN_I64, MIN_I64, "sub"), Ok(0L))
}

///|
test "signed multiplication covers every quadrant exact bounds and zero" {
  for
    pair in [
      (MAX_I64, 1L),
      (MIN_I64, 1L),
      (0L, MIN_I64),
      (MIN_I64, 0L),
      (-2L, 3L),
      (2L, -3L),
      (-2L, -3L),
      (2L, 3L),
    ] {
    let (a, b) = pair
    @debug.assert_eq(checked_mul(a, b, "mul"), Ok(a * b))
  }
  for
    pair in [
      (MAX_I64, 2L),
      (MIN_I64, 2L),
      (MIN_I64, -1L),
      (-1L, MIN_I64),
      (2L, MIN_I64),
      (MAX_I64, -2L),
      (-2L, MAX_I64),
    ] {
    let (a, b) = pair
    @debug.assert_eq(checked_mul(a, b, "mul"), Err(Overflow("mul")))
  }
  @debug.assert_eq(checked_mul(-4611686018427387904L, 2L, "mul"), Ok(MIN_I64))
  @debug.assert_eq(
    checked_mul(-4611686018427387904L, -2L, "mul"),
    Err(Overflow("mul")),
  )
}
