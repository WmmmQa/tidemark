///|
fn period(
  id : String,
  units : String,
  price : String,
  cost : String,
  fixed : String,
) -> Json {
  {
    "id": Json::string(id),
    "products": [
      {
        "product": {
          "id": "tea",
          "selling_price_fen": Json::string(price),
          "variable_cost_fen": Json::string(cost),
        },
        "units": Json::string(units),
      },
    ],
    "fixed_cost_fen": Json::string(fixed),
    "target_profit_fen": "100",
  }
}

///|
fn plan(periods : Array[Json]) -> String {
  let value : Json = {
    "schema_version": 1,
    "kind": "plan",
    "periods": Json::array(periods),
  }
  value.stringify()
}

///|
fn at(value : Json, path : Array[String]) -> Json {
  let mut current = value
  for key in path {
    current = match current {
      Object(fields) => fields.get(key).unwrap()
      _ => abort("expected object in test")
    }
  }
  current
}

///|
fn assert_error(source : String, kind : String, detail : String) -> Unit raise {
  let response = @interchange.run_json(source)
  @debug.assert_eq(at(response, ["ok"]), Json::boolean(false))
  @debug.assert_eq(at(response, ["error", "kind"]), Json::string(kind))
  match at(response, ["error", "detail"]) {
    String(message) => assert_true(message.contains(detail))
    _ => abort("expected error detail")
  }
}

///|
test "multi-period request executes and serializes every amount as string" {
  let source = plan([
    period("oct", "10", "500", "200", "1000"),
    period("nov", "20", "550", "250", "1200"),
  ])
  let response = @interchange.run_json(source)
  @debug.assert_eq(at(response, ["ok"]), Json::boolean(true))
  @debug.assert_eq(at(response, ["schema_version"]), Json::number(1.0))
  @debug.assert_eq(at(response, ["result", "kind"]), Json::string("plan"))
  @debug.assert_eq(
    at(response, ["result", "totals", "revenue_fen"]),
    Json::string("16000"),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "operating_profit_fen"]),
    Json::string("6800"),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "target_gap_fen"]),
    Json::string("-6600"),
  )
  assert_true(@json.valid(response.stringify()))
}

///|
test "comparison machine output retains complete exact four-effect bridge" {
  let source : Json = {
    "schema_version": 1,
    "kind": "comparison",
    "budget": [period("oct", "10", "500", "200", "1000")],
    "actual": [period("oct", "12", "550", "220", "1100")],
  }
  let response = @interchange.run_json(source.stringify())
  @debug.assert_eq(at(response, ["ok"]), Json::boolean(true))
  @debug.assert_eq(at(response, ["result", "kind"]), Json::string("comparison"))
  @debug.assert_eq(
    at(response, ["result", "volume_effect_fen"]),
    Json::string("600"),
  )
  @debug.assert_eq(
    at(response, ["result", "price_effect_fen"]),
    Json::string("600"),
  )
  @debug.assert_eq(
    at(response, ["result", "variable_cost_effect_fen"]),
    Json::string("-240"),
  )
  @debug.assert_eq(
    at(response, ["result", "fixed_cost_effect_fen"]),
    Json::string("-100"),
  )
  @debug.assert_eq(
    at(response, ["result", "profit_delta_fen"]),
    Json::string("860"),
  )
}

///|
test "mix request returns normalized plans break even and target details" {
  let source =
    #|{"schema_version":1,"kind":"mix","items":[{"product":{"id":"tea","selling_price_fen":"500","variable_cost_fen":"200"},"weight":"4"}],"fixed_cost_fen":"1000","planned_bundles":"10","target_profit_fen":"100"}
  let response = @interchange.run_json(source)
  @debug.assert_eq(at(response, ["ok"]), Json::boolean(true))
  @debug.assert_eq(at(response, ["result", "kind"]), Json::string("mix"))
  @debug.assert_eq(
    at(response, ["result", "planned", "operating_profit_fen"]),
    Json::string("2000"),
  )
  @debug.assert_eq(
    at(response, ["result", "break_even", "required", "planned_bundles"]),
    Json::string("4"),
  )
  @debug.assert_eq(
    at(response, ["result", "target", "rounding_surplus_fen"]),
    Json::string("100"),
  )
}

///|
test "malformed syntax and non-object inputs are decode errors" {
  assert_error("{", "decode", "InvalidJson")
  assert_error("[]", "decode", "expected object")
  assert_error("null", "decode", "expected object")
}

///|
test "schema rejects missing extra or unsupported root fields" {
  assert_error("{}", "decode", "$.kind")
  assert_error(
    "{\"kind\":\"plan\",\"periods\":[]}", "decode", "$.schema_version",
  )
  assert_error(
    "{\"schema_version\":2,\"kind\":\"plan\",\"periods\":[]}", "decode", "supported numeric version",
  )
  assert_error(
    "{\"schema_version\":\"1\",\"kind\":\"plan\",\"periods\":[]}", "decode", "supported numeric version",
  )
  assert_error(
    "{\"schema_version\":1,\"kind\":\"forecast\"}", "decode", "unsupported request kind",
  )
  assert_error(
    "{\"schema_version\":1,\"kind\":\"plan\",\"periods\":[],\"typo\":true}", "decode",
    "$.typo",
  )
}

