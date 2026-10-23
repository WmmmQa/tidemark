///|
/// Sales volume for one product in one period. Zero volume is valid.
pub(all) struct SalesLine {
  product : @portfolio.Product
  units : Int64
} derive(Eq, Debug)

///|
/// A period's operating plan. Array order defines chronological order in a plan;
/// IDs are opaque labels. Prices and costs are integer fen, excluding tax.
pub(all) struct PeriodPlan {
  id : String
  products : Array[SalesLine]
  fixed_cost_fen : Int64
  target_profit_fen : Int64
} derive(Eq, Debug)

///|
/// Period results may have zero or negative contribution and profit.
/// Target gap is target minus operating profit; a negative gap exceeds target.
pub(all) struct PeriodResult {
  id : String
  products : Array[@portfolio.ProductSales]
  fixed_cost_fen : Int64
  target_profit_fen : Int64
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
  operating_profit_fen : Int64
  target_gap_fen : Int64
} derive(Eq, Debug)

///|
/// Additive operating amounts; profit is not cash flow. No break-even quantities
/// are summed across periods or across differing product mixes.
pub(all) struct PlanTotals {
  fixed_cost_fen : Int64
  target_profit_fen : Int64
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
  operating_profit_fen : Int64
  target_gap_fen : Int64
} derive(Eq, Debug)

///|
pub(all) struct PeriodCumulative {
  id : String
  totals : PlanTotals
} derive(Eq, Debug)

///|
pub(all) struct PlanResult {
  periods : Array[PeriodResult]
  cumulative : Array[PeriodCumulative]
  totals : PlanTotals
} derive(Eq, Debug)

///|
/// Product contribution change, excluding shared fixed costs. Effects use the
/// declared volume, then price, then variable-cost substitution order.
pub(all) struct ProductVariance {
  product_id : String
  volume_effect_fen : Int64
  price_effect_fen : Int64
  variable_cost_effect_fen : Int64
  profit_delta_fen : Int64
} derive(Eq, Debug)

///|
/// Each positive effect improves actual profit relative to budget. The bridge
/// is an accounting decomposition depending on its order, not causal evidence.
pub(all) struct PeriodVariance {
  id : String
  budget : PeriodResult
  actual : PeriodResult
  products : Array[ProductVariance]
  volume_effect_fen : Int64
  price_effect_fen : Int64
  variable_cost_effect_fen : Int64
  fixed_cost_effect_fen : Int64
  profit_delta_fen : Int64
} derive(Eq, Debug)

///|
/// Periods and product effects follow budget input order. Actual input may have
/// another order, but must contain exactly the same period/product ID sets.
pub(all) struct PlanComparison {
  budget : PlanResult
  actual : PlanResult
  periods : Array[PeriodVariance]
  volume_effect_fen : Int64
  price_effect_fen : Int64
  variable_cost_effect_fen : Int64
  fixed_cost_effect_fen : Int64
  profit_delta_fen : Int64
} derive(Eq, Debug)

///|
/// Deterministic first failure in input order. IDs must be nonblank and already
/// trimmed. Unknown/missing pairs are errors; there is no implicit zero sale.
/// Overflow gives the operation and relevant period/product where applicable.
pub(all) enum PlanError {
  EmptyPlan
  InvalidPeriodId(Int32)
  DuplicatePeriodId(String)
  EmptyProducts(String)
  InvalidProductId(String, Int32)
  DuplicateProductId(String, String)
  PriceOutOfRange(String, String)
  VariableCostOutOfRange(String, String)
  UnitsOutOfRange(String, String)
  FixedCostOutOfRange(String)
  TargetProfitOutOfRange(String)
  MissingPeriod(String)
  UnexpectedPeriod(String)
  MissingProduct(String, String)
  UnexpectedProduct(String, String)
  Overflow(String)
  ReconciliationFailed(String)
} derive(Eq, Debug)

///|
pub extend SalesLine with Eq::{equal, not_equal}

///|
pub extend PeriodPlan with Eq::{equal, not_equal}

///|
pub extend PeriodResult with Eq::{equal, not_equal}

///|
pub extend PlanTotals with Eq::{equal, not_equal}

///|
pub extend PeriodCumulative with Eq::{equal, not_equal}

///|
pub extend PlanResult with Eq::{equal, not_equal}

///|
pub extend ProductVariance with Eq::{equal, not_equal}

///|
pub extend PeriodVariance with Eq::{equal, not_equal}

///|
pub extend PlanComparison with Eq::{equal, not_equal}

///|
pub extend PlanError with Eq::{equal, not_equal}

///|
pub extend SalesLine with @debug.Debug::{to_repr}

///|
pub extend PeriodPlan with @debug.Debug::{to_repr}

///|
pub extend PeriodResult with @debug.Debug::{to_repr}

///|
pub extend PlanTotals with @debug.Debug::{to_repr}

///|
pub extend PeriodCumulative with @debug.Debug::{to_repr}

///|
pub extend PlanResult with @debug.Debug::{to_repr}

///|
pub extend ProductVariance with @debug.Debug::{to_repr}

///|
pub extend PeriodVariance with @debug.Debug::{to_repr}

///|
pub extend PlanComparison with @debug.Debug::{to_repr}

///|
pub extend PlanError with @debug.Debug::{to_repr}
