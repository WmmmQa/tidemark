///|
test "checked addition rejects signed overflow at both Int64 ends" {
  @debug.assert_eq(checked_add(MAX_I64, 1L, "add"), Err(Overflow("add")))
  @debug.assert_eq(checked_add(MIN_I64, -1L, "add"), Err(Overflow("add")))
  @debug.assert_eq(checked_add(MAX_I64, MIN_I64, "add"), Ok(-1L))
  @debug.assert_eq(checked_add(MIN_I64, 0L, "add"), Ok(MIN_I64))
}

///|
test "checked subtraction handles minimum operand without negating it" {
  @debug.assert_eq(checked_sub(0L, MIN_I64, "sub"), Err(Overflow("sub")))
  @debug.assert_eq(checked_sub(MIN_I64, 1L, "sub"), Err(Overflow("sub")))
  @debug.assert_eq(checked_sub(-1L, MIN_I64, "sub"), Ok(MAX_I64))
  @debug.assert_eq(checked_sub(MIN_I64, MIN_I64, "sub"), Ok(0L))
  @debug.assert_eq(checked_sub(MAX_I64, MAX_I64, "sub"), Ok(0L))
}

///|
test "checked nonnegative product accepts exact boundary and zero" {
  @debug.assert_eq(checked_product(MAX_I64, 1L, "mul"), Ok(MAX_I64))
  @debug.assert_eq(checked_product(MAX_I64, 2L, "mul"), Err(Overflow("mul")))
  @debug.assert_eq(checked_product(0L, MAX_I64, "mul"), Ok(0L))
  @debug.assert_eq(checked_product(MAX_I64, 0L, "mul"), Ok(0L))
  @debug.assert_eq(ceil_div(MAX_I64, 2L), 4611686018427387904L)
}
