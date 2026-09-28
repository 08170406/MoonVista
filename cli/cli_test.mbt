///|
test "CLI arguments capture filtering sorting statistics and export destination" {
  let options = parse_args([
    "customers.csv", "--sort", "amount", "desc", "--filter", "region", "=", "EU",
    "--stats", "amount", "--export", "json", "--out", "summary.json",
  ]).unwrap()
  assert_eq(options.input_path, Some("customers.csv"))
  assert_eq(options.sorts.length(), 1)
  assert_eq(options.sorts[0].column, "amount")
  assert_eq(options.sorts[0].descending, true)
  assert_eq(options.filters.length(), 1)
  assert_eq(options.filters[0].column, "region")
  assert_eq(options.filters[0].op, @ops.FilterOp::Eq)
  assert_eq(options.filters[0].value, "EU")
  assert_eq(options.stats_columns, ["amount"])
  assert_eq(options.export_format, ExportFormat::Json)
  assert_eq(options.output_path, Some("summary.json"))
}

///|
test "CLI help needs no input file" {
  let options = parse_args(["--help"]).unwrap()
  assert_eq(options.help, true)
  assert_eq(options.input_path, None)
}

///|
test "CLI rejects unsupported filter operators and missing option values" {
  assert_eq(
    parse_args(["customers.csv", "--filter", "region", "~=", "EU"]) is Err(_),
    true,
  )
  assert_eq(parse_args(["customers.csv", "--sort", "amount"]) is Err(_), true)
}

///|
test "CLI processing applies filters before stable sort" {
  let view = @ops.from_records(["name", "score"], [
    ["Ada", "7"],
    ["Lin", "3"],
    ["Bo", "9"],
  ]).unwrap()
  let options = parse_args([
    "scores.csv", "--filter", "score", ">=", "7", "--sort", "score", "desc",
  ]).unwrap()
  let processed = apply_options(view, options).unwrap()
  assert_eq(@ops.row_count(processed), 2)
  assert_eq(@ops.cell_at(processed, 0, 0), Some(@table.Cell::S("Bo")))
  assert_eq(@ops.cell_at(processed, 1, 0), Some(@table.Cell::S("Ada")))
}

///|
test "CLI recognizes supported input extensions and rejects others" {
  assert_eq(detect_input_format("data.csv"), Ok(InputFormat::Csv))
  assert_eq(detect_input_format("data.json"), Ok(InputFormat::Json))
  assert_eq(detect_input_format("data.jsonl"), Ok(InputFormat::JsonLines))
  assert_eq(detect_input_format("data.tsv") is Err(_), true)
}

///|
test "CLI pipeline exports the filtered and sorted JSON view" {
  let options = parse_args([
    "data.csv", "--filter", "score", ">=", "7", "--sort", "score", "desc", "--export",
    "json",
  ]).unwrap()
  let table = parse_input("data.csv", "name,score\nAda,7\nLin,3\nBo,9\n").unwrap()
  let result = execute_table(table, options).unwrap()
  assert_eq(
    result.body,
    "[{\"name\":\"Bo\",\"score\":9},{\"name\":\"Ada\",\"score\":7}]",
  )
  assert_eq(result.stats_report, "")
}

///|
test "CLI null filters do not need a comparison value" {
  let options = parse_args(["customers.csv", "--filter", "note", "is-null"]).unwrap()
  assert_eq(options.filters.length(), 1)
  assert_eq(options.filters[0].op, @ops.FilterOp::IsNull)
  assert_eq(options.filters[0].value, "")
}

///|
test "REPL search commands replay the application search input" {
  let view = @ops.from_records(["name", "city"], [
    ["Ada", "Paris"],
    ["Lin", "Tokyo"],
  ]).unwrap()
  let state = apply_repl_command(@app.initial(view), "search Tokyo", 10)
  assert_eq(@app.current_rows(state), 1)
  assert_eq(@app.displayed_cell(state, 0, 1), Some("Tokyo"))
}

///|
test "CLI exposes the line-oriented interactive mode" {
  let options = parse_args(["customers.csv", "--repl"]).unwrap()
  assert_eq(options.repl, true)
  assert_eq(
    parse_args(["customers.csv", "--repl", "--export", "json"]) is Err(_),
    true,
  )
}

///|
test "CLI statistics are calculated on the transformed view" {
  let options = parse_args([
    "scores.csv", "--filter", "score", ">=", "7", "--stats", "score",
  ]).unwrap()
  let table = parse_input("scores.csv", "name,score\nAda,7\nLin,3\nBo,9\n").unwrap()
  let output = execute_table(table, options).unwrap()
  assert_eq(
    output.stats_report,
    "Stats score: count=2, nulls=0, unique=2, min=7, max=9, mean=8\n",
  )
}

///|
test "CLI parses JSONL through the selected extension" {
  let table = parse_input(
    "rows.jsonl", "{\"name\":\"Ada\",\"score\":7}\n{\"name\":\"Lin\",\"score\":3}\n",
  ).unwrap()
  assert_eq(@ops.row_count(@ops.from_table(table)), 2)
}

///|
test "CLI refuses to export to an existing input file" {
  let options = parse_args([
    "samples/customers.csv", "--export", "json", "--out", "samples/customers.csv",
  ]).unwrap()
  assert_eq(execute(options) is Err(_), true)
}
