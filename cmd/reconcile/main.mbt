///|
#cfg(target="js")
fn argument_prefix_length() -> Int32 {
  2
}

///|
#cfg(not(target="js"))
fn argument_prefix_length() -> Int32 {
  1
}

///|
priv suberror Usage {
  Usage(String)
}

///|
fn parse_binding(
  argument : String,
  into : Map[String, Int64],
) -> Unit raise Usage {
  let parts = argument.split("=").collect()
  guard parts is [name, raw] && !name.is_empty() else {
    raise Usage("expected name=integer, got '\{argument}'")
  }
  let key = name.to_owned()
  if into.contains(key) {
    raise Usage("duplicate binding '\{key}'")
  }
  into[key] = @string.parse_int64(raw.to_owned()) catch {
    _ => raise Usage("invalid Int64 for '\{key}'")
  }
}

///|
fn render(snapshot : @worksheet.Snapshot) -> Json {
  let values : Map[String, Json] = Map([])
  for entry in snapshot.entries() {
    let (name, value) = entry
    values[name] = Json::string(value.to_string())
  }
  {
    "evaluated": Json::number(snapshot.evaluated_count().to_double()),
    "values": Json::object(values),
  }
}

///|
fn run(arguments : ArrayView[String]) -> Json raise {
  if arguments is ["--compare", .. rest] {
    return run_comparison(rest)
  }
  guard arguments is [source, .. bindings] else {
    raise Usage(
      "pass SOURCE followed by name=integer bindings and optional --edit name=integer bindings",
    )
  }
  let initial = Map([])
  let edits = Map([])
  let mut editing = false
  for arg in bindings {
    if arg == "--edit" {
      if editing {
        raise Usage("--edit can appear only once")
      }
      editing = true
    } else {
      parse_binding(arg, if editing { edits } else { initial })
    }
  }
  let before = @worksheet.compile(source).evaluate(initial)
  if editing {
    let after = before.update(edits)
    { "before": render(before), "after": render(after) }
  } else {
    render(before)
  }
}

///|
fn main {
  let arguments = @env.args()
  let offset = argument_prefix_length()
  let result = run(arguments[offset:]) catch {
    @worksheet.Fault(_, _, _) as fault => {
      let error = render_fault(fault)
      println(error.stringify())
      @env.exit(1)
    }
    Usage(detail) => {
      println("usage: \{detail}")
      @env.exit(2)
    }
    unexpected => {
      println("error: \{unexpected}")
      @env.exit(1)
    }
  }
  println(result.stringify())
}
