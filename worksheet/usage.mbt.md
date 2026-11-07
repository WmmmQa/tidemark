# Reuse a compiled worksheet

An application can reuse a compiled program for multiple independent input
sets and derive another snapshot from any successful result.

~~~mbt check
///|
test "reuse an exact reconciliation worksheet" {
  let model =
    #|check delta == expected
    #|let delta = actual - budget
    #|input actual
    #|input budget
    #|input expected
  let program = @worksheet.compile(model)
  let before = program.evaluate({
    "actual": 50L,
    "budget": 40L,
    "expected": 10L,
  })
  let after = before.update({ "actual": 45L, "expected": 5L })
  assert_eq(before.value("delta"), Some(10L))
  assert_eq(after.value("delta"), Some(5L))
}
~~~
