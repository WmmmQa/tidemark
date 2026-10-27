///|
fn resource(id : String, capacity : Int64) -> @optimizer.Resource {
  { id, capacity, }
}

///|
fn use_of(id : String, units : Int64) -> @optimizer.ResourceUse {
  { resource_id: id, units_per_decision: units, }
}

///|
fn decision(
  id : String,
  value : Int64,
  maximum : Int64,
  uses : Array[@optimizer.ResourceUse],
) -> @optimizer.Decision {
  { id, value_per_unit: value, max_units: maximum, resource_uses: uses, }
}

///|
fn solved(
  problem : @optimizer.AllocationProblem,
  nodes : Int64,
) -> @optimizer.AllocationSolution {
  match @optimizer.optimize(problem, nodes) {
    Ok(solution) => solution
    Err(error) => abort(@debug.to_string(error))
  }
}

///|
test "exact optimum respects a scarce labor capacity and demand bounds" {
  let problem : @optimizer.AllocationProblem = {
    resources: [resource("labor", 10L)],
    decisions: [
      decision("meal", 9L, 3L, [use_of("labor", 4L)]),
      decision("tea", 5L, 4L, [use_of("labor", 3L)]),
    ],
  }
  let result = solved(problem, 100L)
  @debug.assert_eq(result.total_value, 19L)
  @debug.assert_eq(result.decisions[0].units, 1L)
  @debug.assert_eq(result.decisions[1].units, 2L)
  @debug.assert_eq(result.resources[0].used, 10L)
  @debug.assert_eq(result.explored_nodes > 0L, true)
}

///|
test "all resource dimensions are enforced and uses align by resource id" {
  let problem : @optimizer.AllocationProblem = {
    resources: [resource("labor", 10L), resource("material", 8L)],
    decisions: [
      decision("panel", 8L, 2L, [use_of("material", 3L), use_of("labor", 5L)]),
      decision("kit", 9L, 3L, [use_of("labor", 2L), use_of("material", 4L)]),
    ],
  }
  let result = solved(problem, 100L)
  @debug.assert_eq(result.total_value, 18L)
  @debug.assert_eq(result.decisions[0].units, 0L)
  @debug.assert_eq(result.decisions[1].units, 2L)
  @debug.assert_eq(result.resources[0].used, 4L)
  @debug.assert_eq(result.resources[1].used, 8L)
}

///|
test "zero-resource decisions use their finite bound and zero capacity stays feasible" {
  let free_problem : @optimizer.AllocationProblem = {
    resources: [resource("hours", 0L)],
    decisions: [
      decision("report", 3L, 4L, [use_of("hours", 0L)]),
      decision("meeting", 5L, 2L, [use_of("hours", 1L)]),
    ],
  }
  let result = solved(free_problem, 100L)
  @debug.assert_eq(result.total_value, 12L)
  @debug.assert_eq(result.decisions[0].units, 4L)
  @debug.assert_eq(result.decisions[1].units, 0L)
  @debug.assert_eq(result.resources[0].used, 0L)
}

///|
test "equal objective values retain deterministic input-order solution" {
  let problem : @optimizer.AllocationProblem = {
    resources: [resource("hours", 1L)],
    decisions: [
      decision("first", 1L, 1L, [use_of("hours", 1L)]),
      decision("second", 1L, 1L, [use_of("hours", 1L)]),
    ],
  }
  let result = solved(problem, 100L)
  @debug.assert_eq(result.total_value, 1L)
  @debug.assert_eq(result.decisions[0].units, 1L)
  @debug.assert_eq(result.decisions[1].units, 0L)
}

///|
test "invalid ids and unpaired resource coefficients return typed errors" {
  let duplicate : @optimizer.AllocationProblem = {
    resources: [],
    decisions: [decision("same", 1L, 1L, []), decision("same", 1L, 1L, [])],
  }
  @debug.assert_eq(
    @optimizer.optimize(duplicate, 100L),
    Err(@optimizer.DuplicateDecisionId("same")),
  )

  let missing : @optimizer.AllocationProblem = {
    resources: [resource("labor", 10L)],
    decisions: [decision("task", 1L, 1L, [])],
  }
  @debug.assert_eq(
    @optimizer.optimize(missing, 100L),
    Err(@optimizer.ResourceUseCountMismatch("task")),
  )

  let unknown : @optimizer.AllocationProblem = {
    resources: [resource("labor", 10L)],
    decisions: [decision("task", 1L, 1L, [use_of("water", 1L)])],
  }
  @debug.assert_eq(
    @optimizer.optimize(unknown, 100L),
    Err(@optimizer.UnknownResource("task", "water")),
  )
}

