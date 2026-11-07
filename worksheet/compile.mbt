///|
fn index_names(rows : Array[Row[String]]) -> Map[String, Int32] raise Fault {
  let names = Map([])
  for slot, row in rows {
    match row.kind {
      Input(name) | Formula(name) => {
        if names.contains(name) {
          raise Fault(row.at, Duplicate, name)
        }
        names[name] = slot
      }
      Check => ()
    }
  }
  names
}

///|
fn link(
  rows : Array[Row[String]],
  names : Map[String, Int32],
  dependencies : Array[Array[Int32]],
  dependents : Array[Array[Int32]],
) -> Array[Row[Int32]] raise Fault {
  let linked = []
  for slot, row in rows {
    let instructions = []
    for instruction in row.instructions {
      let resolved = match instruction {
        Number(value) => Number(value)
        Apply(operator, at) => Apply(operator, at)
        Read(name, at) => {
          guard names.get(name) is Some(dependency) else {
            raise Fault(at, Unknown, name)
          }
          // Each edge is recorded once, even when an expression reads the same
          // binding several times.
          if !dependencies[slot].contains(dependency) {
            dependencies[slot].push(dependency)
            dependents[dependency].push(slot)
          }
          Read(dependency, at)
        }
      }
      instructions.push(resolved)
    }
    linked.push({ kind: row.kind, at: row.at, instructions, })
  }
  linked
}

///|
fn cycle_fault(
  rows : Array[Row[Int32]],
  dependencies : Array[Array[Int32]],
  remaining : Array[Int32],
  start : Int32,
) -> Fault {
  let seen = Array::make(rows.length(), -1)
  let path = []
  let mut slot = start
  while seen[slot] < 0 {
    seen[slot] = path.length()
    path.push(slot)
    // Every remaining vertex has a remaining prerequisite.
    slot = dependencies[slot]
      .iter()
      .find_first(next => remaining[next] > 0)
      .unwrap()
  }
  let names = []
  for vertex in path[seen[slot]:] {
    guard rows[vertex].kind is Formula(name) else { panic() }
    names.push(name)
  }
  names.push(names[0])
  Fault(rows[slot].at, Cycle, names.join(" -> "))
}

///|
fn schedule(
  rows : Array[Row[Int32]],
  dependencies : Array[Array[Int32]],
  dependents : Array[Array[Int32]],
) -> Array[Int32] raise Fault {
  let remaining = dependencies.map(needs => needs.length())
  let order = []
  for slot, count in remaining {
    if count == 0 {
      order.push(slot)
    }
  }
  for head = 0; head < order.length(); head = head + 1 {
    for follower in dependents[order[head]] {
      remaining[follower] -= 1
      if remaining[follower] == 0 {
        order.push(follower)
      }
    }
  }
  for slot, count in remaining {
    if count > 0 {
      raise cycle_fault(rows, dependencies, remaining, slot)
    }
  }
  order
}

///|
/// Compile a worksheet and check names and dependencies before binding inputs.
pub fn compile(source : String) -> Program raise Fault {
  let parsed = parse(source)
  let names = index_names(parsed)
  let dependencies = Array::makei(parsed.length(), _ => [])
  let dependents = Array::makei(parsed.length(), _ => [])
  let rows = link(parsed, names, dependencies, dependents)
  let order = schedule(rows, dependencies, dependents)
  { rows, names, order, dependents, }
}
