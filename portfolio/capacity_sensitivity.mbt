///|
/// Product quantity change between two independently proven optima.
pub(all) struct CapacityProductQuantityChange {
  product_id : String
  baseline_units : Int64
  increased_capacity_units : Int64
  units_delta : Int64
} derive(Eq, Debug)

///|
/// Exact discrete comparison after adding one unit to a selected resource.
/// This is a finite-step difference, not a continuous shadow price.
pub(all) struct CapacityResourceSensitivity {
  resource_id : String
  capacity_before : Int64
  capacity_after : Int64
  baseline : CapacityEvaluation
  increased_capacity : CapacityEvaluation
  contribution_delta_fen : Int64
  operating_profit_delta_fen : Int64
  product_changes : Array[CapacityProductQuantityChange]
  max_nodes_per_solve : Int64
  total_node_budget : Int64
  explored_nodes_total : Int64
} derive(Eq, Debug)

///|
pub(all) enum CapacitySensitivityStage {
  Baseline
  IncreasedCapacity
} derive(Eq, Debug)

///|
pub(all) enum CapacitySensitivityError {
  InvalidSensitivityResourceId
  SensitivityResourceNotFound(String)
  DuplicateSensitivityResourceId(String)
  SensitivityCapacityAtMaximum(String)
  SensitivitySearchBudgetOutOfRange
  SensitivityPlanFailure(CapacitySensitivityStage, CapacityPlanError)
  SensitivityDifferenceOverflow(String)
} derive(Eq, Debug)

///|
/// Re-solve a capacity plan at its current limit and at one additional unit of
/// the named resource. Each solve has its own `max_nodes` budget. Both exact
/// optima are required; if either search is incomplete, the function returns
/// an error and no partial comparison. The reported change is discrete and
/// specific to this plan, excludes any cost of obtaining extra capacity, and
/// is not a continuous shadow price or causal estimate.
pub fn capacity_resource_sensitivity(
  plan : CapacityPlan,
  resource_id : String,
  max_nodes : Int64,
) -> Result[CapacityResourceSensitivity, CapacitySensitivityError] {
  if resource_id.trim().is_empty() ||
    resource_id != resource_id.trim().to_owned() {
    return Err(InvalidSensitivityResourceId)
  }
  if max_nodes < 1L || max_nodes > @optimizer.MAX_SEARCH_NODES {
    return Err(SensitivitySearchBudgetOutOfRange)
  }

  let mut matching_resources = 0
  let mut selected_capacity = 0L
  for resource in plan.resources {
    if resource.id == resource_id {
      matching_resources = matching_resources + 1
      selected_capacity = resource.capacity
    }
  }
  if matching_resources == 0 {
    return Err(SensitivityResourceNotFound(resource_id))
  }
  if matching_resources > 1 {
    return Err(DuplicateSensitivityResourceId(resource_id))
  }
  if selected_capacity == @optimizer.MAX_INPUT_COEFFICIENT {
    return Err(SensitivityCapacityAtMaximum(resource_id))
  }

  let baseline = match optimize_capacity_plan(plan, max_nodes) {
    Ok(value) => value
    Err(error) => return Err(SensitivityPlanFailure(Baseline, error))
  }
  let increased_resources = plan.resources.map(fn(resource) {
    if resource.id == resource_id {
      @optimizer.Resource::{
        id: resource.id,
        capacity: resource.capacity + 1L,
      }
    } else {
      resource
    }
  })
  let increased_plan : CapacityPlan = {
    items: plan.items,
    resources: increased_resources,
    fixed_cost_fen: plan.fixed_cost_fen,
  }
  let increased_capacity = match
    optimize_capacity_plan(increased_plan, max_nodes) {
    Ok(value) => value
    Err(error) => return Err(SensitivityPlanFailure(IncreasedCapacity, error))
  }
  let contribution_delta = match
    checked_sub(
      increased_capacity.contribution_fen,
      baseline.contribution_fen,
      "capacity sensitivity contribution delta",
    ) {
    Ok(value) => value
    Err(_) =>
      return Err(SensitivityDifferenceOverflow("capacity contribution delta"))
  }
  let profit_delta = match
    checked_sub(
      increased_capacity.operating_profit_fen,
      baseline.operating_profit_fen,
      "capacity sensitivity operating profit delta",
    ) {
    Ok(value) => value
    Err(_) =>
      return Err(
        SensitivityDifferenceOverflow("capacity operating profit delta"),
      )
  }
  let explored_nodes_total = match
    checked_add(
      baseline.explored_nodes,
      increased_capacity.explored_nodes,
      "capacity sensitivity explored nodes",
    ) {
    Ok(value) => value
    Err(_) => return Err(SensitivityDifferenceOverflow("explored nodes total"))
  }
  let product_changes : Array[CapacityProductQuantityChange] = []
  for index, base_product in baseline.products {
    let increased_product = increased_capacity.products[index]
    let units_delta = match
      checked_sub(
        increased_product.units,
        base_product.units,
        "capacity sensitivity product quantity delta",
      ) {
      Ok(value) => value
      Err(_) =>
        return Err(
          SensitivityDifferenceOverflow(
            "product quantity delta: " + base_product.product.id,
          ),
        )
    }
    product_changes.push({
      product_id: base_product.product.id,
      baseline_units: base_product.units,
      increased_capacity_units: increased_product.units,
      units_delta,
    })
  }
  Ok({
    resource_id,
    capacity_before: selected_capacity,
    capacity_after: selected_capacity + 1L,
    baseline,
    increased_capacity,
    contribution_delta_fen: contribution_delta,
    operating_profit_delta_fen: profit_delta,
    product_changes,
    max_nodes_per_solve: max_nodes,
    total_node_budget: max_nodes * 2L,
    explored_nodes_total,
  })
}

///|
pub extend CapacityProductQuantityChange with Eq::{equal, not_equal}

///|
pub extend CapacityResourceSensitivity with Eq::{equal, not_equal}

///|
pub extend CapacitySensitivityStage with Eq::{equal, not_equal}

///|
pub extend CapacitySensitivityError with Eq::{equal, not_equal}

///|
pub extend CapacityProductQuantityChange with @debug.Debug::{to_repr}

///|
pub extend CapacityResourceSensitivity with @debug.Debug::{to_repr}

///|
pub extend CapacitySensitivityStage with @debug.Debug::{to_repr}

///|
pub extend CapacitySensitivityError with @debug.Debug::{to_repr}