///|
test "search budget exhaustion never returns an unproven solution" {
  let problem : @optimizer.AllocationProblem = {
    resources: [resource("hours", 10L)],
    decisions: [
      decision("task", 3L, 3L, [use_of("hours", 1L)]),
      decision("review", 2L, 3L, [use_of("hours", 2L)]),
    ],
  }
  @debug.assert_eq(
    @optimizer.optimize(problem, 1L),
    Err(@optimizer.SearchLimitExceeded(1L)),
  )
}

///|
test "overflowing feasible objective is reported instead of wrapping" {
  let decisions : Array[@optimizer.Decision] = []
  for i in 0..<10 {
    decisions.push(decision("d\{i}", 1_000_000_000L, 1_000_000_000L, []))
  }
  let problem : @optimizer.AllocationProblem = { resources: [], decisions, }
  @debug.assert_eq(
    @optimizer.optimize(problem, 100L),
    Err(@optimizer.ObjectiveOverflow),
  )
}

///|
test "search node limit and model-size limits are validated" {
  let problem : @optimizer.AllocationProblem = {
    resources: [],
    decisions: [decision("task", 1L, 1L, [])],
  }
  @debug.assert_eq(
    @optimizer.optimize(problem, 0L),
    Err(@optimizer.SearchLimitOutOfRange),
  )
  @debug.assert_eq(
    @optimizer.optimize(problem, @optimizer.MAX_SEARCH_NODES + 1L),
    Err(@optimizer.SearchLimitOutOfRange),
  )
  @debug.assert_eq(
    @optimizer.optimize({ resources: [], decisions: [], }, 10L),
    Err(@optimizer.EmptyDecisions),
  )
}

///|
test "last decision solves a billion-unit bound without quantity enumeration" {
  let problem : @optimizer.AllocationProblem = {
    resources: [resource("stock", 1_000_000_000L)],
    decisions: [decision("standard", 7L, 1_000_000_000L, [use_of("stock", 1L)])],
  }
  let result = solved(problem, 1L)
  @debug.assert_eq(result.total_value, 7_000_000_000L)
  @debug.assert_eq(result.decisions[0].units, 1_000_000_000L)
  @debug.assert_eq(result.resources[0].used, 1_000_000_000L)
  @debug.assert_eq(result.explored_nodes, 1L)
}

///|
test "resource-free decision tail is completed directly at its quantity bounds" {
  let decisions : Array[@optimizer.Decision] = []
  for _ in 0..<10 {
    decisions.push(decision("d\{decisions.length()}", 1L, 1_000_000_000L, []))
  }
  let result = solved({ resources: [], decisions, }, 1L)
  @debug.assert_eq(result.total_value, 10_000_000_000L)
  @debug.assert_eq(result.decisions[0].units, 1_000_000_000L)
  @debug.assert_eq(result.decisions[9].units, 1_000_000_000L)
  @debug.assert_eq(result.explored_nodes, 1L)
}

///|
test "branch and bound agrees with exhaustive enumeration on a small grid" {
  for capacity in 0L..<8L {
    for first_value in 1L..<5L {
      for second_value in 1L..<5L {
        let problem : @optimizer.AllocationProblem = {
          resources: [resource("stock", capacity)],
          decisions: [
            decision("first", first_value, 3L, [use_of("stock", 2L)]),
            decision("second", second_value, 3L, [use_of("stock", 3L)]),
          ],
        }
        let mut expected = 0L
        for first_units in 0L..<4L {
          for second_units in 0L..<4L {
            if first_units * 2L + second_units * 3L <= capacity {
              let value = first_units * first_value +
                second_units * second_value
              if value > expected {
                expected = value
              }
            }
          }
        }
        @debug.assert_eq(solved(problem, 1000L).total_value, expected)
      }
    }
  }
}

///|
test "branch and bound agrees with exhaustive enumeration across two resources" {
  for labor_capacity in 0L..<5L {
    for material_capacity in 0L..<5L {
      for first_value in 1L..<4L {
        for second_value in 1L..<4L {
          let problem : @optimizer.AllocationProblem = {
            resources: [
              resource("labor", labor_capacity),
              resource("material", material_capacity),
            ],
            decisions: [
              decision("panel", first_value, 2L, [
                use_of("labor", 1L),
                use_of("material", 2L),
              ]),
              decision("kit", second_value, 2L, [
                use_of("labor", 2L),
                use_of("material", 1L),
              ]),
            ],
          }
          let mut expected = 0L
          for panel_units in 0L..<3L {
            for kit_units in 0L..<3L {
              let labor_used = panel_units + kit_units * 2L
              let material_used = panel_units * 2L + kit_units
              if labor_used <= labor_capacity &&
                material_used <= material_capacity {
                let value = panel_units * first_value + kit_units * second_value
                if value > expected {
                  expected = value
                }
              }
            }
          }
          @debug.assert_eq(solved(problem, 100L).total_value, expected)
        }
      }
    }
  }
}
