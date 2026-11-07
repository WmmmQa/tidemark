///|
fn run_row(row : Row[Int32], values : Array[Int64]) -> Int64 raise Fault {
  let stack = []
  for instruction in row.instructions {
    match instruction {
      Number(value) => stack.push(value)
      Read(slot, _) => stack.push(values[slot])
      Apply(Negate, at) => {
        let value = stack.pop().unwrap()
        stack.push(apply_binary(Subtract, 0L, value, at))
      }
      Apply(operator, at) => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(apply_binary(operator, left, right, at))
      }
    }
  }
  stack.pop().unwrap()
}

///|
fn Program::input_slot(self : Program, name : String) -> Int32 raise Fault {
  guard self.names.get(name) is Some(slot) else {
    // There is no source location for a binding absent from the program.
    raise Fault({ line: 0, column: 0, }, InvalidBinding, name)
  }
  guard self.rows[slot].kind is Input(_) else {
    raise Fault(self.rows[slot].at, InvalidBinding, name)
  }
  slot
}

///|
/// Evaluate all formulas and checks using exactly the declared inputs.
pub fn Program::evaluate(
  self : Program,
  bindings : Map[String, Int64],
) -> Snapshot raise Fault {
  let values = Array::make(self.rows.length(), 0L)
  for name, value in bindings {
    values[self.input_slot(name)] = value
  }
  for row in self.rows {
    if row.kind is Input(name) && !bindings.contains(name) {
      raise Fault(row.at, MissingInput, name)
    }
  }
  let mut evaluated = 0
  for slot in self.order {
    let row = self.rows[slot]
    if !(row.kind is Input(_)) {
      values[slot] = run_row(row, values)
      evaluated += 1
    }
  }
  { program: self, values, evaluated, }
}

///|
/// Apply edits atomically. A failure leaves the old snapshot usable.
pub fn Snapshot::update(
  self : Snapshot,
  edits : Map[String, Int64],
) -> Snapshot raise Fault {
  let program = self.program
  let values = self.values.copy()
  let dirty = Array::make(values.length(), false)
  for name, value in edits {
    let slot = program.input_slot(name)
    if values[slot] != value {
      values[slot] = value
      for follower in program.dependents[slot] {
        dirty[follower] = true
      }
    }
  }
  let mut evaluated = 0
  for slot in program.order {
    if dirty[slot] {
      let value = run_row(program.rows[slot], values)
      evaluated += 1
      if value != values[slot] {
        values[slot] = value
        for follower in program.dependents[slot] {
          dirty[follower] = true
        }
      }
    }
  }
  { program, values, evaluated, }
}

///|
/// Read an input or formula by name. Checks do not introduce names.
pub fn Snapshot::value(self : Snapshot, name : String) -> Int64? {
  self.program.names.get(name).map(slot => self.values[slot])
}

///|
/// Copy all named values in source order.
pub fn Snapshot::entries(self : Snapshot) -> Array[(String, Int64)] {
  let entries = []
  for slot, row in self.program.rows {
    if row.kind is (Input(name) | Formula(name)) {
      entries.push((name, self.values[slot]))
    }
  }
  entries
}

///|
/// Number of formulas and checks executed by this evaluation or update.
pub fn Snapshot::evaluated_count(self : Snapshot) -> Int32 {
  self.evaluated
}
