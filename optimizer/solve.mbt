///|
const MAX_I64 : Int64 = 9223372036854775807L

///|
priv struct PreparedDecision {
  id : String
  value_per_unit : Int64
  max_units : Int64
  uses : Array[Int64]
}

///|
priv struct PreparedProblem {
  resources : Array[Resource]
  decisions : Array[PreparedDecision]
}

///|
priv struct SearchState {
  problem : PreparedProblem
  max_nodes : Int64
  mut nodes : Int64
  mut best_value : Int64
  best_quantities : Array[Int64]
  current_quantities : Array[Int64]
  current_resource_use : Array[Int64]
  mut failure : AllocationError?
}

///|
priv struct ObjectiveBound {
  value : Int64
  overflowed : Bool
}

///|
fn valid_id(id : String) -> Bool {
  !id.trim().is_empty() && id == id.trim().to_owned()
}

///|
fn resource_index(resources : Array[Resource], id : String) -> Int32? {
  for index in 0..<resources.length() {
    if resources[index].id == id {
      return Some(index)
    }
  }
  None
}

///|
fn use_index(uses : Array[ResourceUse], id : String) -> Int32? {
  for index in 0..<uses.length() {
    if uses[index].resource_id == id {
      return Some(index)
    }
  }
  None
}

///|
fn prepare(
  problem : AllocationProblem,
) -> Result[PreparedProblem, AllocationError] {
  if problem.decisions.is_empty() {
    return Err(EmptyDecisions)
  }
  if problem.decisions.length() > MAX_DECISIONS {
    return Err(TooManyDecisions)
  }
  if problem.resources.length() > MAX_RESOURCES {
    return Err(TooManyResources)
  }
  for i in 0..<problem.resources.length() {
    let resource = problem.resources[i]
    if !valid_id(resource.id) {
      return Err(InvalidResourceId(i))
    }
    if resource.capacity < 0L || resource.capacity > MAX_INPUT_COEFFICIENT {
      return Err(CapacityOutOfRange(resource.id))
    }
    for j in 0..<i {
      if problem.resources[j].id == resource.id {
        return Err(DuplicateResourceId(resource.id))
      }
    }
  }

  let decisions : Array[PreparedDecision] = []
  for i in 0..<problem.decisions.length() {
    let decision = problem.decisions[i]
    if !valid_id(decision.id) {
      return Err(InvalidDecisionId(i))
    }
    for j in 0..<i {
      if problem.decisions[j].id == decision.id {
        return Err(DuplicateDecisionId(decision.id))
      }
    }
    if decision.value_per_unit < 0L ||
      decision.value_per_unit > MAX_INPUT_COEFFICIENT {
      return Err(ValueOutOfRange(decision.id))
    }
    if decision.max_units < 0L || decision.max_units > MAX_INPUT_COEFFICIENT {
      return Err(MaxUnitsOutOfRange(decision.id))
    }
    if decision.resource_uses.length() != problem.resources.length() {
      return Err(ResourceUseCountMismatch(decision.id))
    }
    for j in 0..<decision.resource_uses.length() {
      let resource_use = decision.resource_uses[j]
      if resource_index(problem.resources, resource_use.resource_id) is None {
        return Err(UnknownResource(decision.id, resource_use.resource_id))
      }
      for k in 0..<j {
        if decision.resource_uses[k].resource_id == resource_use.resource_id {
          return Err(
            DuplicateResourceUse(decision.id, resource_use.resource_id),
          )
        }
      }
      if resource_use.units_per_decision < 0L ||
        resource_use.units_per_decision > MAX_INPUT_COEFFICIENT {
        return Err(
          ResourceUnitsOutOfRange(decision.id, resource_use.resource_id),
        )
      }
    }
    let uses : Array[Int64] = []
    for resource in problem.resources {
      match use_index(decision.resource_uses, resource.id) {
        Some(index) =>
          uses.push(decision.resource_uses[index].units_per_decision)
        None => return Err(ResourceUseCountMismatch(decision.id))
      }
    }
    decisions.push({
      id: decision.id,
      value_per_unit: decision.value_per_unit,
      max_units: decision.max_units,
      uses,
    })
  }
  Ok({ resources: problem.resources, decisions, })
}

///|
fn add_to_bound(bound : ObjectiveBound, amount : Int64) -> ObjectiveBound {
  if bound.overflowed || bound.value > MAX_I64 - amount {
    { value: MAX_I64, overflowed: true, }
  } else {
    { value: bound.value + amount, overflowed: false, }
  }
}

