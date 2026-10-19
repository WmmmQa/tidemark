///|
/// One product and one operating period in a cost-volume-profit model.
/// Money is represented as integer fen; quantities are whole units.
pub(all) struct CvpCase {
  selling_price_fen : Int64
  variable_cost_fen : Int64
  fixed_cost_fen : Int64
}
