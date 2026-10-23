///|
/// One identifiable product. Money is integer fen, excluding tax.
/// A loss-making product is allowed within a positive-contribution mix.
pub(all) struct Product {
  id : String
  selling_price_fen : Int64
  variable_cost_fen : Int64
} derive(Eq, Debug)

///|
/// Positive integer sales ratio, not a percentage or a forecast.
pub(all) struct MixItem {
  product : Product
  weight : Int64
} derive(Eq, Debug)

///|
/// Fixed product mix and shared fixed costs for one operating period.
pub(all) struct MixPlan {
  items : Array[MixItem]
  fixed_cost_fen : Int64
} derive(Eq, Debug)

///|
/// Validated mix with weights divided by their greatest common divisor.
/// A bundle is one complete normalized sales mix, not one physical item.
pub(all) struct MixProfile {
  items : Array[MixItem]
  fixed_cost_fen : Int64
  bundle_revenue_fen : Int64
  bundle_variable_cost_fen : Int64
  bundle_contribution_fen : Int64
} derive(Eq, Debug)

///|
/// Product-level sales underlying a portfolio total.
pub(all) struct ProductSales {
  product : Product
  units : Int64
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
} derive(Eq, Debug)

///|
/// Revenue less variable costs less shared fixed cost, charged once.
pub(all) struct MixEvaluation {
  profile : MixProfile
  planned_bundles : Int64
  products : Array[ProductSales]
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
  operating_profit_fen : Int64
} derive(Eq, Debug)

///|
/// Minimum whole bundles reaching a nonnegative operating-profit target.
/// Surplus is the profit above target caused by buying whole bundles.
pub(all) struct MixTarget {
  target_profit_fen : Int64
  required : MixEvaluation
  rounding_surplus_fen : Int64
} derive(Eq, Debug)

///|
/// Financial changes are comparable even when bundle definitions differ.
/// Quantities remain in the two evaluations; there is no bundle-count delta.
pub(all) struct MixComparison {
  baseline : MixEvaluation
  alternative : MixEvaluation
  revenue_delta_fen : Int64
  variable_cost_delta_fen : Int64
  fixed_cost_delta_fen : Int64
  contribution_delta_fen : Int64
  operating_profit_delta_fen : Int64
} derive(Eq, Debug)

///|
/// Validation or arithmetic failure. Product indices are zero-based.
/// Overflow includes the operation name; no partial numeric result is returned.
pub(all) enum MixError {
  EmptyMix
  InvalidProductId(Int32)
  DuplicateProductId(String)
  PriceOutOfRange(String)
  VariableCostOutOfRange(String)
  WeightOutOfRange(String)
  FixedCostOutOfRange
  TargetProfitOutOfRange
  PlannedBundlesOutOfRange
  NonPositiveMixContribution
  Overflow(String)
} derive(Eq, Debug)

///|
/// Maximum for each input money amount, in fen (10 million yuan).
pub const MAX_INPUT_AMOUNT_FEN : Int64 = 1_000_000_000L

///|
/// Maximum raw weight and requested planned bundle count.
/// Derived product quantities may exceed this; every operation is checked.
pub const MAX_INPUT_QUANTITY : Int64 = 1_000_000_000L

///|
pub extend Product with Eq::{equal, not_equal}

///|
pub extend MixItem with Eq::{equal, not_equal}

///|
pub extend MixPlan with Eq::{equal, not_equal}

///|
pub extend MixProfile with Eq::{equal, not_equal}

///|
pub extend ProductSales with Eq::{equal, not_equal}

///|
pub extend MixEvaluation with Eq::{equal, not_equal}

///|
pub extend MixTarget with Eq::{equal, not_equal}

///|
pub extend MixComparison with Eq::{equal, not_equal}

///|
pub extend MixError with Eq::{equal, not_equal}

///|
pub extend Product with @debug.Debug::{to_repr}

///|
pub extend MixItem with @debug.Debug::{to_repr}

///|
pub extend MixPlan with @debug.Debug::{to_repr}

///|
pub extend MixProfile with @debug.Debug::{to_repr}

///|
pub extend ProductSales with @debug.Debug::{to_repr}

///|
pub extend MixEvaluation with @debug.Debug::{to_repr}

///|
pub extend MixTarget with @debug.Debug::{to_repr}

///|
pub extend MixComparison with @debug.Debug::{to_repr}

///|
pub extend MixError with @debug.Debug::{to_repr}
