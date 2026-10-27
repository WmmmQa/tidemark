///|
/// A scarce resource with a nonnegative capacity, such as labor hours or stock.
pub(all) struct Resource {
  id : String
  capacity : Int64
} derive(Eq, Debug)

///|
/// Resource consumption for one unit of a decision.
pub(all) struct ResourceUse {
  resource_id : String
  units_per_decision : Int64
} derive(Eq, Debug)

///|
/// A bounded integer decision. Objective values and resource quantities must
/// be nonnegative; zero units are always feasible.
pub(all) struct Decision {
  id : String
  value_per_unit : Int64
  max_units : Int64
  resource_uses : Array[ResourceUse]
} derive(Eq, Debug)

///|
/// Maximize total value subject to every resource limit and decision bound.
/// Each decision must specify exactly one use for every declared resource.
pub(all) struct AllocationProblem {
  resources : Array[Resource]
  decisions : Array[Decision]
} derive(Eq, Debug)

///|
pub(all) struct DecisionQuantity {
  decision_id : String
  units : Int64
} derive(Eq, Debug)

///|
pub(all) struct ResourceTotal {
  resource_id : String
  used : Int64
  capacity : Int64
} derive(Eq, Debug)

///|
/// Exact optimal solution. Ties are resolved deterministically in input order.
pub(all) struct AllocationSolution {
  total_value : Int64
  decisions : Array[DecisionQuantity]
  resources : Array[ResourceTotal]
  explored_nodes : Int64
} derive(Eq, Debug)

///|
pub(all) enum AllocationError {
  EmptyDecisions
  TooManyDecisions
  TooManyResources
  InvalidResourceId(Int32)
  DuplicateResourceId(String)
  CapacityOutOfRange(String)
  InvalidDecisionId(Int32)
  DuplicateDecisionId(String)
  ValueOutOfRange(String)
  MaxUnitsOutOfRange(String)
  ResourceUseCountMismatch(String)
  UnknownResource(String, String)
  DuplicateResourceUse(String, String)
  ResourceUnitsOutOfRange(String, String)
  SearchLimitOutOfRange
  SearchLimitExceeded(Int64)
  ObjectiveOverflow
} derive(Eq, Debug)

///|
pub const MAX_INPUT_COEFFICIENT : Int64 = 1_000_000_000L

///|
pub const MAX_DECISIONS : Int32 = 32

///|
pub const MAX_RESOURCES : Int32 = 16

///|
pub const MAX_SEARCH_NODES : Int64 = 250_000L

///|
pub extend Resource with Eq::{equal, not_equal}

///|
pub extend ResourceUse with Eq::{equal, not_equal}

///|
pub extend Decision with Eq::{equal, not_equal}

///|
pub extend AllocationProblem with Eq::{equal, not_equal}

///|
pub extend DecisionQuantity with Eq::{equal, not_equal}

///|
pub extend ResourceTotal with Eq::{equal, not_equal}

///|
pub extend AllocationSolution with Eq::{equal, not_equal}

///|
pub extend AllocationError with Eq::{equal, not_equal}

///|
pub extend Resource with @debug.Debug::{to_repr}

///|
pub extend ResourceUse with @debug.Debug::{to_repr}

///|
pub extend Decision with @debug.Debug::{to_repr}

///|
pub extend AllocationProblem with @debug.Debug::{to_repr}

///|
pub extend DecisionQuantity with @debug.Debug::{to_repr}

///|
pub extend ResourceTotal with @debug.Debug::{to_repr}

///|
pub extend AllocationSolution with @debug.Debug::{to_repr}

///|
pub extend AllocationError with @debug.Debug::{to_repr}
