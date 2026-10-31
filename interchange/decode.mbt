///|
/// Decode schema version 1. Money and quantity fields must be canonical decimal
/// strings so JavaScript JSON numbers cannot silently lose integer precision.
/// Duplicate object keys follow core/json behavior: the final value wins.
pub fn parse_request(source : String) -> Result[Request, DecodeError] {
  if source.length() > MAX_INPUT_CODE_UNITS {
    return Err(InputTooLarge(source.length()))
  }
  let parsed = @json.parse(source) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  Ok(decode_request(parsed)) catch {
    DecodeFailure(error) => Err(error)
  }
}

///|
fn[T] invalid(path : String, reason : String) -> T raise DecodeFailure {
  raise DecodeFailure(InvalidField(path, reason))
}

///|
fn object_fields(
  value : Json,
  path : String,
  allowed : Array[String],
) -> Map[String, Json] raise DecodeFailure {
  let fields = match value {
    Object(fields) => fields
    _ => invalid(path, "expected object")
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      invalid("\{path}.\{key}", "unknown field")
    }
  }
  for key in allowed {
    if fields.get(key) is None {
      invalid("\{path}.\{key}", "missing required field")
    }
  }
  fields
}

///|
fn field(fields : Map[String, Json], name : String) -> Json {
  // object_fields checks presence before each typed decoder is called.
  match fields.get(name) {
    Some(value) => value
    None => Json::null()
  }
}

///|
fn text(value : Json, path : String) -> String raise DecodeFailure {
  match value {
    String(value) => value
    _ => invalid(path, "expected string")
  }
}

///|
fn integer(value : Json, path : String) -> Int64 raise DecodeFailure {
  let raw = text(value, path)
  let start = if raw.length() > 0 && raw[0] == 45 { 1 } else { 0 }
  if raw.length() == start {
    return invalid(path, "expected canonical decimal integer string")
  }
  if raw[start] == 48 && (raw.length() - start > 1 || start == 1) {
    return invalid(path, "leading zeros and negative zero are not canonical")
  }
  for index in start..<raw.length() {
    if raw[index] < 48 || raw[index] > 57 {
      return invalid(path, "expected canonical decimal integer string")
    }
  }
  @string.parse_int64(raw) catch {
    _ => invalid(path, "integer is outside signed Int64 range")
  }
}

///|
fn values(value : Json, path : String) -> Array[Json] raise DecodeFailure {
  match value {
    Array(rows) => rows
    _ => invalid(path, "expected array")
  }
}

///|
fn product(
  value : Json,
  path : String,
) -> @portfolio.Product raise DecodeFailure {
  let fields = object_fields(value, path, [
    "id", "selling_price_fen", "variable_cost_fen",
  ])
  {
    id: text(field(fields, "id"), "\{path}.id"),
    selling_price_fen: integer(
      field(fields, "selling_price_fen"),
      "\{path}.selling_price_fen",
    ),
    variable_cost_fen: integer(
      field(fields, "variable_cost_fen"),
      "\{path}.variable_cost_fen",
    ),
  }
}

///|
fn resources(
  value : Json,
  path : String,
) -> Array[@optimizer.Resource] raise DecodeFailure {
  let result = []
  for index, row in values(value, path) {
    let location = "\{path}[\{index}]"
    let fields = object_fields(row, location, ["id", "capacity"])
    result.push(@optimizer.Resource::{
      id: text(field(fields, "id"), "\{location}.id"),
      capacity: integer(field(fields, "capacity"), "\{location}.capacity"),
    })
  }
  result
}

///|
fn capacity_items(
  value : Json,
  path : String,
) -> Array[@portfolio.CapacityItem] raise DecodeFailure {
  let result = []
  for index, row in values(value, path) {
    let location = "\{path}[\{index}]"
    let fields = object_fields(row, location, [
      "product", "max_units", "resource_uses",
    ])
    let resource_uses = []
    for
      use_index, use_row in values(
        field(fields, "resource_uses"),
        "\{location}.resource_uses",
      ) {
      let use_path = "\{location}.resource_uses[\{use_index}]"
      let use_fields = object_fields(use_row, use_path, [
        "resource_id", "units_per_decision",
      ])
      resource_uses.push(@optimizer.ResourceUse::{
        resource_id: text(
          field(use_fields, "resource_id"),
          "\{use_path}.resource_id",
        ),
        units_per_decision: integer(
          field(use_fields, "units_per_decision"),
          "\{use_path}.units_per_decision",
        ),
      })
    }
    result.push(@portfolio.CapacityItem::{
      product: product(field(fields, "product"), "\{location}.product"),
      max_units: integer(field(fields, "max_units"), "\{location}.max_units"),
      resource_uses,
    })
  }
  result
}

