///|
test "revision replay reports directional rejections without stopping later cases" {
  let old = @worksheet.compile("input n\ncheck n == 1")
  let new = @worksheet.compile("input n\ncheck n == 2")
  let results = @worksheet.compare_revisions(old, new, [
    { name: "regression", bindings: { "n": 1L }, },
    { name: "recovery", bindings: { "n": 2L }, },
    { name: "invalid", bindings: { "n": 3L }, },
  ])
  assert_true(
    results[0].outcome
    is CandidateRejected(Fault({ line: 2, .. }, CheckFailed, _)),
  )
  assert_true(results[1].outcome is BaselineRejected(Fault(_, CheckFailed, _)))
  assert_true(
    results[2].outcome
    is BothRejected(Fault(_, CheckFailed, _), Fault(_, CheckFailed, _)),
  )
}

///|
test "revision replay matches formula names and orders additions removals and changes" {
  let old = @worksheet.compile(
    "input n\nlet retired = 3\nlet sum = n\nlet stable = n",
  )
  let new = @worksheet.compile(
    "input n\nlet stable = n\nlet sum = n * 2\nlet added = 0",
  )
  let samples : Array[@worksheet.ReplayCase] = [
    { name: "one", bindings: { "n": 1L }, },
  ]
  let results = @worksheet.compare_revisions(old, new, samples[:])
  assert_eq(results[0].name, "one")
  assert_true(
    results[0].outcome
    is Changed(
      [
        { name: "retired", before: Some(3L), after: None, },
        { name: "sum", before: Some(1L), after: Some(2L), },
        { name: "added", before: None, after: Some(0L), },
      ]
    ),
  )
  assert_true(
    @worksheet.compare_revisions(old, old, samples[:])[0].outcome is Equivalent,
  )
}
