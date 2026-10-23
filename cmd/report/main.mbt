///|
fn main {
  let arguments = @env.args()
  let offset = argument_prefix_length()
  let response = if arguments.length() == offset + 1 {
    @interchange.run_json(arguments[offset])
  } else {
    @interchange.error_response(
      "usage", "Expected exactly one JSON argument; use node scripts/analyze.mjs FILE.json.",
    )
  }
  println(response.stringify())
}

///|
/// Node includes its executable and script; native includes its executable.
#cfg(target="js")
fn argument_prefix_length() -> Int32 {
  2
}

///|
#cfg(not(target="js"))
fn argument_prefix_length() -> Int32 {
  1
}
