///|
fn amount(value : Int64) -> Json {
  Json::string(value.to_string())
}

///|
fn encode_product(value : @portfolio.Product) -> Json {
  {
    "id": Json::string(value.id),
    "selling_price_fen": amount(value.selling_price_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
  }
}

///|
fn encode_sales(value : @portfolio.ProductSales) -> Json {
  {
    "product": encode_product(value.product),
    "units": amount(value.units),
    "revenue_fen": amount(value.revenue_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
    "contribution_fen": amount(value.contribution_fen),
  }
}

///|
fn encode_period(value : @planning.PeriodResult) -> Json {
  {
    "id": Json::string(value.id),
    "products": Json::array(value.products.map(encode_sales)),
    "fixed_cost_fen": amount(value.fixed_cost_fen),
    "target_profit_fen": amount(value.target_profit_fen),
    "revenue_fen": amount(value.revenue_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
    "contribution_fen": amount(value.contribution_fen),
    "operating_profit_fen": amount(value.operating_profit_fen),
    "target_gap_fen": amount(value.target_gap_fen),
  }
}

///|
fn encode_totals(value : @planning.PlanTotals) -> Json {
  {
    "fixed_cost_fen": amount(value.fixed_cost_fen),
    "target_profit_fen": amount(value.target_profit_fen),
    "revenue_fen": amount(value.revenue_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
    "contribution_fen": amount(value.contribution_fen),
    "operating_profit_fen": amount(value.operating_profit_fen),
    "target_gap_fen": amount(value.target_gap_fen),
  }
}

///|
fn encode_plan(value : @planning.PlanResult) -> Json {
  {
    "periods": Json::array(value.periods.map(encode_period)),
    "cumulative": Json::array(
      value.cumulative.map(fn(row) {
        { "id": Json::string(row.id), "totals": encode_totals(row.totals) }
      }),
    ),
    "totals": encode_totals(value.totals),
  }
}

///|
fn encode_product_variance(value : @planning.ProductVariance) -> Json {
  {
    "product_id": Json::string(value.product_id),
    "volume_effect_fen": amount(value.volume_effect_fen),
    "price_effect_fen": amount(value.price_effect_fen),
    "variable_cost_effect_fen": amount(value.variable_cost_effect_fen),
    "profit_delta_fen": amount(value.profit_delta_fen),
  }
}

///|
fn encode_variance(value : @planning.PeriodVariance) -> Json {
  {
    "id": Json::string(value.id),
    "budget": encode_period(value.budget),
    "actual": encode_period(value.actual),
    "products": Json::array(value.products.map(encode_product_variance)),
    "volume_effect_fen": amount(value.volume_effect_fen),
    "price_effect_fen": amount(value.price_effect_fen),
    "variable_cost_effect_fen": amount(value.variable_cost_effect_fen),
    "fixed_cost_effect_fen": amount(value.fixed_cost_effect_fen),
    "profit_delta_fen": amount(value.profit_delta_fen),
  }
}

///|
fn encode_comparison(value : @planning.PlanComparison) -> Json {
  {
    "kind": "comparison",
    "budget": encode_plan(value.budget),
    "actual": encode_plan(value.actual),
    "periods": Json::array(value.periods.map(encode_variance)),
    "volume_effect_fen": amount(value.volume_effect_fen),
    "price_effect_fen": amount(value.price_effect_fen),
    "variable_cost_effect_fen": amount(value.variable_cost_effect_fen),
    "fixed_cost_effect_fen": amount(value.fixed_cost_effect_fen),
    "profit_delta_fen": amount(value.profit_delta_fen),
  }
}

///|
fn encode_mix(value : @portfolio.MixEvaluation) -> Json {
  let profile : Json = {
    "items": Json::array(
      value.profile.items.map(fn(item) {
        {
          "product": encode_product(item.product),
          "weight": amount(item.weight),
        }
      }),
    ),
    "fixed_cost_fen": amount(value.profile.fixed_cost_fen),
    "bundle_revenue_fen": amount(value.profile.bundle_revenue_fen),
    "bundle_variable_cost_fen": amount(value.profile.bundle_variable_cost_fen),
    "bundle_contribution_fen": amount(value.profile.bundle_contribution_fen),
  }
  {
    "profile": profile,
    "planned_bundles": amount(value.planned_bundles),
    "products": Json::array(value.products.map(encode_sales)),
    "revenue_fen": amount(value.revenue_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
    "contribution_fen": amount(value.contribution_fen),
    "operating_profit_fen": amount(value.operating_profit_fen),
  }
}

///|
fn encode_capacity(value : @portfolio.CapacityEvaluation) -> Json {
  {
    "kind": "capacity",
    "products": Json::array(
      value.products.map(fn(item) {
        {
          "product": encode_product(item.product),
          "units": amount(item.units),
          "revenue_fen": amount(item.revenue_fen),
          "variable_cost_fen": amount(item.variable_cost_fen),
          "contribution_fen": amount(item.contribution_fen),
        }
      }),
    ),
    "resources": Json::array(
      value.resources.map(fn(resource) {
        {
          "id": Json::string(resource.resource_id),
          "used": amount(resource.used),
          "capacity": amount(resource.capacity),
        }
      }),
    ),
    "revenue_fen": amount(value.revenue_fen),
    "variable_cost_fen": amount(value.variable_cost_fen),
    "contribution_fen": amount(value.contribution_fen),
    "fixed_cost_fen": amount(value.fixed_cost_fen),
    "operating_profit_fen": amount(value.operating_profit_fen),
    "explored_nodes": amount(value.explored_nodes),
  }
}

///|
fn encode_capacity_sensitivity(
  value : @portfolio.CapacityResourceSensitivity,
) -> Json {
  {
    "kind": "capacity_sensitivity",
    "metric": "discrete_one_unit_capacity_change",
    "resource_id": Json::string(value.resource_id),
    "capacity_before": amount(value.capacity_before),
    "capacity_after": amount(value.capacity_after),
    "baseline": encode_capacity(value.baseline),
    "increased_capacity": encode_capacity(value.increased_capacity),
    "contribution_delta_fen": amount(value.contribution_delta_fen),
    "operating_profit_delta_fen": amount(value.operating_profit_delta_fen),
    "product_changes": Json::array(
      value.product_changes.map(fn(change) {
        {
          "product_id": Json::string(change.product_id),
          "baseline_units": amount(change.baseline_units),
          "increased_capacity_units": amount(change.increased_capacity_units),
          "units_delta": amount(change.units_delta),
        }
      }),
    ),
    "interpretation": Json::string(
      "Discrete difference between two exact optima for this plan; excludes any cost of obtaining extra capacity and is not a continuous shadow price or causal estimate.",
    ),
    "search": {
      "solves": 2,
      "max_nodes_per_solve": amount(value.max_nodes_per_solve),
      "total_node_budget": amount(value.total_node_budget),
      "explored_nodes_total": amount(value.explored_nodes_total),
    },
  }
}

///|
fn encode_target(value : @portfolio.MixTarget) -> Json {
  {
    "target_profit_fen": amount(value.target_profit_fen),
    "required": encode_mix(value.required),
    "rounding_surplus_fen": amount(value.rounding_surplus_fen),
  }
}

///|
fn success(value : Json) -> Json {
  { "schema_version": 1, "ok": true, "result": value }
}

///|
/// Stable error envelope; detail retains the typed constructor and its context.
pub fn error_response(kind : String, detail : String) -> Json {
  {
    "schema_version": 1,
    "ok": false,
    "error": { "kind": Json::string(kind), "detail": Json::string(detail) },
  }
}

///|
/// Execute typed requests using pure MoonBit analysis and optimization
/// packages. No file I/O, locale or binary floating-point money conversion is involved.
pub fn execute_request(request : Request) -> Json {
  match request {
    Plan(periods) =>
      match @planning.evaluate_plan(periods) {
        Ok(result) => {
          let encoded = encode_plan(result)
          match encoded {
            Object(fields) => {
              fields["kind"] = "plan"
              success(Json::object(fields))
            }
            _ => abort("plan encoder must produce an object")
          }
        }
        Err(error) => error_response("analysis", @debug.to_string(error))
      }
    Comparison(budget, actual) =>
      match @planning.compare_plans(budget, actual) {
        Ok(result) => success(encode_comparison(result))
        Err(error) => error_response("analysis", @debug.to_string(error))
      }
    Mix(plan, planned_bundles, target_profit_fen) => {
      let planned = match @portfolio.evaluate_mix(plan, planned_bundles) {
        Ok(result) => result
        Err(error) => return error_response("analysis", @debug.to_string(error))
      }
      let break_even = match @portfolio.mix_break_even(plan) {
        Ok(result) => result
        Err(error) => return error_response("analysis", @debug.to_string(error))
      }
      let target = match @portfolio.mix_target(plan, target_profit_fen) {
        Ok(result) => result
        Err(error) => return error_response("analysis", @debug.to_string(error))
      }
      success({
        "kind": "mix",
        "planned": encode_mix(planned),
        "break_even": encode_target(break_even),
        "target": encode_target(target),
      })
    }
    Capacity(plan, max_nodes) =>
      match @portfolio.optimize_capacity_plan(plan, max_nodes) {
        Ok(result) => success(encode_capacity(result))
        Err(error) => error_response("analysis", @debug.to_string(error))
      }
    CapacitySensitivity(plan, resource_id, max_nodes) =>
      match
        @portfolio.capacity_resource_sensitivity(plan, resource_id, max_nodes) {
        Ok(result) => success(encode_capacity_sensitivity(result))
        Err(error) => error_response("analysis", @debug.to_string(error))
      }
  }
}

///|
/// Full reusable JSON workflow. Both successful and failed requests return one
/// versioned machine-readable document; callers must check its `ok` field.
pub fn run_json(source : String) -> Json {
  match parse_request(source) {
    Ok(request) => execute_request(request)
    Err(error) => error_response("decode", @debug.to_string(error))
  }
}