///|
fn ratio_is_greater(
  candidate_value : Int64,
  candidate_use : Int64,
  best_value : Int64,
  best_use : Int64,
) -> Bool {
  candidate_value * best_use > best_value * candidate_use
}

///|
/// A safe objective upper bound: for each resource, allow all zero-use
/// decisions at their full bounds and price all other decisions at the best
/// value/resource ratio. The minimum of these independent bounds is still safe.
fn objective_upper_bound(
  state : SearchState,
  next_index : Int32,
  current_value : Int64,
) -> ObjectiveBound {
  if state.problem.resources.is_empty() {
    let mut upper = { value: current_value, overflowed: false, }
    for i in next_index..<state.problem.decisions.length() {
      let decision = state.problem.decisions[i]
      upper = add_to_bound(upper, decision.value_per_unit * decision.max_units)
    }
    return upper
  }
  let mut tightest = MAX_I64
  let mut tightest_overflowed = true
  for resource_index in 0..<state.problem.resources.length() {
    let mut free_value = { value: 0L, overflowed: false, }
    let mut best_ratio_value = 0L
    let mut best_ratio_use = 1L
    for i in next_index..<state.problem.decisions.length() {
      let decision = state.problem.decisions[i]
      let resource_use = decision.uses[resource_index]
      if resource_use == 0L {
        free_value = add_to_bound(
          free_value,
          decision.value_per_unit * decision.max_units,
        )
      } else if ratio_is_greater(
          decision.value_per_unit,
          resource_use,
          best_ratio_value,
          best_ratio_use,
        ) {
        best_ratio_value = decision.value_per_unit
        best_ratio_use = resource_use
      }
    }
    let remaining = state.problem.resources[resource_index].capacity -
      state.current_resource_use[resource_index]
    let numerator = remaining * best_ratio_value
    let quotient = numerator / best_ratio_use
    let fractional_value = if numerator % best_ratio_use == 0L {
      quotient
    } else {
      quotient + 1L
    }
    let bound = add_to_bound(
      add_to_bound(
        { value: current_value, overflowed: false, },
        free_value.value,
      ),
      fractional_value,
    )
    let bound_overflowed = free_value.overflowed || bound.overflowed
    if (tightest_overflowed && !bound_overflowed) ||
      (tightest_overflowed == bound_overflowed && bound.value < tightest) {
      tightest = bound.value
      tightest_overflowed = bound_overflowed
    }
  }
  { value: tightest, overflowed: tightest_overflowed, }
}

///|
fn feasible_max_units(state : SearchState, index : Int32) -> Int64 {
  let decision = state.problem.decisions[index]
  let mut maximum = decision.max_units
  for i in 0..<state.problem.resources.length() {
    let resource_use = decision.uses[i]
    if resource_use > 0L {
      let remaining = state.problem.resources[i].capacity -
        state.current_resource_use[i]
      let resource_limit = remaining / resource_use
      if resource_limit < maximum {
        maximum = resource_limit
      }
    }
  }
  maximum
}

///|
fn remaining_decisions_are_resource_free(
  problem : PreparedProblem,
  start : Int32,
) -> Bool {
  for i in start..<problem.decisions.length() {
    for resource_use in problem.decisions[i].uses {
      if resource_use > 0L {
        return false
      }
    }
  }
  true
}

///|
fn complete_resource_free_tail(
  state : SearchState,
  start : Int32,
  current_value : Int64,
) -> Unit {
  let mut total_value = current_value
  for i in start..<state.problem.decisions.length() {
    let decision = state.problem.decisions[i]
    let added_value = decision.value_per_unit * decision.max_units
    if total_value > MAX_I64 - added_value {
      state.failure = Some(ObjectiveOverflow)
      return
    }
    total_value = total_value + added_value
    state.current_quantities[i] = decision.max_units
  }
  if total_value > state.best_value {
    state.best_value = total_value
    for i in 0..<state.current_quantities.length() {
      state.best_quantities[i] = state.current_quantities[i]
    }
  }
}

