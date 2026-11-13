///|
fn render_fault(fault : @worksheet.Fault) -> Json {
  let @worksheet.Fault(at, code, detail) = fault
  {
    "error": Json::string(code.name()),
    "line": Json::number(at.line.to_double()),
    "column": Json::number(at.column.to_double()),
    "detail": Json::string(detail),
  }
}

///|
fn output_value(value : Int64?) -> Json {
  match value {
    Some(value) => Json::string(value.to_string())
    None => Json::null()
  }
}

///|
fn render_replay(result : @worksheet.ReplayResult) -> Json {
  let name = Json::string(result.name)
  match result.outcome {
    Equivalent => { "case": name, "status": "equivalent" }
    Changed(changes) => {
      let values = changes.map(change => {
        let row : Json = {
          "name": Json::string(change.name),
          "before": output_value(change.before),
          "after": output_value(change.after),
        }
        row
      })
      { "case": name, "status": "changed", "outputs": Json::array(values) }
    }
    BaselineRejected(fault) =>
      {
        "case": name,
        "status": "baseline-rejected",
        "baseline": render_fault(fault),
      }
    CandidateRejected(fault) =>
      {
        "case": name,
        "status": "candidate-rejected",
        "candidate": render_fault(fault),
      }
    BothRejected(old, new) =>
      {
        "case": name,
        "status": "both-rejected",
        "baseline": render_fault(old),
        "candidate": render_fault(new),
      }
  }
}

///|
fn run_comparison(arguments : ArrayView[String]) -> Json raise {
  guard arguments is [old, new, .. samples] && !samples.is_empty() else {
    raise Usage(
      "pass --compare BASELINE CANDIDATE and one or more NAME:key=value,key=value cases",
    )
  }
  let cases : Array[@worksheet.ReplayCase] = []
  let names = Map([])
  for sample in samples {
    guard sample.split(":").collect() is [label, pairs] && !label.is_empty() else {
      raise Usage("expected NAME:key=value,key=value")
    }
    let name = label.to_owned()
    if names.contains(name) {
      raise Usage("duplicate case '\{name}'")
    }
    names[name] = true
    let bindings = Map([])
    if !pairs.is_empty() {
      for pair in pairs.to_owned().split(",") {
        parse_binding(pair.to_owned(), bindings)
      }
    }
    cases.push({ name, bindings, })
  }
  let baseline = @worksheet.compile(old) catch {
    fault => {
      let report : Json = {
        "revision": "baseline",
        "diagnostic": render_fault(fault),
      }
      println(report.stringify())
      @env.exit(1)
    }
  }
  let candidate = @worksheet.compile(new) catch {
    fault => {
      let report : Json = {
        "revision": "candidate",
        "diagnostic": render_fault(fault),
      }
      println(report.stringify())
      @env.exit(1)
    }
  }
  let results = @worksheet.compare_revisions(baseline, candidate, cases[:])
  { "cases": Json::array(results.map(render_replay)) }
}
