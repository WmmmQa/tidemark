///|
/// A named operating assumption set used for comparison or sensitivity review.
/// Keep one driver change per alternative when interpreting sensitivity results.
pub(all) struct CvpScenario {
  label : String
  case : CvpCase
  planned_units : Int64
}
