///|
priv struct LineParser {
  chars : Array[Char]
  line : Int32
  mut index : Int32
}

///|
fn LineParser::position(self : LineParser) -> Position {
  { line: self.line, column: self.index + 1, }
}

///|
fn LineParser::peek(self : LineParser) -> Char? {
  self.chars.get(self.index)
}

///|
fn LineParser::skip_space(self : LineParser) -> Unit {
  while self.peek() is Some(' ' | '\t' | '\r') {
    self.index += 1
  }
}

///|
fn LineParser::take(self : LineParser, char : Char) -> Bool {
  self.skip_space()
  if self.peek() == Some(char) {
    self.index += 1
    true
  } else {
    false
  }
}

///|
fn LineParser::at_end(self : LineParser) -> Bool {
  self.skip_space()
  self.peek() is (None | Some('#'))
}

///|
fn name_start(char : Char) -> Bool {
  char is ('a'..<='z' | 'A'..<='Z' | '_')
}

///|
fn LineParser::name(self : LineParser) -> String raise Fault {
  self.skip_space()
  let start = self.index
  guard self.peek() is Some(char) && name_start(char) else {
    raise Fault(self.position(), Syntax, "expected an identifier")
  }
  self.index += 1
  while self.peek() is Some(char) && (name_start(char) || char is ('0'..<='9')) {
    self.index += 1
  }
  String::from_array(self.chars[start:self.index])
}

///|
/// Accumulate negatively so the signed minimum literal is representable.
fn LineParser::number(
  self : LineParser,
  negative : Bool,
  at : Position,
) -> Int64 raise Fault {
  let limit = if negative { MIN_VALUE } else { -MAX_VALUE }
  let mut result = 0L
  while self.peek() is Some('0'..<='9' as char) {
    let digit = (char.to_int() - '0'.to_int()).to_int64()
    if result < (limit + digit) / 10L {
      raise Fault(at, Overflow, "integer literal exceeds Int64")
    }
    result = result * 10L - digit
    self.index += 1
  }
  if negative {
    result
  } else {
    -result
  }
}

///|
fn LineParser::atom(
  self : LineParser,
  out : Array[Instruction[String]],
  depth : Int32,
) -> Unit raise Fault {
  self.skip_space()
  let at = self.position()
  if depth > 32 {
    raise Fault(at, Limit, "expression nesting exceeds 32")
  }
  match self.peek() {
    Some('(') => {
      self.index += 1
      self.expression(out, 0, depth + 1)
      if !self.take(')') {
        raise Fault(self.position(), Syntax, "expected ')'")
      }
    }
    Some('-') => {
      self.index += 1
      self.skip_space()
      if self.peek() is Some('0'..<='9') {
        out.push(Number(self.number(true, at)))
      } else {
        self.atom(out, depth + 1)
        out.push(Apply(Negate, at))
      }
    }
    Some('0'..<='9') => out.push(Number(self.number(false, at)))
    Some(char) if name_start(char) => out.push(Read(self.name(), at))
    _ => raise Fault(at, Syntax, "expected an integer, name or parenthesis")
  }
}

///|
fn LineParser::expression(
  self : LineParser,
  out : Array[Instruction[String]],
  min_precedence : Int32,
  depth : Int32,
) -> Unit raise Fault {
  self.atom(out, depth)
  while true {
    self.skip_space()
    let (operator, precedence) = match self.peek() {
      Some('+') => (Add, 1)
      Some('-') => (Subtract, 1)
      Some('*') => (Multiply, 2)
      Some('/') => (Divide, 2)
      _ => break
    }
    if precedence < min_precedence {
      break
    }
    let at = self.position()
    self.index += 1
    self.expression(out, precedence + 1, depth)
    out.push(Apply(operator, at))
  }
}

///|
fn LineParser::statement(self : LineParser) -> Row[String] raise Fault {
  self.skip_space()
  let at = self.position()
  let instructions = []
  let kind = match self.name() {
    "input" => Input(self.name())
    "let" => {
      let name = self.name()
      if !self.take('=') {
        raise Fault(self.position(), Syntax, "expected '='")
      }
      self.expression(instructions, 0, 0)
      Formula(name)
    }
    "check" => {
      self.expression(instructions, 0, 0)
      self.skip_space()
      let compare_at = self.position()
      if !(self.peek() is Some('=') &&
        self.chars.get(self.index + 1) is Some('=')) {
        raise Fault(compare_at, Syntax, "expected '=='")
      }
      self.index += 2
      self.expression(instructions, 0, 0)
      instructions.push(Apply(AssertEqual, compare_at))
      Check
    }
    _ => raise Fault(at, Syntax, "expected 'input', 'let' or 'check'")
  }
  if !self.at_end() {
    raise Fault(self.position(), Syntax, "unexpected trailing input")
  }
  { kind, at, instructions, }
}

///|
fn parse(source : String) -> Array[Row[String]] raise Fault {
  if source.length() > 65536 {
    raise Fault(
      { line: 1, column: 1, },
      Limit,
      "source exceeds 65536 UTF-16 units",
    )
  }
  let rows = []
  for line, text in source.split("\n") {
    let at = { line: line + 1, column: 1, }
    let chars = text.to_array()
    if chars.length() > 512 {
      raise Fault(at, Limit, "line exceeds 512 characters")
    }
    let parser = { chars, line: at.line, index: 0, }
    if !parser.at_end() {
      if rows.length() == 512 {
        raise Fault(at, Limit, "worksheet exceeds 512 statements")
      }
      rows.push(parser.statement())
    }
  }
  rows
}
