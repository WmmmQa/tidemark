///|
/// A product with an independently chosen bounded quantity and resource use.
pub(all) struct CapacityItem {
  product : Product
  max_units : Int64
  resource_uses : Array[@optimizer.ResourceUse]
} derive(Eq, Debug)

///|
/// Product contribution plan under shared resource capacities and fixed cost.
pub(all) struct CapacityPlan {
  items : Array[CapacityItem]
  resources : Array[@optimizer.Resource]
  fixed_cost_fen : Int64
} derive(Eq, Debug)

///|
/// Financial detail for one product selected by a capacity plan.
pub(all) struct CapacityProductSales {
  product : Product
  units : Int64
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
} derive(Eq, Debug)

///|
/// Optimized product mix, reconciled to revenue, contribution and profit.
pub(all) struct CapacityEvaluation {
  products : Array[CapacityProductSales]
  resources : Array[@optimizer.ResourceTotal]
  revenue_fen : Int64
  variable_cost_fen : Int64
  contribution_fen : Int64
  fixed_cost_fen : Int64
  operating_profit_fen : Int64
  explored_nodes : Int64
} derive(Eq, Debug)

///|
pub(all) enum CapacityPlanError {
  EmptyCapacityPlan
  InvalidCapacityProductId(Int32)
  DuplicateCapacityProductId(String)
  CapacityPriceOutOfRange(String)
  CapacityVariableCostOutOfRange(String)
  CapacityQuantityOutOfRange(String)
  CapacityFixedCostOutOfRange
  AllocationFailure(@optimizer.AllocationError)
  CapacityOverflow(String)
} derive(Eq, Debug)

///|
/// Choose product quantities that maximize total contribution under shared
/// resource limits, then deduct fixed cost once. Products with nonpositive
/// contribution are assigned a zero quantity because the model has no minimum
/// production requirement. Money is in fen; all other units must be consistent
/// within each resource dimension.
pub fn optimize_capacity_plan(
  plan : CapacityPlan,
  max_nodes : Int64,
) -> Result[CapacityEvaluation, CapacityPlanError] {
  if plan.items.is_empty() {
    return Err(EmptyCapacityPlan)
  }
  if plan.fixed_cost_fen < 0 || plan.fixed_cost_fen > MAX_INPUT_AMOUNT_FEN {
    return Err(CapacityFixedCostOutOfRange)
  }
  let seen : Map[String, Bool] = Map([])
  let decisions : Array[@optimizer.Decision] = []
  for index, item in plan.items {
    let product = item.product
    if product.id.trim().is_empty() ||
      product.id != product.id.trim().to_owned() {
      return Err(InvalidCapacityProductId(index))
    }
    if seen.contains(product.id) {
      return Err(DuplicateCapacityProductId(product.id))
    }
    seen[product.id] = true
    if product.selling_price_fen <= 0 ||
      product.selling_price_fen > MAX_INPUT_AMOUNT_FEN {
      return Err(CapacityPriceOutOfRange(product.id))
    }
    if product.variable_cost_fen < 0 ||
      product.variable_cost_fen > MAX_INPUT_AMOUNT_FEN {
      return Err(CapacityVariableCostOutOfRange(product.id))
    }
    if item.max_units < 0 || item.max_units > MAX_INPUT_QUANTITY {
      return Err(CapacityQuantityOutOfRange(product.id))
    }
    let margin = product.selling_price_fen - product.variable_cost_fen
    let allocatable_units = if margin > 0L { item.max_units } else { 0L }
    decisions.push({
      id: product.id,
      value_per_unit: if margin > 0L {
        margin
      } else {
        0L
      },
      max_units: allocatable_units,
      resource_uses: item.resource_uses,
    })
  }
  let allocation = match
    @optimizer.optimize({ resources: plan.resources, decisions, }, max_nodes) {
    Ok(value) => value
    Err(error) => return Err(AllocationFailure(error))
  }

  let products : Array[CapacityProductSales] = []
  let mut revenue = 0L
  let mut variable_cost = 0L
  let mut contribution = 0L
  for index, item in plan.items {
    let units = allocation.decisions[index].units
    let product = item.product
    let line_revenue = match
      checked_product(
        units,
        product.selling_price_fen,
        "capacity revenue: " + product.id,
      ) {
      Ok(value) => value
      Err(_) => return Err(CapacityOverflow("capacity revenue: " + product.id))
    }
    let line_variable_cost = match
      checked_product(
        units,
        product.variable_cost_fen,
        "capacity variable cost: " + product.id,
      ) {
      Ok(value) => value
      Err(_) =>
        return Err(CapacityOverflow("capacity variable cost: " + product.id))
    }
    let line_contribution = line_revenue - line_variable_cost
    revenue = match
      checked_add(revenue, line_revenue, "capacity revenue total") {
      Ok(value) => value
      Err(_) => return Err(CapacityOverflow("capacity revenue total"))
    }
    variable_cost = match
      checked_add(
        variable_cost, line_variable_cost, "capacity variable cost total",
      ) {
      Ok(value) => value
      Err(_) => return Err(CapacityOverflow("capacity variable cost total"))
    }
    contribution = match
      checked_add(
        contribution, line_contribution, "capacity contribution total",
      ) {
      Ok(value) => value
      Err(_) => return Err(CapacityOverflow("capacity contribution total"))
    }
    products.push({
      product,
      units,
      revenue_fen: line_revenue,
      variable_cost_fen: line_variable_cost,
      contribution_fen: line_contribution,
    })
  }
  let operating_profit = match
    checked_sub(contribution, plan.fixed_cost_fen, "capacity operating profit") {
    Ok(value) => value
    Err(_) => return Err(CapacityOverflow("capacity operating profit"))
  }
  Ok({
    products,
    resources: allocation.resources,
    revenue_fen: revenue,
    variable_cost_fen: variable_cost,
    contribution_fen: contribution,
    fixed_cost_fen: plan.fixed_cost_fen,
    operating_profit_fen: operating_profit,
    explored_nodes: allocation.explored_nodes,
  })
}

///|
pub extend CapacityItem with Eq::{equal, not_equal}

///|
pub extend CapacityPlan with Eq::{equal, not_equal}

///|
pub extend CapacityProductSales with Eq::{equal, not_equal}

///|
pub extend CapacityEvaluation with Eq::{equal, not_equal}

///|
pub extend CapacityPlanError with Eq::{equal, not_equal}

///|
pub extend CapacityItem with @debug.Debug::{to_repr}

///|
pub extend CapacityPlan with @debug.Debug::{to_repr}

///|
pub extend CapacityProductSales with @debug.Debug::{to_repr}

///|
pub extend CapacityEvaluation with @debug.Debug::{to_repr}

///|
pub extend CapacityPlanError with @debug.Debug::{to_repr}