///|
test "unknown nested field and wrong collection type identify schema paths" {
  let source = plan([period("oct", "10", "500", "200", "1000")])
  assert_error(
    source.replace(old="\"units\":\"10\"", new="\"volume\":\"10\""),
    "decode",
    "$.periods[0].products[0].volume",
  )
  assert_error(
    "{\"schema_version\":1,\"kind\":\"plan\",\"periods\":{}}", "decode", "$.periods",
  )
  assert_error(
    source.replace(old="\"units\":\"10\"", new="\"units\":null"),
    "decode",
    "expected string",
  )
}

///|
test "money and quantities reject JSON numbers before domain analysis" {
  let source = plan([period("oct", "10", "500", "200", "1000")])
  for number in ["10", "9007199254740993", "1e2", "0.5"] {
    assert_error(
      source.replace(old="\"units\":\"10\"", new="\"units\":\{number}"),
      "decode",
      "expected string",
    )
  }
}

///|
test "noncanonical decimal spellings cannot pass integer input" {
  for
    input in [
      "", "-", "+10", " 10", "10 ", "1e2", "1.0", "01", "-01", "-0", "１２", "1_000",
    ] {
    assert_error(
      plan([period("oct", input, "500", "200", "1000")]),
      "decode",
      "InvalidField",
    )
  }
}

///|
test "Int64 boundaries parse exactly then domain validates bounds" {
  let maximum = plan([
    period("oct", "9223372036854775807", "500", "200", "1000"),
  ])
  let minimum = plan([
    period("oct", "-9223372036854775808", "500", "200", "1000"),
  ])
  assert_error(maximum, "analysis", "UnitsOutOfRange")
  assert_error(minimum, "analysis", "UnitsOutOfRange")
  for
    input in [
      "9223372036854775808", "-9223372036854775809", "999999999999999999999999999999999999999999999999",
    ] {
    assert_error(
      plan([period("oct", input, "500", "200", "1000")]),
      "decode",
      "outside signed Int64 range",
    )
  }
}

///|
test "signed in-range values reach typed domain validation" {
  assert_error(
    plan([period("oct", "-1", "500", "200", "1000")]),
    "analysis",
    "UnitsOutOfRange",
  )
  let response = @interchange.run_json(
    plan([period("oct", "0", "500", "200", "1000")]),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "operating_profit_fen"]),
    Json::string("-1000"),
  )
}

///|
test "precision above JavaScript safe integer is retained in output" {
  let response = @interchange.run_json(
    plan([period("oct", "1000000000", "1000000000", "1", "1")]),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "revenue_fen"]),
    Json::string("1000000000000000000"),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "operating_profit_fen"]),
    Json::string("999999998999999999"),
  )
}

///|
test "version dispatch uses parsed JSON number while finance inputs stay exact strings" {
  let source = plan([period("oct", "1000000000", "1000000000", "1", "1")]).replace(
    old="\"schema_version\":1",
    new="\"schema_version\":1.0000000000000001",
  )
  let response = @interchange.run_json(source)
  @debug.assert_eq(at(response, ["ok"]), Json::boolean(true))
  @debug.assert_eq(
    at(response, ["result", "totals", "revenue_fen"]),
    Json::string("1000000000000000000"),
  )
  @debug.assert_eq(
    at(response, ["result", "totals", "operating_profit_fen"]),
    Json::string("999999998999999999"),
  )

  assert_error(
    source.replace(old="1.0000000000000001", new="1.0000000000000002"),
    "decode",
    "supported numeric version",
  )
}

///|
test "bounded transport rejects oversized input before JSON parsing" {
  @debug.assert_eq(
    @interchange.parse_request(" ".repeat(16001)),
    Err(@interchange.InputTooLarge(16001)),
  )
  let accepted_length = @interchange.parse_request(" ".repeat(16000))
  assert_true(accepted_length is Err(@interchange.InvalidJson(_)))
}

///|
test "core parser repeated object keys explicitly use final value" {
  let source = "{\"schema_version\":0,\"schema_version\":1,\"kind\":\"plan\",\"periods\":[]}"
  @debug.assert_eq(
    @interchange.parse_request(source),
    Ok(@interchange.Plan([])),
  )
}

///|
test "analysis diagnostics retain product and period identity" {
  let source = plan([
    period("oct", "10", "500", "200", "1000"),
    period("oct", "20", "500", "200", "1000"),
  ])
  assert_error(source, "analysis", "DuplicatePeriodId(\"oct\")")
}

///|
test "comparison missing pairs are not silently defaulted" {
  let source : Json = {
    "schema_version": 1,
    "kind": "comparison",
    "budget": [period("oct", "10", "500", "200", "1000")],
    "actual": [period("nov", "12", "550", "220", "1100")],
  }
  assert_error(source.stringify(), "analysis", "MissingPeriod")
}