///|
fn periods(
  value : Json,
  path : String,
) -> Array[@planning.PeriodPlan] raise DecodeFailure {
  let result = []
  for index, row in values(value, path) {
    let location = "\{path}[\{index}]"
    let fields = object_fields(row, location, [
      "id", "products", "fixed_cost_fen", "target_profit_fen",
    ])
    let products = []
    for
      product_index, entry in values(
        field(fields, "products"),
        "\{location}.products",
      ) {
      let entry_path = "\{location}.products[\{product_index}]"
      let entry_fields = object_fields(entry, entry_path, ["product", "units"])
      products.push(@planning.SalesLine::{
        product: product(
          field(entry_fields, "product"),
          "\{entry_path}.product",
        ),
        units: integer(field(entry_fields, "units"), "\{entry_path}.units"),
      })
    }
    result.push(@planning.PeriodPlan::{
      id: text(field(fields, "id"), "\{location}.id"),
      products,
      fixed_cost_fen: integer(
        field(fields, "fixed_cost_fen"),
        "\{location}.fixed_cost_fen",
      ),
      target_profit_fen: integer(
        field(fields, "target_profit_fen"),
        "\{location}.target_profit_fen",
      ),
    })
  }
  result
}

///|
fn decode_request(value : Json) -> Request raise DecodeFailure {
  let root = match value {
    Object(fields) => fields
    _ => invalid("$", "expected object")
  }
  let kind = match root.get("kind") {
    Some(value) => text(value, "$.kind")
    None => invalid("$.kind", "missing required field")
  }
  let allowed = match kind {
    "plan" => ["schema_version", "kind", "periods"]
    "comparison" => ["schema_version", "kind", "budget", "actual"]
    "mix" =>
      [
        "schema_version", "kind", "items", "fixed_cost_fen", "planned_bundles", "target_profit_fen",
      ]
    "capacity" =>
      [
        "schema_version", "kind", "resources", "items", "fixed_cost_fen", "max_nodes",
      ]
    "capacity_sensitivity" =>
      [
        "schema_version", "kind", "resources", "items", "fixed_cost_fen", "resource_id",
        "max_nodes",
      ]
    _ => return invalid("$.kind", "unsupported request kind")
  }
  let fields = object_fields(value, "$", allowed)
  match field(fields, "schema_version") {
    Number(version, ..) if version == 1.0 => ()
    _ => invalid("$.schema_version", "expected supported numeric version 1")
  }
  match kind {
    "plan" => Plan(periods(field(fields, "periods"), "$.periods"))
    "comparison" =>
      Comparison(
        periods(field(fields, "budget"), "$.budget"),
        periods(field(fields, "actual"), "$.actual"),
      )
    "mix" => {
      let items = []
      for index, row in values(field(fields, "items"), "$.items") {
        let path = "$.items[\{index}]"
        let item_fields = object_fields(row, path, ["product", "weight"])
        items.push(@portfolio.MixItem::{
          product: product(field(item_fields, "product"), "\{path}.product"),
          weight: integer(field(item_fields, "weight"), "\{path}.weight"),
        })
      }
      Mix(
        {
          items,
          fixed_cost_fen: integer(
            field(fields, "fixed_cost_fen"),
            "$.fixed_cost_fen",
          ),
        },
        integer(field(fields, "planned_bundles"), "$.planned_bundles"),
        integer(field(fields, "target_profit_fen"), "$.target_profit_fen"),
      )
    }
    "capacity" =>
      Capacity(
        {
          resources: resources(field(fields, "resources"), "$.resources"),
          items: capacity_items(field(fields, "items"), "$.items"),
          fixed_cost_fen: integer(
            field(fields, "fixed_cost_fen"),
            "$.fixed_cost_fen",
          ),
        },
        integer(field(fields, "max_nodes"), "$.max_nodes"),
      )
    _ =>
      CapacitySensitivity(
        {
          resources: resources(field(fields, "resources"), "$.resources"),
          items: capacity_items(field(fields, "items"), "$.items"),
          fixed_cost_fen: integer(
            field(fields, "fixed_cost_fen"),
            "$.fixed_cost_fen",
          ),
        },
        text(field(fields, "resource_id"), "$.resource_id"),
        integer(field(fields, "max_nodes"), "$.max_nodes"),
      )
  }
}
