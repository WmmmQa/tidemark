///|
#derive(Eq, Debug)
pub(all) struct Position {
  line : Int32
  column : Int32
}

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum Code {
  Syntax
  Limit
  Duplicate
  Unknown
  Cycle
  MissingInput
  InvalidBinding
  Overflow
  ZeroDivisor
  InexactDivision
  CheckFailed
}

///|
pub extend Code with Eq::{not_equal, equal}

///|
pub extend Code with @debug.Debug::{to_repr}

///|
/// Stable error label for logs and machine-readable reports.
pub fn Code::name(self : Code) -> String {
  match self {
    Syntax => "syntax"
    Limit => "limit"
    Duplicate => "duplicate"
    Unknown => "unknown"
    Cycle => "cycle"
    MissingInput => "missing-input"
    InvalidBinding => "invalid-binding"
    Overflow => "overflow"
    ZeroDivisor => "zero-divisor"
    InexactDivision => "inexact-division"
    CheckFailed => "check-failed"
  }
}

///|
#derive(Eq, Debug)
pub suberror Fault {
  Fault(Position, Code, String)
}

///|
pub extend Fault with Eq::{not_equal, equal}

///|
pub extend Fault with @debug.Debug::{to_repr}

///|
priv enum Operator {
  Add
  Subtract
  Multiply
  Divide
  Negate
  AssertEqual
}

///|
priv enum Instruction[Ref] {
  Number(Int64)
  Read(Ref, Position)
  Apply(Operator, Position)
}

///|
priv enum Kind {
  Input(String)
  Formula(String)
  Check
}

///|
priv struct Row[Ref] {
  kind : Kind
  at : Position
  instructions : Array[Instruction[Ref]]
}

///|
/// A compiled worksheet. It is safe to reuse across independent snapshots.
pub struct Program {
  priv rows : Array[Row[Int32]]
  priv names : Map[String, Int32]
  priv order : Array[Int32]
  priv dependents : Array[Array[Int32]]
}

///|
/// Values from one successful evaluation. Updating it returns a new snapshot.
pub struct Snapshot {
  priv program : Program
  priv values : Array[Int64]
  priv evaluated : Int32
}
