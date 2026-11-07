///|
/// Typed requests are independent of command-line transport.
#derive(Eq, Debug)
pub(all) enum Request {
  Plan(Array[@planning.PeriodPlan])
  Comparison(Array[@planning.PeriodPlan], Array[@planning.PeriodPlan])
  Mix(@portfolio.MixPlan, Int64, Int64)
  Capacity(@portfolio.CapacityPlan, Int64)
  CapacitySensitivity(@portfolio.CapacityPlan, String, Int64)
}

///|
/// Paths identify the offending schema field. Core analysis errors are returned
/// separately by execute_request; decoding does not replace domain validation.
#derive(Eq, Debug)
pub(all) enum DecodeError {
  InputTooLarge(Int32)
  InvalidJson(String)
  InvalidField(String, String)
}

///|
pub const MAX_INPUT_CODE_UNITS : Int32 = 16000

///|
priv suberror DecodeFailure {
  DecodeFailure(DecodeError)
}

///|
pub extend Request with Eq::{equal, not_equal}

///|
pub extend Request with @debug.Debug::{to_repr}

///|
pub extend DecodeError with Eq::{equal, not_equal}

///|
pub extend DecodeError with @debug.Debug::{to_repr}
