///|
/// One named set of inputs replayed against both worksheet revisions.
pub(all) struct ReplayCase {
  name : String
  bindings : Map[String, Int64]
}

///|
pub(all) enum RevisionOutcome {
  Equivalent
  Changed(Array[OutputChange])
  BaselineRejected(Fault)
  CandidateRejected(Fault)
  BothRejected(Fault, Fault)
}

///|
/// A missing value indicates that the named formula is absent on that side.
pub(all) struct OutputChange {
  name : String
  before : Int64?
  after : Int64?
}

///|
pub(all) struct ReplayResult {
  name : String
  outcome : RevisionOutcome
}

///|
fn Snapshot::formula_values(self : Snapshot) -> Map[String, Int64] {
  let values = Map([])
  for slot, row in self.program.rows {
    if row.kind is Formula(name) {
      values[name] = self.values[slot]
    }
  }
  values
}

///|
fn compare_outputs(before : Snapshot, after : Snapshot) -> RevisionOutcome {
  let old_values = before.formula_values()
  let new_values = after.formula_values()
  let names = old_values.keys().collect()
  for name in new_values.keys() {
    if !old_values.contains(name) {
      names.push(name)
    }
  }
  let changes = []
  for name in names {
    let before = old_values.get(name)
    let after = new_values.get(name)
    if before != after {
      changes.push({ name, before, after, })
    }
  }
  if changes.is_empty() {
    Equivalent
  } else {
    Changed(changes)
  }
}

///|
/// Evaluate every case independently. A rejected case does not stop replay.
/// Existing formulas follow baseline declaration order, then additions follow
/// candidate declaration order. Results preserve case order.
/// ```mbt check
/// test {
///   let old = @worksheet.compile("input n\nlet total = n * 2")
///   let new = @worksheet.compile("input n\nlet total = n * 3")
///   let results = @worksheet.compare_revisions(old, new, [
///     { name: "sample", bindings: { "n": 5L }, },
///   ])
///   assert_true(
///     results[0].outcome
///     is Changed([{ name: "total", before: Some(10L), after: Some(15L), }]),
///   )
/// }
/// ```
pub fn compare_revisions(
  baseline : Program,
  candidate : Program,
  cases : ArrayView[ReplayCase],
) -> Array[ReplayResult] {
  let results = []
  for sample in cases {
    let before = Ok(baseline.evaluate(sample.bindings)) catch { e => Err(e) }
    let after = Ok(candidate.evaluate(sample.bindings)) catch { e => Err(e) }
    let outcome = match (before, after) {
      (Ok(old), Ok(new)) => compare_outputs(old, new)
      (Err(old), Ok(_)) => BaselineRejected(old)
      (Ok(_), Err(new)) => CandidateRejected(new)
      (Err(old), Err(new)) => BothRejected(old, new)
    }
    results.push({ name: sample.name, outcome, })
  }
  results
}