///|
fn visit(
  state : SearchState,
  next_index : Int32,
  current_value : Int64,
) -> Unit {
  if state.failure is Some(_) {
    return
  }
  if state.nodes >= state.max_nodes {
    state.failure = Some(SearchLimitExceeded(state.max_nodes))
    return
  }
  state.nodes = state.nodes + 1L
  let upper = objective_upper_bound(state, next_index, current_value)
  if !upper.overflowed && upper.value <= state.best_value {
    return
  }
  if next_index == state.problem.decisions.length() {
    state.best_value = current_value
    for i in 0..<state.current_quantities.length() {
      state.best_quantities[i] = state.current_quantities[i]
    }
    return
  }

  if remaining_decisions_are_resource_free(state.problem, next_index) {
    complete_resource_free_tail(state, next_index, current_value)
    return
  }

  let decision = state.problem.decisions[next_index]
  if next_index == state.problem.decisions.length() - 1 {
    let quantity = feasible_max_units(state, next_index)
    let added_value = decision.value_per_unit * quantity
    if current_value > MAX_I64 - added_value {
      state.failure = Some(ObjectiveOverflow)
      return
    }
    let total_value = current_value + added_value
    state.current_quantities[next_index] = quantity
    for i in 0..<state.problem.resources.length() {
      state.current_resource_use[i] = state.current_resource_use[i] +
        decision.uses[i] * quantity
    }
    if total_value > state.best_value {
      state.best_value = total_value
      for i in 0..<state.current_quantities.length() {
        state.best_quantities[i] = state.current_quantities[i]
      }
    }
    for i in 0..<state.problem.resources.length() {
      state.current_resource_use[i] = state.current_resource_use[i] -
        decision.uses[i] * quantity
    }
    return
  }

  let mut quantity = feasible_max_units(state, next_index)
  while quantity >= 0L {
    let added_value = decision.value_per_unit * quantity
    if current_value > MAX_I64 - added_value {
      state.failure = Some(ObjectiveOverflow)
      return
    }
    state.current_quantities[next_index] = quantity
    for i in 0..<state.problem.resources.length() {
      state.current_resource_use[i] = state.current_resource_use[i] +
        decision.uses[i] * quantity
    }
    visit(state, next_index + 1, current_value + added_value)
    for i in 0..<state.problem.resources.length() {
      state.current_resource_use[i] = state.current_resource_use[i] -
        decision.uses[i] * quantity
    }
    if state.failure is Some(_) || quantity == 0L {
      return
    }
    quantity = quantity - 1L
  }
}

///|
/// Solve a bounded integer resource-allocation problem exactly.
///
/// This branch-and-bound solver maximizes the sum of nonnegative decision
/// values. Every decision has a finite upper bound; each resource constraint
/// limits the total consumption. `max_nodes` makes worst-case search time
/// explicit. If the budget is exhausted, no unproven incumbent is returned.
pub fn optimize(
  problem : AllocationProblem,
  max_nodes : Int64,
) -> Result[AllocationSolution, AllocationError] {
  if max_nodes < 1L || max_nodes > MAX_SEARCH_NODES {
    return Err(SearchLimitOutOfRange)
  }
  let prepared = match prepare(problem) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let best_quantities : Array[Int64] = []
  let current_quantities : Array[Int64] = []
  for _ in 0..<prepared.decisions.length() {
    best_quantities.push(0L)
    current_quantities.push(0L)
  }
  let current_resource_use : Array[Int64] = []
  for _ in 0..<prepared.resources.length() {
    current_resource_use.push(0L)
  }
  let state : SearchState = {
    problem: prepared,
    max_nodes,
    nodes: 0L,
    best_value: 0L,
    best_quantities,
    current_quantities,
    current_resource_use,
    failure: None,
  }
  visit(state, 0, 0L)
  match state.failure {
    Some(error) => Err(error)
    None => {
      let quantities : Array[DecisionQuantity] = []
      for i in 0..<prepared.decisions.length() {
        quantities.push({
          decision_id: prepared.decisions[i].id,
          units: state.best_quantities[i],
        })
      }
      let totals : Array[ResourceTotal] = []
      for i in 0..<prepared.resources.length() {
        let mut used = 0L
        for j in 0..<prepared.decisions.length() {
          used = used + prepared.decisions[j].uses[i] * state.best_quantities[j]
        }
        totals.push({
          resource_id: prepared.resources[i].id,
          used,
          capacity: prepared.resources[i].capacity,
        })
      }
      Ok({
        total_value: state.best_value,
        decisions: quantities,
        resources: totals,
        explored_nodes: state.nodes,
      })
    }
  }
}
